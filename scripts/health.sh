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
echo '=== Temperature / throttling ==='
command -v vcgencmd >/dev/null && vcgencmd measure_temp || true
command -v vcgencmd >/dev/null && vcgencmd get_throttled || true
echo
echo '=== Optional overlay network ==='
sudo zerotier-cli listnetworks 2>/dev/null || true
echo
echo '=== Valheim UDP sockets ==='
sudo ss -lunp | grep -E ':(2456|2457)([[:space:]]|$)' || true
