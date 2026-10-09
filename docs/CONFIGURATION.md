# Configuration reference

Docker Compose reads server settings from `/srv/valheim/.env`. Create it from
the tracked template and keep it private:

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

Run `sudo docker compose config --quiet` after every edit. Most settings take
effect only after recreating the container:

```bash
sudo docker compose up -d --no-build --force-recreate valheim
```

Rebuilding the image is unnecessary unless `Dockerfile`, files under `docker/`
or an upstream image digest changed.

## Platform

| Variable | Default | Description |
| --- | --- | --- |
| `ARM64_DEVICE` | `generic` | Box64 build selected for the host CPU. Use `rpi4` for the verified Raspberry Pi 4 setup. |
| `TZ` | `UTC` | Container timezone, for example `Europe/Helsinki`. |
| `PUID` | `0` | Numeric owner ID used by the upstream image. Set together with `PGID` when non-root ownership is required. |
| `PGID` | `0` | Numeric group ID used by the upstream image. |

The complete device-profile table is in [Installation](INSTALLATION.md). Leave
the profile at `generic` when no exact match is available.

## Server identity and connection

| Variable | Default | Description |
| --- | --- | --- |
| `NAME` | `Valheim Dedicated Server` | Name presented to players. |
| `PORT` | `2456` | Base UDP port. Valheim also uses the next port. |
| `WORLD` | `DedicatedWorld` | World name without `.db`, `.db2`, `.fwl` or `.fwl2`. |
| `PASSWORD` | placeholder | Server password. Replace it before starting. |
| `SERVER_PUBLIC` | `0` | `1` lists the server publicly; `0` keeps it out of the browser. |
| `CROSSPLAY` | `true` | Enables PlayFab Crossplay and Join Code registration. |

If no save matching `WORLD` exists, Valheim creates a new world during the
first successful start. If importing a save, the name must match exactly,
including case and non-ASCII characters.

The Compose variable is called `SERVER_PUBLIC`, not `PUBLIC`. Windows defines
`PUBLIC` as a system path and can silently override a Compose `.env` value.

`PASSWORD_FILE` is also accepted by the container when supplied through a
Compose override that mounts a secret file. It takes precedence over
`PASSWORD`; the default Compose file does not create or mount that secret.

## Saves and native backup copies

| Variable | Default | Unit | Description |
| --- | ---: | --- | --- |
| `SAVEINTERVAL` | `900` | seconds | Interval between Valheim world saves. |
| `BACKUPS` | `4` | files | Number of Valheim-managed `WORLD_backup_auto-*` copies. |
| `BACKUPSHORT` | `7200` | seconds | Short native-backup interval. |
| `BACKUPLONG` | `43200` | seconds | Long native-backup interval. |

Native copies are stored beside the active world in `config/worlds_local`.
They are separate from the rolling ZIP archives described below.

## Rolling and manual archives

| Variable | Default | Description |
| --- | --- | --- |
| `BACKUPS_INTERVAL` | `3600` | Seconds between rolling world archives. |
| `BACKUPS_CRON` | empty | Cron schedule that replaces `BACKUPS_INTERVAL`, for example `"5 * * * *"`. |
| `BACKUPS_MAX_AGE` | `14` | Maximum rolling archive age in days. |
| `BACKUPS_MAX_COUNT` | `168` | Maximum number of rolling archives. |
| `BACKUPS_ZIP` | `true` | Stores rolling archives in ZIP format. |
| `MANUAL_BACKUP_RETENTION_DAYS` | `30` | Age limit applied by `scripts/backup.sh`; `0` disables pruning. |

The first rolling limit reached wins. At one archive per hour, `168` retains
roughly seven days even though the age limit is fourteen days. Set the count to
`336` if storage capacity permits fourteen full days.

Do not place backup directories inside `config/worlds_local`: doing so causes
new archives to contain previous archives.

## Updates and scheduled restarts

| Variable | Default | Description |
| --- | --- | --- |
| `UPDATE_INTERVAL` | `0` | Automatic update-check interval; `0` keeps updates manual. |
| `UPDATE_IF_IDLE` | `true` | Allows an update only when the traffic-based idle check passes. |
| `UPDATE_IDLE_CHECKS` | `5` | Number of successful idle checks required. |
| `UPDATE_IDLE_CHECK_INTERVAL` | `60` | Seconds between idle checks. |
| `IDLE_DATAGRAM_WINDOW` | `3` | Traffic observation window used by the upstream scripts. |
| `IDLE_DATAGRAM_MAX_COUNT` | `30` | Maximum datagrams considered idle during the window. |
| `SERVER_STOP_TIMEOUT` | `150` | Seconds allowed for an orderly server stop. |
| `RESTART_CRON` | empty | Optional scheduled restart, for example `"10 5 * * *"`. |
| `RESTART_IF_IDLE` | `true` | Delays a scheduled restart until the server appears idle. |

Automatic updates are intentionally disabled by default. A controlled image
rebuild and graceful restart are easier to observe and roll back on emulated
ARM64 systems.

## Difficulty and world modifiers

Pass official dedicated-server flags through `SERVER_ARGS`. Leave it empty for
normal settings:

```dotenv
SERVER_ARGS=
```

Available presets are `normal`, `casual`, `easy`, `hard`, `hardcore`,
`immersive` and `hammer`:

```dotenv
SERVER_ARGS=-preset easy
```

A preset establishes a group of settings. More specific modifiers may follow
it and override individual parts:

```dotenv
SERVER_ARGS=-preset hard -modifier combat easy -modifier resources more -modifier raids none
```

| Modifier | Accepted values |
| --- | --- |
| `combat` | `veryeasy`, `easy`, `hard`, `veryhard` |
| `deathpenalty` | `casual`, `veryeasy`, `easy`, `hard`, `hardcore` |
| `resources` | `muchless`, `less`, `more`, `muchmore`, `most` |
| `raids` | `none`, `muchless`, `less`, `more`, `muchmore` |
| `portals` | `casual`, `hard`, `veryhard` |

World keys can be added independently:

```dotenv
SERVER_ARGS=-setkey nobuildcost -setkey nomap
```

Supported keys include `nobuildcost`, `playerevents`, `passivemobs` and
`nomap`. Put `-preset` first, modifiers second and `-setkey` flags last. Confirm
the resulting command in the `Final Valheim parameters` log line.

Refer to the
[official Valheim dedicated-server guide](https://valheim.com/support/a-guide-to-dedicated-servers/)
when a game update adds or changes server flags.

## Administrators and access lists

Use the exact platform ID printed by the Valheim log or the in-game F2 panel:

```dotenv
ADMINLIST_IDS=Steam_00000000000000000
BANNEDLIST_IDS=
PERMITTEDLIST_IDS=
```

Crossplay users may have IDs such as `Xbox_...`. Separate multiple IDs with
spaces or commas. The container writes the values to:

```text
/config/adminlist.txt
/config/bannedlist.txt
/config/permittedlist.txt
```

An empty setting leaves an existing file unchanged. Do not publish real player
IDs unnecessarily.

## Optional mods

| Variable | Default | Description |
| --- | --- | --- |
| `MODS_ENABLED` | `false` | Enables the externally managed BepInEx pack mounted from `mods`. |

Read [Mods](MODS.md) before enabling it. Console clients cannot install BepInEx,
and Crossplay support must be confirmed for every exact server-side mod version.
