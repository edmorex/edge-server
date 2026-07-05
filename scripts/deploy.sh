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

echo "==> Validating Caddyfile before reload"
# The Caddyfile is bind-mounted, so the running container already sees the new
# file after the git reset above. Validate first so a broken config can't take
# down the live proxy; only reload if it passes.
docker compose exec -T caddy caddy validate --config /etc/caddy/Caddyfile

echo "==> Reloading Caddy (zero downtime)"
docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile

echo "==> Current state"
docker compose ps
echo "==> Deploy complete"
