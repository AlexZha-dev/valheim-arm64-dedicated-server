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
PUBLIC=0
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
PUBLIC=0
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
find backups -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort
ls -lah config/worlds_local
ls -lah config/backups backups/compose
```

The `SAVEINTERVAL` value is in seconds. For example, `SAVEINTERVAL=600` saves approximately every 10 minutes.

## Automatic backup sidecar

```bash
sudo docker compose ps valheim-backup
sudo docker compose logs -f --tail=50 valheim-backup
```

Set the interval and retention in `.env`:

```dotenv
BACKUP_INTERVAL=3600
BACKUP_RETENTION_DAYS=14
```

Apply a changed interval:

```bash
sudo docker compose up -d --force-recreate valheim-backup
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
