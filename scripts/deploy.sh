#!/usr/bin/env bash
# Deploy the edge-server stack on the VPS. Run over SSH by the GitHub Actions
# workflow (.github/workflows/deploy.yml), but also safe to run by hand.
set -euo pipefail

EDGE_DIR="${EDGE_DIR:-$HOME/edge-server}"
cd "$EDGE_DIR"

echo "==> Syncing to origin/main"
git fetch --prune origin
# Deterministic deploy: match origin exactly. .env and other git-ignored files
# are untouched (reset --hard does not remove ignored/untracked files).
git reset --hard origin/main

echo "==> Applying compose stack"
docker compose pull --quiet
docker compose up -d

echo "==> Validating the new Caddyfile"
# Validate in a throwaway container. A fresh container binds the CURRENT
# Caddyfile, whereas the long-running caddy's single-file bind mount can still
# point at the pre-git-reset inode (Docker binds the file by inode at start),
# so validating via `exec` on the running container would check a stale file.
# `run` doesn't publish ports, so there's no clash with the live proxy on 80/443.
# If the config is broken this fails here (set -e), leaving the live proxy untouched.
# NB: `-T` and `</dev/null` are essential here. This script is delivered to the
# server via `ssh 'bash -s' < deploy.sh`, so bash reads it from stdin. Without
# these, `docker compose run` attaches to that same stdin and swallows the rest
# of the script — the deploy would silently stop here with exit 0.
docker compose run --rm --no-deps -T --entrypoint caddy caddy \
  validate --config /etc/caddy/Caddyfile </dev/null

echo "==> Applying the new Caddyfile"
# Recreate the caddy container so its bind mount re-resolves to the new file.
# A plain `caddy reload` would re-read the stale mount and change nothing.
# Certs persist in the caddy_data volume, so this does NOT re-hit Let's Encrypt;
# it's a ~1s connection blip, not a re-issuance.
docker compose up -d --force-recreate caddy

echo "==> Current state"
docker compose ps
echo "==> Deploy complete"
