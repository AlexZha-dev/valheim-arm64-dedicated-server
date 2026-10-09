# Valheim Raspberry Pi command reference

Run these commands on the Raspberry Pi from the project directory:

```bash
cd /srv/valheim
```

## Start, stop and logs

```bash
sudo docker compose up -d --build
sudo docker compose ps -a
sudo docker compose logs -f --tail=100 valheim
sudo docker compose stop -t 180 valheim
sudo docker compose up -d --no-build
```

`Ctrl+C` only leaves the log view; it does not stop the container.

## Crossplay / Join Code

The recommended `.env` values are:

```dotenv
CROSSPLAY=true
SERVER_PUBLIC=0
```

Watch registration messages:

```bash
sudo docker compose logs -f valheim | grep -iE 'join code|game server connected|playfab|registering|opened steam server'
```

Crossplay normally does not require router port forwarding. Players use the Join Code provided by Valheim.

## Local network or private overlay

For a LAN or private VPN/overlay connection:

```dotenv
CROSSPLAY=false
SERVER_PUBLIC=0
```

Players connect to the Pi address on UDP `2456`. Check the sockets:

```bash
sudo ss -lunp | grep -E ':(2456|2457)([[:space:]]|$)'
```

The optional ZeroTier firewall helper is only for hosts that really use ZeroTier:

```bash
sudo ./scripts/ufw-zerotier.sh ztXXXXXXXXXX
sudo ufw status verbose
```

## Saves and manual backups

```bash
sudo ./scripts/backup.sh
find backups/manual -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort
find backups/valheim -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort
ls -lah config/worlds_local
ls -lah backups/manual backups/valheim
```

The `SAVEINTERVAL` value is in seconds. For example, `SAVEINTERVAL=600` saves approximately every 10 minutes.

## Automatic rolling backups

The Valheim image creates the hourly ZIP archives itself; there is no second backup sidecar. Set the interval and two retention limits in `.env`:

```dotenv
BACKUPS_INTERVAL=3600
BACKUPS_MAX_AGE=14
BACKUPS_MAX_COUNT=168
BACKUPS_ZIP=true
```

`BACKUPS_MAX_COUNT=168` is roughly one week of hourly archives. A backup is deleted as soon as either its age or the maximum count is exceeded. `BACKUPS_CRON` overrides `BACKUPS_INTERVAL` if it is set.

Apply a changed schedule or retention:

```bash
sudo docker compose up -d --force-recreate --no-build valheim
sudo docker compose logs --tail=100 valheim | grep -i backup
```

## Difficulty and world modifiers

```dotenv
SERVER_ARGS=-preset hard
# SERVER_ARGS=-preset hard -modifier combat hard -modifier deathpenalty casual -modifier resources more -modifier raids none
# SERVER_ARGS=-setkey nobuildcost -setkey nomap
```

Apply changed environment values:

```bash
sudo docker compose up -d --force-recreate --no-build
sudo docker compose logs --tail=100 valheim
```

Check the `Final Valheim parameters` line in the log.

## Optional BepInEx modpack

The detailed workflow is in [`MODS.md`](MODS.md). Vanilla is the default:

```dotenv
MODS_ENABLED=false
```

Install a complete, user-maintained BepInEx server pack only while its target
container is stopped:

```bash
sudo docker compose stop -t 180 valheim
bash scripts/install-modpack.sh /home/USER/server-modpack.zip
sed -i 's/^MODS_ENABLED=.*/MODS_ENABLED=true/' .env
sudo docker compose up -d --no-build --force-recreate valheim
sudo docker compose logs -f --tail=200 valheim
bash scripts/modpack-status.sh
```

Use `compose.test.yaml` with `.env.test` and `-p valheim-mod-test` to test a
pack on port `2458` before production. Keep Crossplay only for packs whose
authors explicitly support dedicated Crossplay.

## Admin and access lists

```dotenv
ADMINLIST_IDS=Steam_00000000000000000
# BANNEDLIST_IDS=Steam_00000000000000000
# PERMITTEDLIST_IDS=Steam_00000000000000000
```

Use exact platform IDs from the Valheim log or the in-game F2 panel. Multiple IDs can be separated by spaces or commas. Files are written under `/config`:

```bash
ls -lah config/adminlist.txt config/bannedlist.txt config/permittedlist.txt
```

## Update the image

```bash
sudo docker compose stop -t 180
sudo docker compose build --pull
sudo docker compose up -d --no-build
```

Base images are pinned. A regular build is reproducible; follow `UPSTREAM.md`
for a deliberate base-image update.

Do not remove `config` and do not run `docker compose down -v` when the world must be preserved.

## Raspberry Pi health

```bash
sudo ./scripts/health.sh
htop
free -h
vmstat 2
df -h /srv/valheim
vcgencmd measure_temp
vcgencmd get_throttled
sudo docker stats --no-stream valheim
```

If the server exits unexpectedly:

```bash
sudo docker compose ps -a
sudo docker compose logs --tail=200 valheim
sudo docker inspect --format='status={{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}}' valheim
dmesg | tail -n 100
swapon --show
```

## Configuration validation

```bash
sudo docker compose config --quiet
sudo docker compose images
```
