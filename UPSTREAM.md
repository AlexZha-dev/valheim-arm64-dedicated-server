# Upstream image contract

This project combines the Valheim lifecycle scripts from `arm64-valheim` with
the Box32-enabled SteamCMD runtime from `steamcmd-arm64`. Both images are
pinned by digest in `Dockerfile` so a normal rebuild remains reproducible.

| Purpose | Pinned image |
| --- | --- |
| Valheim lifecycle scripts | `ghcr.io/riptidewave93/arm64-valheim@sha256:1ebe7e5a31a8f12c0d852cb11695a526431dd6d1629b3bf3a33f88d7538eee49` |
| Box32 SteamCMD runtime | `ghcr.io/sonroyaalmerol/steamcmd-arm64@sha256:11ca8c6dd83931bc8a26f2b33eb7a6a452740ea55a9afc27aa744e68dcb448f8` |

## Imported files

The pinned Valheim image provides these paths:

```text
/usr/local/lib/valheim/bootstrap
/usr/local/lib/valheim/common
/usr/local/bin/valheim-backup
/usr/local/bin/valheim-updater
/usr/lib/x86_64-linux-gnu/libogg.so.0
```

`docker/patch-upstream-for-box32.sh` is the only local adaptation. It changes
the upstream scripts from their native `linuxarm64` SteamCMD to the
Box32-managed `linux32` SteamCMD at `/home/steam/steamcmd`. It also validates
the expected source patterns, executable files and shell syntax during build.

`docker/valheim-box64.sh` is a local runtime wrapper. It passes SteamCMD
through to Box64 unchanged and enables BepInEx only for `valheim_server.x86_64`
when `MODS_ENABLED=true`. It uses Box64's guest-library variables for the
x86_64 Doorstop preloader; it does not modify the imported upstream scripts.

## Updating an upstream image

Do not replace a digest with a floating tag. Make one dedicated update commit:

1. Inspect the ARM64 manifest of the candidate image:

   ```bash
   docker buildx imagetools inspect --raw IMAGE:TAG
   ```

2. Replace the appropriate digest in `Dockerfile` and the matching table entry
   in this file.
3. Confirm the five imported paths and the three patterns checked by
   `docker/patch-upstream-for-box32.sh` still exist.
4. Build on the Pi with `sudo docker compose build --pull`.
5. Start the server and confirm SteamCMD uses `linux32/steamcmd`, the existing
   world loads, and the container remains running.

If a source path or checked pattern changed, update the patch script in the
same commit. Never weaken it into a fallback search: a failed build is safer
than silently combining incompatible upstream layouts.
