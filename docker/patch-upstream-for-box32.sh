#!/usr/bin/env bash
# Adapt the pinned arm64-valheim control scripts to the Box32 SteamCMD image.
# This is intentionally strict: changed upstream source must fail the build,
# then be reviewed and updated together with the digest in Dockerfile.
set -Eeuo pipefail

readonly bootstrap=/usr/local/lib/valheim/bootstrap
readonly common=/usr/local/lib/valheim/common
readonly steamcmd_dir=/home/steam/steamcmd

require_file() {
  local file="$1"
  [[ -f "$file" ]] || {
    echo "Required upstream file is missing: $file" >&2
    exit 1
  }
}

require_one() {
  local file="$1" pattern="$2" description="$3" count
  count="$(grep -Ec -- "$pattern" "$file" || true)"
  [[ "$count" -eq 1 ]] || {
    echo "Expected exactly one $description in $file; found $count" >&2
    exit 1
  }
}

require_file "$bootstrap"
require_file "$common"
require_file /usr/local/bin/valheim-backup
require_file /usr/local/bin/valheim-updater
require_file /usr/lib/x86_64-linux-gnu/libogg.so.0

[[ -x "$bootstrap" ]] || chmod 0755 "$bootstrap"
[[ -x /usr/local/bin/valheim-backup ]] || chmod 0755 /usr/local/bin/valheim-backup
[[ -x /usr/local/bin/valheim-updater ]] || chmod 0755 /usr/local/bin/valheim-updater
[[ -x "$steamcmd_dir/linux32/steamcmd" ]] || {
  echo "Box32 SteamCMD is missing: $steamcmd_dir/linux32/steamcmd" >&2
  exit 1
}

require_one "$common" '^STEAMCMD_DIR="\$\{VOLUME_DIR\}/steamcmd"$' 'default SteamCMD directory'
require_one "$bootstrap" '/linuxarm64/steamcmd' 'native SteamCMD executable check'
require_one "$bootstrap" 'steamcmd_linuxarm64\.tar\.gz' 'native SteamCMD download URL'

sed -i \
  -e "s|^STEAMCMD_DIR=.*|STEAMCMD_DIR=\"$steamcmd_dir\"|" \
  "$common"
sed -i \
  -e 's|/linuxarm64/steamcmd|/linux32/steamcmd|g' \
  -e 's|steamcmd_linuxarm64\.tar\.gz|steamcmd_linux.tar.gz|g' \
  "$bootstrap"

grep -qFx "STEAMCMD_DIR=\"$steamcmd_dir\"" "$common"
grep -qF "\${STEAMCMD_DIR}/linux32/steamcmd" "$bootstrap"
grep -qF 'steamcmd_linux.tar.gz' "$bootstrap"
! grep -qF 'linuxarm64' "$bootstrap"

bash -n "$bootstrap" "$common" /usr/local/bin/valheim-backup /usr/local/bin/valheim-updater
echo 'Applied and verified the Box32 SteamCMD adaptation.'
