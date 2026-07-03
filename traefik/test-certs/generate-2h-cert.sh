#!/usr/bin/env bash
# Generates a self-signed certificate for pjp1-test.ddns.net (NOT pjp1.ddns.net —
# see below) valid for exactly 2 hours, for testing certificate-renewal
# automation against the "test" entrypoint (:8444).
#
# NOT a publicly trusted certificate — Let's Encrypt does not support a 2-hour
# validity period (its shortest option is the ~6-day "shortlived" ACME profile).
# This is purely for local renewal-logic testing.
#
# Uses a dedicated test hostname rather than the real pjp1.ddns.net: Traefik's
# TLS store keeps one certificate per domain, and once a domain's slot is
# filled it is never replaced by a *live* config reload — only a full restart
# re-evaluates from scratch. pjp1.ddns.net's slot is permanently held by the
# real ACME cert (booking's production routers), so a live-reloaded test cert
# under that same name would silently never take effect.
#
# The key+cert pair is built in a fresh releases/<timestamp>/ directory (never
# modified in place), which is then published two ways:
#
# 1. The "current" symlink is atomically flipped to it (for convenient manual
#    inspection, e.g. `openssl x509 -in current/pjp1.crt ...`).
# 2. dynamic/test-tls.yml's certFile/keyFile are rewritten to point directly at
#    the new releases/<timestamp>/ path (NOT through "current").
#
# (2) matters more than it looks: Traefik's file provider diffs the *parsed*
# dynamic config on every reload, and skips reloading TLS certs entirely if
# the config is unchanged. If certFile/keyFile always pointed at the same
# stable "current" path, the config would look identical on every run even
# though the cert content behind it changed — so Traefik would silently keep
# serving the old cert forever. Pointing at the versioned path instead means
# the config genuinely changes every time, which is what actually triggers
# Traefik to re-read the cert files (see traefik/traefik#3083, #5495).
#
# Usage: ./generate-2h-cert.sh [hours]   (defaults to 2)

set -euo pipefail
cd "$(dirname "$0")"

HOURS="${1:-2}"
DOMAIN="pjp1-test.ddns.net"
RELEASE="releases/$(date -u '+%Y%m%d%H%M%S')"

mkdir -p "$RELEASE"

# Reset the minimal openssl CA state used for -selfsign on every run — this is a
# throwaway CA database, not a real one, and `openssl ca` refuses to reissue a
# cert for a subject it already has a (still "valid") entry for otherwise.
: > "$RELEASE/index.txt"
echo 1000 > "$RELEASE/serial"

cat > "$RELEASE/openssl.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
CN = ${DOMAIN}

[v3_ca]
subjectAltName = DNS:${DOMAIN}
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ca]
default_ca = myca

[myca]
new_certs_dir = ${RELEASE}
database = ${RELEASE}/index.txt
serial = ${RELEASE}/serial
default_md = sha256
policy = policy_anything
x509_extensions = v3_ca
copy_extensions = copy

[policy_anything]
commonName = supplied
EOF

openssl genrsa -out "$RELEASE/pjp1.key" 2048 2>/dev/null
openssl req -new -key "$RELEASE/pjp1.key" -out "$RELEASE/pjp1.csr" -config "$RELEASE/openssl.cnf"

START=$(date -u '+%y%m%d%H%M%SZ')
END=$(date -u -d "+${HOURS} hours" '+%y%m%d%H%M%SZ')

openssl ca -config "$RELEASE/openssl.cnf" -selfsign -in "$RELEASE/pjp1.csr" -out "$RELEASE/pjp1.crt" \
  -keyfile "$RELEASE/pjp1.key" -startdate "$START" -enddate "$END" -batch -notext

# Convenience symlink for manual inspection (not what Traefik is told to read — see above).
ln -sfn "$RELEASE" current.tmp
mv -T current.tmp current

echo
echo "Generated ${DOMAIN} cert valid for ${HOURS}h:"
openssl x509 -in current/pjp1.crt -noout -dates -subject

# Point Traefik's dynamic config at this exact release (see comment above for why).
# Only touches the file if the test setup is currently enabled; never auto-enables it.
DYNAMIC_CONF="../dynamic/test-tls.yml"
CONTAINER_PATH="/test-certs/${RELEASE}"
if [ -f "$DYNAMIC_CONF" ]; then
  cat > "$DYNAMIC_CONF.tmp" <<EOF
# Serves the self-signed short-lived test certificate (see ../test-certs/)
# on the "test" entrypoint (:8444) for ${DOMAIN}.
#
# Deliberately NOT pjp1.ddns.net: Traefik's TLS store keeps one certificate
# per domain and never replaces it via a live reload once filled — and
# pjp1.ddns.net's slot is permanently held by the real ACME cert. Using a
# distinct hostname here is what makes live-reloading actually work.
#
# certFile/keyFile point at a specific releases/<timestamp>/ snapshot rather
# than test-certs/current — Traefik also skips reloading TLS certs if the
# parsed config is otherwise unchanged, so the path itself must change on
# every regeneration too. generate-2h-cert.sh rewrites this file for you;
# don't point it at "current".
#
# To disable:  mv test-tls.yml test-tls.yml.disabled
tls:
  certificates:
    - certFile: ${CONTAINER_PATH}/pjp1.crt
      keyFile: ${CONTAINER_PATH}/pjp1.key
EOF
  mv "$DYNAMIC_CONF.tmp" "$DYNAMIC_CONF"
  echo
  echo "Updated $DYNAMIC_CONF to point at ${CONTAINER_PATH} — Traefik will reload within its poll interval, no restart needed."
else
  echo
  echo "dynamic/test-tls.yml is currently disabled — enable it (see README §7) to serve this cert."
fi

# Keep the current + previous release only, now that nothing but this run's
# dynamic config could still be referencing the previous one transiently.
KEEP_COUNT=2
ls -1dt releases/*/ 2>/dev/null | tail -n +$((KEEP_COUNT + 1)) | xargs -r rm -rf
