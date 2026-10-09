# Optional BepInEx mods

This bundle is a vanilla Valheim server unless `MODS_ENABLED=true` is set in
`.env`. Mods execute third-party code on the Pi and can alter a world
permanently. The server owner is responsible for choosing, versioning, testing
and updating every mod.

No plugin, mod manager, Thunderstore account, URL or DLL is included here.

## Compatibility first

There are three different kinds of Valheim mod:

- **Client-only:** install it only on the relevant PC clients, never on this
  server.
- **Server-only:** install it on the Pi only. Keep `CROSSPLAY=true` only when
  the author explicitly says that the exact version works on a dedicated
  Crossplay server. This is the only category that may be suitable for console
  players.
- **Synchronized, content or RPC mod:** the server and every PC player need
  the same versions and dependencies. Disable Crossplay (`CROSSPLAY=false`):
  Xbox and other console clients cannot run BepInEx.

Do not treat a mod marked "server-side" as a Crossplay guarantee. Test the
exact pack after every Valheim, BepInEx or mod update. Valheim's `-crossplay`
mode uses the PlayFab backend; it is not a generic compatibility layer for
third-party code.

## Server modpack contract

`scripts/install-modpack.sh` accepts one local ZIP archive. Its payload must
have either this layout at the archive root, or the same layout inside one
`BepInExPack_Valheim/` directory:

```text
BepInEx/
  core/BepInEx.Preloader.dll
  plugins/
  config/
doorstop_libs/
  libdoorstop_x64.so
unstripped_corlib/
modpack.lock                 # strongly recommended
```

Start with the Linux x64 BepInExPack required by the selected mods. Add the
server plugin DLLs and their dependencies to `BepInEx/plugins/`, then package
the three directories above into one ZIP. Do not install a Windows-only pack.
The installer deliberately ignores the vendor's `start_server_bepinex.sh`: the
container owns the launch command and injects Doorstop through Box64.

`modpack.lock` is plain text owned by the server owner. Record every package,
its exact version, source URL and SHA-256 hash. For example:

```text
# package | version | source | sha256
BepInExPack_Valheim | 5.x.y | https://example.invalid/release.zip | SHA256
Author-ModName | 1.2.3 | https://example.invalid/mod.zip | SHA256
```

Keep the ZIP and lock file outside Git as well. They are needed to reproduce a
world after an update or a restore.

## Install and test a pack

Build the current image first. The production server must be stopped before its
pack is replaced:

```bash
cd /srv/valheim
sudo docker compose build --pull valheim
sudo docker compose stop -t 180 valheim
bash scripts/install-modpack.sh /home/USER/server-modpack.zip
```

The script checks ZIP integrity and unsafe paths, validates the BepInEx
preloader and x86_64 Doorstop library, then activates the pack. It never
downloads arbitrary code. The former `mods/` directory is preserved as
`mods.previous-TIMESTAMP` for rollback.

Use the included isolated test service before production. It has a different
container, world/data/mods directories and UDP port (`2458`):

```bash
cd /srv/valheim
cp .env.test.example .env.test
nano .env.test

sudo install -d test/config/worlds_local test/data test/backups/valheim \
  test/steam-diagnostics
sudo rsync -a config/worlds_local/ test/config/worlds_local/
sudo rsync -a data/ test/data/
MODS_DIRECTORY="$PWD/test/mods" bash scripts/install-modpack.sh \
  /home/USER/server-modpack.zip

sudo docker compose -p valheim-mod-test --env-file .env.test \
  -f compose.yaml -f compose.test.yaml up -d --no-build
sudo docker compose -p valheim-mod-test --env-file .env.test \
  -f compose.yaml -f compose.test.yaml logs -f --tail=200 valheim
```

Set `TEST_WORLD` in `.env.test` to the copied production world directory name
when testing world-affecting content. Leave it as `ModTestWorld` to verify only
the loader and connection path against a newly generated test world.

The log must contain `[valheim-mods] Starting BepInEx` and BepInEx loader
messages before you test player connections. The loader line alone only proves
that BepInEx started; check its log and the mod documentation to confirm each
plugin actually loaded.

Stop the test without touching production data:

```bash
sudo docker compose -p valheim-mod-test --env-file .env.test \
  -f compose.yaml -f compose.test.yaml down
```

To promote the already tested archive, make a manual backup and install the
same ZIP into `mods/`:

```bash
cd /srv/valheim
sudo ./scripts/backup.sh
bash scripts/install-modpack.sh /home/USER/server-modpack.zip
sed -i 's/^MODS_ENABLED=.*/MODS_ENABLED=true/' .env
sudo docker compose up -d --no-build --force-recreate valheim
sudo docker compose logs -f --tail=200 valheim
```

The manual backup contains `config/` and `mods/`. The hourly rolling archives
contain worlds only, so make a manual backup before every modpack change.

## Status and recovery

```bash
cd /srv/valheim
bash scripts/modpack-status.sh
tail -n 200 mods/BepInEx/LogOutput.log
```

If a pack prevents startup, retain its files for diagnosis and boot vanilla:

```bash
sed -i 's/^MODS_ENABLED=.*/MODS_ENABLED=false/' .env
sudo docker compose up -d --no-build --force-recreate valheim
```

Do not load a world containing modded content in vanilla mode just because the
server starts. Restore the matching modpack first, or restore a backup created
before the content was introduced.
