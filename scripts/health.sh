#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo '=== Compose ==='
sudo docker compose ps -a
echo
echo '=== Container resources ==='
sudo docker stats --no-stream valheim || true
echo
echo '=== Restart count ==='
sudo docker inspect --format='status={{.State.Status}} restarts={{.RestartCount}}' valheim 2>/dev/null || true
echo
echo '=== Memory ==='
free -h
echo
echo '=== Disk ==='
df -h "$ROOT_DIR"
echo
echo '=== Backups ==='
du -sh "$ROOT_DIR/backups" 2>/dev/null || true
find "$ROOT_DIR/backups/valheim" -maxdepth 1 -type f -name 'worlds-*.zip' -printf '%TY-%Tm-%Td %TH:%TM %s bytes %f\n' 2>/dev/null | sort | tail -n 5 || true
echo
echo '=== Mod pack ==='
mods_enabled="$(sed -n 's/^MODS_ENABLED=//p' "$ROOT_DIR/.env" 2>/dev/null | tail -n 1)"
echo "enabled=${mods_enabled:-false}"
if [[ -f "$ROOT_DIR/scripts/modpack-status.sh" ]]; then
  bash "$ROOT_DIR/scripts/modpack-status.sh" || true
elif [[ -d "$ROOT_DIR/mods/BepInEx/plugins" ]]; then
  find "$ROOT_DIR/mods/BepInEx/plugins" -type f -name '*.dll' -printf '%f\n' 2>/dev/null | sort || true
fi
echo
echo '=== Temperature / throttling ==='
command -v vcgencmd >/dev/null && vcgencmd measure_temp || true
command -v vcgencmd >/dev/null && vcgencmd get_throttled || true
echo
echo '=== Optional overlay network ==='
sudo zerotier-cli listnetworks 2>/dev/null || true
echo
echo '=== Valheim UDP sockets ==='
sudo ss -lunp | grep -E ':(2456|2457)([[:space:]]|$)' || true
