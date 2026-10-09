#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Missing $ROOT_DIR/.env" >&2
  exit 1
fi

echo "Stopping Valheim gracefully so the archive is consistent..."
sudo docker compose stop -t 180 valheim

archive="backups/config-$(date +%Y%m%d-%H%M%S).tar.gz"
sudo tar -czf "$archive" -C . config
sudo tar -tzf "$archive" >/dev/null

echo "Backup created and verified: $ROOT_DIR/$archive"
sudo docker compose up -d --no-build
