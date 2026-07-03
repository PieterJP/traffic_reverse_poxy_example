#!/usr/bin/env bash
# Checks the live TLS certificate actually being served for each configured
# domain and alerts multiple recipients when it's close to expiry — or isn't
# the expected issuer at all (e.g. Traefik's self-signed fallback after a
# renewal failure, see README §6).
#
# Why this exists: Traefik's own `acme.email` is a single string, not a list
# (see README §6.5) — there's no built-in way to get more than one address
# notified through the ACME account itself, and Let's Encrypt no longer
# reliably sends renewal-failure reminders there anyway. This script is a
# safety net that's entirely independent of the ACME account: it inspects
# the certificate Traefik is *serving* over the wire, not acme.json, so it
# also catches the case where Traefik silently fell back to a self-signed
# cert after repeated renewal failures (which acme.email would never tell
# you about either way).
#
# Usage:
#   ./check-cert-expiry.sh
#
# Configuration is via environment variables — either export them before
# running, or put them in a .env file next to this script (auto-sourced):
#   DOMAINS            Space-separated "host[:port]" list to check.
#                       Default: "pjp.tplinkdns.com pjp1.ddns.net"
#   WARN_DAYS           Alert if fewer than this many days remain. Default: 14
#   EXPECTED_ISSUER     Substring expected in the cert issuer, to catch
#                       Traefik's self-signed fallback early.
#                       Default: "Let's Encrypt"
#   ALERT_EMAILS        Comma-separated recipient list, used with the `mail`
#                       command (mailutils/bsd-mailx + a configured MTA).
#                       This is the actual fix for "more than one person
#                       should know" — leave unset to skip email and just
#                       log/print instead.
#   SLACK_WEBHOOK_URL   Optional incoming-webhook URL (Slack/Mattermost-style)
#                       for a chat alert instead of/alongside email.
#
# Suggested crontab entry (daily; only prints/alerts when there's an issue):
#   0 7 * * * /home/avnuser/traefik/scripts/check-cert-expiry.sh >> /home/avnuser/traefik/scripts/check-cert-expiry.log 2>&1

set -euo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1091
[ -f .env ] && source .env

DOMAINS="${DOMAINS:-pjp.tplinkdns.com pjp1.ddns.net}"
WARN_DAYS="${WARN_DAYS:-14}"
# (built separately to sidestep a bash quirk: an apostrophe inside a
# ${VAR:-default} default value confuses bash's quote parsing even when the
# whole expression is itself double-quoted)
_default_issuer=$'Let\'s Encrypt'
EXPECTED_ISSUER="${EXPECTED_ISSUER:-$_default_issuer}"
ALERT_EMAILS="${ALERT_EMAILS:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

problems=()

for domain_port in $DOMAINS; do
  domain="${domain_port%%:*}"
  port="${domain_port#*:}"
  [ "$port" = "$domain" ] && port=443

  # -servername is required for SNI: without it Traefik would hand back
  # whatever its *default* certificate is, not the one for this domain.
  cert="$(echo | openssl s_client -connect "${domain}:${port}" -servername "${domain}" 2>/dev/null \
    | openssl x509 -noout -enddate -issuer 2>/dev/null || true)"

  if [ -z "$cert" ]; then
    problems+=("${domain}: could not retrieve a certificate at all (host/port unreachable?)")
    continue
  fi

  end_date="$(echo "$cert" | sed -n 's/^notAfter=//p')"
  issuer="$(echo "$cert" | sed -n 's/^issuer=//p')"

  end_epoch="$(date -d "$end_date" +%s)"
  now_epoch="$(date -u +%s)"
  days_left=$(( (end_epoch - now_epoch) / 86400 ))

  if [[ "$issuer" != *"$EXPECTED_ISSUER"* ]]; then
    problems+=("${domain}: unexpected issuer \"${issuer}\" (expected to contain \"${EXPECTED_ISSUER}\") — likely Traefik's self-signed fallback after a renewal failure, see README §6")
  elif [ "$days_left" -lt "$WARN_DAYS" ]; then
    problems+=("${domain}: expires in ${days_left} day(s) (${end_date}) — renewal should already have kicked in 30 days before expiry, so this is a sign it's stuck (see README §6.3)")
  fi
done

if [ "${#problems[@]}" -eq 0 ]; then
  echo "[$(date -u '+%Y-%m-%d %H:%M:%SZ')] OK — all certs healthy: ${DOMAINS}"
  exit 0
fi

message="Traefik certificate check found ${#problems[@]} issue(s) on $(hostname):"$'\n\n'
for p in "${problems[@]}"; do
  message+="- ${p}"$'\n'
done

echo "[$(date -u '+%Y-%m-%d %H:%M:%SZ')] ${message}"

if [ -n "$ALERT_EMAILS" ] && command -v mail >/dev/null 2>&1; then
  IFS=',' read -ra recipients <<< "$ALERT_EMAILS"
  echo "$message" | mail -s "[traefik] certificate issue on $(hostname)" "${recipients[@]}"
elif [ -n "$ALERT_EMAILS" ]; then
  echo "WARNING: ALERT_EMAILS is set but no 'mail' command is available/configured (install mailutils/bsd-mailx + an MTA, or use SLACK_WEBHOOK_URL instead)." >&2
fi

if [ -n "$SLACK_WEBHOOK_URL" ]; then
  escaped="$(printf '%s' "$message" | sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g')"
  curl -fsS -X POST -H 'Content-type: application/json' \
    --data "{\"text\": \"${escaped}\"}" "$SLACK_WEBHOOK_URL" >/dev/null || true
fi

exit 1
