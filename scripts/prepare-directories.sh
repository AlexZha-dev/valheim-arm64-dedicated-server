#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$ROOT_DIR/config/worlds_local" \
         "$ROOT_DIR/data" \
         "$ROOT_DIR/backups/valheim" \
         "$ROOT_DIR/backups/manual" \
         "$ROOT_DIR/steam-diagnostics"

echo "Directories are ready: $ROOT_DIR"
echo "Copy .env.example to .env and set PASSWORD before starting."
