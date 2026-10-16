# Upstream Maintenance for the Valheim ARM64 Docker Image

This project combines Valheim lifecycle scripts from
[`arm64-valheim`](https://github.com/riptidewave93/arm64-valheim) with the
x86_64 SteamCMD and Box64 runtime from
[`steamcmd-arm64`](https://github.com/sonroyaalmerol/steamcmd-arm64). Both
inputs are pinned by digest in `Dockerfile`, so routine rebuilds are
reproducible.

| Purpose | Pinned image |
| --- | --- |
| Valheim lifecycle scripts | `ghcr.io/riptidewave93/arm64-valheim@sha256:1ebe7e5a31a8f12c0d852cb11695a526431dd6d1629b3bf3a33f88d7538eee49` |
| SteamCMD/Box64 runtime | `ghcr.io/sonroyaalmerol/steamcmd-arm64@sha256:11ca8c6dd83931bc8a26f2b33eb7a6a452740ea55a9afc27aa744e68dcb448f8` |

## Local adaptation boundary

The pinned lifecycle image supplies:

```text
/usr/local/lib/valheim/bootstrap
/usr/local/lib/valheim/common
/usr/local/bin/valheim-backup
/usr/local/bin/valheim-updater
/usr/lib/x86_64-linux-gnu/libogg.so.0
```

`docker/patch-upstream-for-steamcmd.sh` is the only build-time adaptation. It
changes the imported scripts from native `linuxarm64` SteamCMD to the
Box64-managed `linux64` SteamCMD under `/home/steam/steamcmd`. It validates the
expected source patterns, executable and shell syntax before the image can
build. The `linux32` launcher is not used because current SteamCMD self-updates
can request libc symbols unavailable in the pinned Box32 runtime.

`docker/valheim-box64.sh` is the runtime wrapper. It passes x86_64 SteamCMD to
Box64 unchanged and injects BepInEx only into `valheim_server.x86_64` when
`MODS_ENABLED=true`.

`ARM64_DEVICE` is interpreted by the pinned `steamcmd-arm64` runtime. The
project defaults to `generic`; device-specific profiles are performance and
compatibility selections rather than different Valheim configurations.

## Update procedure

Never replace a digest with a floating tag. Update one upstream input per pull
request or commit:

1. Inspect the candidate ARM64 manifest.

   ```bash
   docker buildx imagetools inspect --raw IMAGE:TAG
   ```

2. Review its release notes, Dockerfile and relevant source changes.
3. Replace one digest in `Dockerfile` and the corresponding table entry above.
4. Confirm that every imported path and every pattern checked by
   `patch-upstream-for-steamcmd.sh` still exists.
5. Run static validation and build on an ARM64 host.
6. Start with `ARM64_DEVICE=generic`, then verify the tested `rpi4` profile.
7. Confirm SteamCMD uses `linux64/steamcmd`, the existing world loads, a new
   world can be created, Crossplay registers and a graceful stop saves cleanly.

If an imported path or source pattern changed, update the patch script in the
same change. Do not weaken the strict checks into a fallback search: a failed
build is safer than silently combining incompatible upstream layouts.

## Validation commands

```bash
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.test.example \
  -f compose.yaml -f compose.test.yaml config --quiet
bash -n docker/*.sh scripts/*.sh
git diff --check
```

The full image cannot be considered validated until it has been built and run
on an ARM64 Linux host.
