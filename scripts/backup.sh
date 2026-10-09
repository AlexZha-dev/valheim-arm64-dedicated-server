#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Missing $ROOT_DIR/.env" >&2
  exit 1
fi

was_running="$(sudo docker compose ps --status running -q valheim)"
restart_server() {
  if [[ -n "$was_running" ]]; then
    echo "Starting Valheim again..."
    sudo docker compose up -d --no-build valheim
  fi
}
trap restart_server EXIT

if [[ -n "$was_running" ]]; then
  echo "Stopping Valheim gracefully so the archive is consistent..."
  sudo docker compose stop -t 180 valheim
fi

sudo install -d -m 0750 backups/manual
archive="backups/manual/config-$(date +%Y%m%d-%H%M%S).tar.gz"
backup_paths=(config)
if [[ -d mods ]]; then
  backup_paths+=(mods)
fi
sudo tar -czf "$archive" -C . "${backup_paths[@]}"
sudo tar -tzf "$archive" >/dev/null

manual_retention="$(sed -n 's/^MANUAL_BACKUP_RETENTION_DAYS=//p' .env | tail -n 1)"
manual_retention="${manual_retention:-30}"
if [[ ! "$manual_retention" =~ ^[0-9]+$ ]]; then
  echo "MANUAL_BACKUP_RETENTION_DAYS must be a non-negative number" >&2
  exit 1
fi
if [[ "$manual_retention" -gt 0 ]]; then
  sudo find backups/manual -type f -name 'config-*.tar.gz' -mtime +"$manual_retention" -delete
fi

echo "Backup created and verified: $ROOT_DIR/$archive"
