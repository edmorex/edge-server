# edge-server

The host's **dedicated edge reverse proxy** — a standalone Caddy that owns ports
80/443, terminates TLS for all domains, and routes to backend apps on a shared
Docker network named `edge`. Static sites are served directly; containerized
apps are reverse-proxied by service name.

See [`edge-server-spec.md`](./edge-server-spec.md) for the full architecture and
the BasecaBot migration story.

## What it serves

- `edmorex.com` / `www.edmorex.com` — static hello-world landing page.
- `edmorex.com/basecawheel` — redirect to the BasecaWheel GitHub Pages app.
- A pattern for adding future apps at `edmorex.com/<name>` (see below).

## One-time setup

1. Create the shared external network (once per host):
   ```bash
   docker network create edge
   ```
2. Create your `.env` from the example and set your ACME email:
   ```bash
   cp .env.example .env
   # edit ACME_EMAIL=you@example.com
   ```

## Run

```bash
docker compose up -d
docker compose logs -f caddy   # watch for successful cert issuance
```

## Add a static app at `edmorex.com/<name>`

1. Put the built files (including `index.html`) in `sites/<name>/`.
2. Add a block inside the `edmorex.com, www.edmorex.com` site in the `Caddyfile`
   (`handle_path` strips the `/<name>` prefix):
   ```caddyfile
   handle_path /trivia* {
       root * /srv/sites/trivia
       file_server
   }
   ```
3. Reload with zero downtime:
   ```bash
   docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
   ```

## Add a containerized app at `edmorex.com/<name>`

1. Give the app its own compose project joined to the external `edge` network,
   with a service name (e.g. `myapi`).
2. Add a block to the `Caddyfile`:
   ```caddyfile
   handle /api* {
       reverse_proxy myapi:3000
   }
   ```
3. Reload Caddy as above.

> **Subpath caveat:** apps with absolute asset paths (`/assets/...`) can break
> under a subpath. `handle_path` fixes simple static sites, but many SPAs assume
> they live at the domain root — for those, prefer a **subdomain**
> (`trivia.edmorex.com`) with its own site block and DNS record.

## Reload after editing the Caddyfile

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
# or: docker compose restart caddy
```
