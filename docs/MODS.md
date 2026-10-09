# Optional BepInEx Mods for the Valheim ARM64 Server

The server is vanilla unless `MODS_ENABLED=true` is set in `.env`. Mods execute
third-party code and may permanently change a world. The server owner is
responsible for selecting, versioning, testing and updating the complete pack.

This repository does not include a plugin, mod manager, Thunderstore account,
download URL or DLL.

> [!WARNING]
> Make a manual backup before every modpack change. Do not open a world that
> contains modded objects without its matching modpack merely because the
> vanilla server can start.

## Compatibility model

| Mod type | Server | PC clients | Console / Crossplay |
| --- | --- | --- | --- |
| Client-only | Do not install | Install where needed | Unaffected only if truly client-only |
| Server-only | Install | Usually not required | Use only when the author confirms the exact version supports dedicated Crossplay |
| Synchronized, content or RPC | Install | Same versions required | Incompatible with clients that cannot run BepInEx |

A `server-side` label is not a Crossplay guarantee. Test the exact combination
after each Valheim, BepInEx or plugin update.

## Modpack contract

`scripts/install-modpack.sh` accepts one local ZIP with this layout at its root
or inside one `BepInExPack_Valheim/` directory:

```text
BepInEx/
  core/BepInEx.Preloader.dll
  plugins/
  config/
doorstop_libs/
  libdoorstop_x64.so
unstripped_corlib/
modpack.lock
```

Use a Linux x64 BepInEx pack compatible with the selected plugins. The
container controls the launch process and deliberately ignores a vendor
`start_server_bepinex.sh`; Doorstop is injected through Box64 instead.

`modpack.lock` is a human-readable inventory maintained by the server owner:

```text
# package | version | source | sha256
BepInExPack_Valheim | 5.x.y | https://example.invalid/release.zip | SHA256
Author-ModName | 1.2.3 | https://example.invalid/mod.zip | SHA256
```

Keep the original ZIP and lock file outside Git. They are part of the recovery
material for a modded world.

## Install a pack

Build the current server image and stop production before replacing its pack:

```bash
cd /srv/valheim
sudo docker compose build --pull valheim
sudo docker compose stop -t 180 valheim
bash scripts/install-modpack.sh /home/USER/server-modpack.zip
```

The installer checks ZIP integrity, rejects unsafe paths and symbolic links,
validates the BepInEx preloader and x86_64 Doorstop library, then activates the
pack atomically. A previous `mods` directory is retained as
`mods.previous-TIMESTAMP` for rollback.

The installer never downloads arbitrary code.

## Test without production data

The test override has its own container, world, game data, mods, diagnostics,
backups and base UDP port `2458`:

```bash
cd /srv/valheim
cp .env.test.example .env.test
nano .env.test

sudo install -d test/config/worlds_local test/data test/backups/valheim \
  test/steam-diagnostics
sudo rsync -a config/worlds_local/ test/config/worlds_local/
sudo rsync -a data/ test/data/
MODS_DIRECTORY="$PWD/test/mods" \
  bash scripts/install-modpack.sh /home/USER/server-modpack.zip

sudo docker compose -p valheim-mod-test --env-file .env.test \
  -f compose.yaml -f compose.test.yaml up -d --no-build
sudo docker compose -p valheim-mod-test --env-file .env.test \
  -f compose.yaml -f compose.test.yaml logs -f --tail=200 valheim
```

Copying an active production world may produce an inconsistent snapshot. Stop
production first or use a fresh `TEST_WORLD` when world contents matter.

Set `TEST_WORLD` to the copied production name for a world-affecting test. Keep
`ModTestWorld` to verify only loader startup and connectivity against a new
world. Set `ARM64_DEVICE=rpi4` in `.env.test` on the verified Pi 4 setup.

The log must contain `[valheim-mods] Starting BepInEx`, followed by BepInEx and
plugin load messages. The wrapper line alone proves only that injection began.

Stop and remove the test container without touching production:

```bash
sudo docker compose -p valheim-mod-test --env-file .env.test \
  -f compose.yaml -f compose.test.yaml down
```

## Promote a tested pack

Use the exact ZIP tested above:

```bash
cd /srv/valheim
sudo ./scripts/backup.sh
bash scripts/install-modpack.sh /home/USER/server-modpack.zip
sed -i 's/^MODS_ENABLED=.*/MODS_ENABLED=true/' .env
sudo docker compose up -d --no-build --force-recreate valheim
sudo docker compose logs -f --tail=200 valheim
bash scripts/modpack-status.sh
```

The manual backup contains `config` and `mods`. Rolling archives contain worlds
only.

## Disable or recover

Inspect the active pack:

```bash
cd /srv/valheim
bash scripts/modpack-status.sh
tail -n 200 mods/BepInEx/LogOutput.log
```

If the loader itself prevents startup, retain the pack for diagnosis and boot
without injection:

```bash
sed -i 's/^MODS_ENABLED=.*/MODS_ENABLED=false/' .env
sudo docker compose up -d --no-build --force-recreate valheim
```

Do not let players enter a modded world in this state. Restore the matching
pack or a backup created before modded content was introduced.
