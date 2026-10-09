#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mods_dir="${MODS_DIRECTORY:-$ROOT_DIR/mods}"
mods_dir="$(realpath -m -- "$mods_dir")"
enabled="$(sed -n 's/^MODS_ENABLED=//p' "$ROOT_DIR/.env" 2>/dev/null | tail -n 1)"
enabled="${enabled:-false}"

echo "directory=$mods_dir"
echo "configured=$enabled"

missing=0
for required in \
  "$mods_dir/BepInEx/core/BepInEx.Preloader.dll" \
  "$mods_dir/doorstop_libs/libdoorstop_x64.so"; do
  if [[ ! -f "$required" ]]; then
    echo "missing=${required#"$mods_dir"/}" >&2
    missing=1
  fi
done
if [[ ! -d "$mods_dir/unstripped_corlib" ]]; then
  echo 'missing=unstripped_corlib' >&2
  missing=1
fi

if [[ -f "$mods_dir/modpack.lock" ]]; then
  echo 'lockfile=present'
else
  echo 'lockfile=absent'
fi
echo 'plugins:'
find "$mods_dir/BepInEx/plugins" -type f -name '*.dll' -printf '%f\n' 2>/dev/null | sort || true

if [[ "$enabled" == true && "$missing" -ne 0 ]]; then
  exit 1
fi
