#!/usr/bin/env bash
# Install a complete BepInEx server pack without trusting it in-place first.
# The archive must contain BepInEx/, doorstop_libs/ and unstripped_corlib/
# either at its root or inside one BepInExPack_Valheim/ directory.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODS_DIRECTORY="${MODS_DIRECTORY:-$ROOT_DIR/mods}"

usage() {
  echo "Usage: $(basename "$0") /path/to/server-modpack.zip" >&2
  echo 'Set MODS_DIRECTORY to /srv/valheim/test/mods to install a test pack.' >&2
  exit 64
}

fail() {
  echo "install-modpack: $*" >&2
  exit 1
}

[[ "$#" -eq 1 ]] || usage
for command in unzip find mktemp realpath sudo; do
  command -v "$command" >/dev/null || fail "Required command is not installed: $command"
done

archive="$(realpath -e -- "$1")" || fail "Archive does not exist: $1"
target_dir="$(realpath -m -- "$MODS_DIRECTORY")"
case "$target_dir" in
  "$ROOT_DIR/mods"|"$ROOT_DIR/test/mods")
    ;;
  *)
    fail "MODS_DIRECTORY must be $ROOT_DIR/mods or $ROOT_DIR/test/mods"
    ;;
esac

[[ -f "$archive" ]] || fail "Not a regular file: $archive"
[[ "$archive" == *.zip ]] || fail 'The mod pack must be a .zip archive'

if ! sudo docker info >/dev/null 2>&1; then
  fail 'Docker is not available; start Docker before installing a mod pack'
fi

if [[ "$target_dir" == "$ROOT_DIR/mods" ]]; then
  running="$(sudo docker compose -f "$ROOT_DIR/compose.yaml" ps --status running -q valheim)" || fail 'Unable to inspect the production container'
else
  running="$(sudo docker ps -q --filter 'name=^/valheim-mod-test$')"
fi
[[ -z "$running" ]] || fail 'Stop the target server before changing its mod pack'

# Do not hand an archive with absolute paths, traversal paths or backslash
# separators to unzip. The latter avoids platform-dependent interpretation.
while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue
  [[ "$entry" != /* && "$entry" != *\\* ]] || fail "Unsafe archive entry: $entry"
  IFS='/' read -r -a parts <<< "$entry"
  for part in "${parts[@]}"; do
    [[ "$part" != '.' && "$part" != '..' ]] || fail "Unsafe archive entry: $entry"
  done
done < <(unzip -Z1 "$archive")

unzip -tqq "$archive" >/dev/null || fail 'Archive integrity test failed'
stage="$(mktemp -d "$ROOT_DIR/.modpack-staging.XXXXXX")"
cleanup() {
  rm -rf "$stage"
}
trap cleanup EXIT

mkdir -p "$stage/extract" "$stage/pack"
unzip -qq "$archive" -d "$stage/extract"
symlink="$(find "$stage/extract" -type l -print -quit)"
[[ -z "$symlink" ]] || fail "Symbolic links are not accepted in a mod pack: $symlink"

payload="$stage/extract"
if [[ -d "$stage/extract/BepInExPack_Valheim" ]]; then
  payload="$stage/extract/BepInExPack_Valheim"
fi

for required in \
  "$payload/BepInEx/core/BepInEx.Preloader.dll" \
  "$payload/doorstop_libs/libdoorstop_x64.so"; do
  [[ -f "$required" ]] || fail "Required BepInEx file is missing: ${required#"$payload"/}"
done
[[ -d "$payload/unstripped_corlib" ]] || fail 'Required BepInEx directory is missing: unstripped_corlib'

cp -a "$payload/BepInEx" "$stage/pack/BepInEx"
cp -a "$payload/doorstop_libs" "$stage/pack/doorstop_libs"
cp -a "$payload/unstripped_corlib" "$stage/pack/unstripped_corlib"
mkdir -p "$stage/pack/BepInEx/plugins" "$stage/pack/BepInEx/config"
if [[ -f "$payload/modpack.lock" ]]; then
  cp -a "$payload/modpack.lock" "$stage/pack/modpack.lock"
fi

stamp="$(date +%Y%m%d-%H%M%S)"
previous_dir="$target_dir.previous-$stamp"
moved_previous=false
if [[ -e "$target_dir" ]]; then
  sudo mv "$target_dir" "$previous_dir"
  moved_previous=true
fi

if ! sudo mv "$stage/pack" "$target_dir"; then
  if [[ "$moved_previous" == true ]]; then
    sudo mv "$previous_dir" "$target_dir" || true
  fi
  fail 'Could not activate the validated mod pack; the previous pack was restored'
fi

if [[ ! -f "$target_dir/modpack.lock" ]]; then
  echo 'Warning: modpack.lock is absent. Add package names, exact versions and SHA-256 hashes.' >&2
fi
echo "Installed mod pack: $target_dir"
if [[ "$moved_previous" == true ]]; then
  echo "Previous mod pack preserved at: $previous_dir"
fi
echo 'Set MODS_ENABLED=true only after testing the pack and checking BepInEx logs.'
