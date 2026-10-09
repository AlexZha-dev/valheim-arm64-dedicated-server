#!/usr/bin/env bash
# Box64 wrapper for both SteamCMD and Valheim.
# BepInEx uses an x86_64 Doorstop library, so it must be injected through
# Box64's guest-library variables rather than the ARM process's LD_PRELOAD.
set -Eeuo pipefail

readonly box64=/usr/local/bin/box64

if [[ "$#" -eq 0 ]]; then
  echo 'valheim-box64: missing program to execute' >&2
  exit 64
fi

case "${MODS_ENABLED:-false}" in
  false|'')
    exec "$box64" "$@"
    ;;
  true)
    ;;
  *)
    echo "valheim-box64: MODS_ENABLED must be true or false (got ${MODS_ENABLED})" >&2
    exit 64
    ;;
esac

# DEBUGGER also starts x86 SteamCMD. Only the dedicated-server binary must
# receive the BepInEx environment.
if [[ "$(basename -- "$1")" != 'valheim_server.x86_64' ]]; then
  exec "$box64" "$@"
fi

readonly server_dir="$(pwd -P)"
readonly preloader="$server_dir/BepInEx/core/BepInEx.Preloader.dll"
readonly doorstop="$server_dir/doorstop_libs/libdoorstop_x64.so"
readonly corlib="$server_dir/unstripped_corlib"

for required in "$preloader" "$doorstop"; do
  if [[ ! -f "$required" ]]; then
    echo "valheim-box64: BepInEx is enabled but required file is missing: $required" >&2
    exit 78
  fi
done
if [[ ! -d "$corlib" ]]; then
  echo "valheim-box64: BepInEx is enabled but required directory is missing: $corlib" >&2
  exit 78
fi

export DOORSTOP_ENABLE=TRUE
export DOORSTOP_INVOKE_DLL_PATH="$preloader"
export DOORSTOP_CORLIB_OVERRIDE_PATH="$corlib"
export BOX64_LD_LIBRARY_PATH="$server_dir/doorstop_libs${BOX64_LD_LIBRARY_PATH:+:${BOX64_LD_LIBRARY_PATH}}"
export BOX64_LD_PRELOAD="$doorstop${BOX64_LD_PRELOAD:+:${BOX64_LD_PRELOAD}}"

echo "[valheim-mods] Starting BepInEx from $server_dir/BepInEx"
exec "$box64" "$@"
