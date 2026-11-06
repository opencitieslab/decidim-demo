#!/usr/bin/env bash
# Deploy/update the demo from an operator machine.
# Syncs the committed tree (git archive of HEAD) to the host, builds, migrates, restarts, installs cron.
# The host's .env.production is created once by hand (see README) and never overwritten.
set -euo pipefail
cd "$(dirname "$0")/.."

EIP=$(cat deploy/.host-ip)
KEY_FILE="${KEY_FILE:-$HOME/.ssh/decidim-demo.pem}"
SSH="ssh -i $KEY_FILE -o StrictHostKeyChecking=accept-new ubuntu@$EIP"
APP=/opt/decidim-demo

echo "Shipping $(git rev-parse --short HEAD) to $EIP"
git archive --format=tar HEAD | $SSH "mkdir -p $APP && tar -x -C $APP"

$SSH bash -s <<EOF
set -euo pipefail
cd $APP
test -f .env.production || { echo "Missing $APP/.env.production — create it first (README: First deploy)"; exit 1; }
chmod 600 .env.production
ln -sf .env.production .env          # compose variable interpolation (DATABASE_PASSWORD, SITE_ADDRESS)
mkdir -p log
docker compose build app
docker compose up -d db redis
# NOT db:prepare/db:setup — those run db/seeds.rb, which creates well-known default accounts.
docker compose run --rm -T app bin/rails db:create db:migrate < /dev/null
docker compose up -d --remove-orphans
# Caddyfile is a single-file bind mount and tar replaces the file (new inode), so recreate caddy to load it.
docker compose up -d --force-recreate --no-deps caddy
crontab deploy/crontab
docker image prune -f >/dev/null
docker compose ps
EOF
