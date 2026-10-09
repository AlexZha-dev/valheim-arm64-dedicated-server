#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo '=== Host ==='
printf 'architecture=%s\n' "$(uname -m)"
if [[ -r /etc/os-release ]]; then
  host_os="$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | head -n 1 | tr -d '"')"
  printf 'os=%s\n' "${host_os:-unknown}"
fi
device_profile="$(sed -n 's/^ARM64_DEVICE=//p' "$ROOT_DIR/.env" 2>/dev/null | tail -n 1)"
printf 'arm64_device=%s\n' "${device_profile:-generic}"
echo
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
if command -v vcgencmd >/dev/null 2>&1; then
  vcgencmd measure_temp || true
  vcgencmd get_throttled || true
elif [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
  awk '{ printf "temperature=%.1fC\n", $1 / 1000 }' /sys/class/thermal/thermal_zone0/temp
  echo 'throttling=unavailable (vcgencmd is not installed)'
else
  echo 'temperature=unavailable'
  echo 'throttling=unavailable'
fi
echo
echo '=== Optional overlay network ==='
if command -v zerotier-cli >/dev/null 2>&1; then
  sudo zerotier-cli listnetworks 2>/dev/null || true
else
  echo 'ZeroTier is not installed'
fi
echo
echo '=== Valheim UDP sockets ==='
sudo ss -lunp | grep -E ':(2456|2457)([[:space:]]|$)' || true
