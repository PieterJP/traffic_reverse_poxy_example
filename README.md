# Traefik Reverse Proxy Example — Two Domains, Two Apps

A worked example of running a single [Traefik](https://traefik.io/) instance
in front of two independent applications, each on its own public domain,
with a LAN-only admin path that never touches the public internet.

## Layout

| Directory | What it is |
| --- | --- |
| [`traefik/`](traefik/) | The Traefik reverse proxy itself (docker-compose config, TLS/Let's Encrypt setup, routing docs) |
| [`booking/`](booking/) | Example app #1 — a small Vite/React app served on `pjp1.ddns.net` |
| [`dbc/`](dbc/) | Example app #2 — a small Next.js app served under `pjp.tplinkdns.com/dbc` |

See [`traefik/README.md`](traefik/README.md) for the full architecture,
routing rules, and setup walkthrough covering all three services together.

## Quick start

Each directory is a standalone docker-compose project that joins a shared
external `web` network:

```bash
docker network create web

cd traefik && cp .env.example .env && docker compose up -d
cd ../booking && docker compose up -d
cd ../dbc && docker compose up -d
```
