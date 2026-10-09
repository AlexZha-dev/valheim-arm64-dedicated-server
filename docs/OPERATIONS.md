# Valheim Dedicated Server Operations and Troubleshooting

Run commands from the deployment directory unless a section says otherwise:

```bash
cd /srv/valheim
```

## Routine lifecycle

```bash
# Start an existing build
sudo docker compose up -d --no-build

# Show state
sudo docker compose ps -a

# Follow logs; Ctrl+C only closes the viewer
sudo docker compose logs -f --tail=100 valheim

# Save and stop gracefully
sudo docker compose stop -t 180 valheim

# Recreate after changing .env or compose.yaml
sudo docker compose up -d --no-build --force-recreate valheim
```

Avoid `docker kill`: it prevents Valheim from completing its shutdown save.

## Verify a healthy server

```bash
sudo ./scripts/health.sh
sudo docker compose ps -a
sudo docker inspect \
  --format='status={{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}}' \
  valheim
```

Useful Crossplay messages:

```bash
sudo docker compose logs -f valheim \
  | grep -iE 'join code|game server connected|playfab|registering|opened steam server'
```

A healthy start initializes Steam, loads the selected world, registers the game
server and remains `Up`. Shader, audio and headless-renderer warnings are often
expected. A restart loop, exit code `139`, missing world or repeated failed
registration needs investigation.

## Resources and temperature

```bash
sudo docker stats --no-stream valheim
free -h
vmstat 2
df -h /srv/valheim
dmesg | tail -n 100
swapon --show
```

On Raspberry Pi hardware:

```bash
vcgencmd measure_temp
vcgencmd get_throttled
```

`scripts/health.sh` uses the generic Linux thermal-zone value when `vcgencmd`
is unavailable. The exact throttling threshold is hardware-specific; sustained
single-board-computer workloads should use active cooling.

## Backup model

| Backup | Location | Contents | Retention |
| --- | --- | --- | --- |
| Valheim native | `config/worlds_local` | Automatic copies of each world | `BACKUPS` |
| Rolling | `backups/valheim` | `worlds_local` ZIP archives | Age and count limits |
| Manual | `backups/manual` | Complete `config` and optional `mods` | Age limit on next manual run |

Create a consistent manual backup:

```bash
sudo ./scripts/backup.sh
ls -lah backups/manual backups/valheim config/worlds_local
```

The script stops the server only when it is currently running, validates the
archive, applies manual retention and then restores the previous running state.

Inspect archives without extracting them:

```bash
sudo tar -tzf backups/manual/config-YYYYMMDD-HHMMSS.tar.gz | less
sudo unzip -l backups/valheim/worlds-YYYYMMDD-HHMMSS.zip | less
```

Before a restore, copy the chosen archive somewhere safe and stop the server.
Extract it into a separate staging directory, inspect the paths, then move the
current `config` aside instead of deleting it:

```bash
sudo docker compose stop -t 180 valheim
restore_dir="$(mktemp -d /srv/valheim/restore.XXXXXX)"
sudo tar -xzf backups/manual/config-YYYYMMDD-HHMMSS.tar.gz -C "$restore_dir"
sudo find "$restore_dir" -maxdepth 3 -type f -printf '%p %s bytes\n' | head -n 50
sudo mv config "config.before-restore-$(date +%Y%m%d-%H%M%S)"
sudo cp -a "$restore_dir/config" ./config
sudo docker compose up -d --no-build valheim
```

Keep the previous directory and staging extraction until the restored world has
been loaded and checked in-game.

## Update the server image

Create a backup and update during a maintenance window:

```bash
sudo ./scripts/backup.sh
sudo docker compose stop -t 180 valheim
sudo docker compose build --pull
sudo docker compose up -d --no-build
sudo docker compose logs -f --tail=150 valheim
```

Base images are pinned by digest, so `--pull` does not silently select an
untested upstream release. Follow [Upstream maintenance](UPSTREAM.md) when
changing a digest.

If the new container fails, preserve its logs, stop it, restore the previous
Git revision and rebuild. Bind-mounted worlds are not embedded in either image.

## Rolling-back duplicated legacy backups

Older project revisions used a second Compose backup sidecar. This migration
preserves all files, moves ZIP archives under the managed directory and removes
only the obsolete container:

```bash
cd /srv/valheim
sudo docker compose stop -t 180
sudo docker stop -t 30 valheim-backup 2>/dev/null || true
stamp="$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 0750 backups/valheim backups/legacy
sudo find backups -maxdepth 1 -type f -name 'worlds-*.zip' \
  -exec mv -t backups/valheim -- {} +
if [ -d backups/compose ]; then
  sudo mv backups/compose "backups/legacy/compose-$stamp"
fi
sudo docker compose up -d --remove-orphans --no-build
```

Legacy `.tar.gz` files remain under `backups/legacy` and are never pruned
automatically. Delete them only after verifying and copying anything important.

## Network checks

Check the host sockets in direct-connect mode:

```bash
sudo ss -lunp | grep -E ':(2456|2457)([[:space:]]|$)'
sudo ufw status verbose
```

Basic outbound tests:

```bash
ping -c 4 1.1.1.1
getent hosts api.steampowered.com
curl -4 -I --connect-timeout 10 https://api.steampowered.com/
```

Crossplay requires more than basic HTTP reachability. Inspect Steam connection
logs when PlayFab or Steam registration repeatedly fails:

```bash
sudo docker exec valheim sh -c \
  'find /root/Steam -maxdepth 3 -type f -name "connection_log*.txt" -print -exec tail -n 80 {} \;'
```

## Common failures

| Symptom | First checks |
| --- | --- |
| `Illegal instruction` | Confirm `uname -m`, choose the correct `ARM64_DEVICE`, then try `generic`. |
| SteamCMD aborts during a download | Check RAM, swap, disk space, temperature and `steam-diagnostics`. Retry after confirming the partial data directory is writable. |
| Exit code `139` | Inspect `dmesg`, memory pressure, Box64 profile and the last server log lines. |
| `Missing configuration` | Verify Steam connectivity and diagnostics; do not assume a Steam account is required for anonymous AppID `896660`. |
| World starts without expected buildings | Stop immediately and verify that `WORLD` points to the intended complete save pair/directory. |
| No Join Code | Confirm `CROSSPLAY=true`, outbound Internet access and successful PlayFab registration. |
| Repeated backup growth | Confirm backups are outside `config/worlds_local` and inspect retention variables. |

Warnings about slow location placement during world generation are normally
informational when placement eventually completes. Treat them as a problem only
when they accompany sustained stalls, crashes or restart loops.

## Configuration and file checks

```bash
sudo docker compose config --quiet
sudo docker compose images
find config/worlds_local -maxdepth 2 -type f -printf '%p %s bytes\n' | sort
find backups -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort
```
