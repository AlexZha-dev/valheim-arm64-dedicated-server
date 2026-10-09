# Valheim Dedicated Server on Raspberry Pi 4

This directory contains a neutral, reproducible Valheim dedicated-server setup for a 64-bit Raspberry Pi 4 running Raspberry Pi OS or Debian.

The primary connection mode is **Crossplay with a Join Code**. The same container can also be used on a local network or behind a private overlay network by changing the server settings and firewall rules.

The Raspberry Pi runs the ARM64 operating system, while SteamCMD and the Valheim server are executed through Box32/Box64 compatibility layers. The first image build and the first game download can take a long time.

## What is included

- `compose.yaml` - Valheim with its integrated, retention-limited backup scheduler.
- `Dockerfile` - Raspberry Pi 4 image using Box32 for SteamCMD and Box64 for Valheim.
- `.env.example` - safe template for server settings; copy it to `.env` before starting.
- `scripts/prepare-directories.sh` - creates persistent data directories.
- `scripts/backup.sh` - creates a verified archive of the complete `config` directory.
- `scripts/health.sh` - reports container, resource, temperature, throttling and network status.
- `scripts/ufw-zerotier.sh` - optional firewall helper for a ZeroTier-style private overlay.
- `COMMANDS.md` - short operational command reference.

No world save, administrator ID, password, Steam credentials or machine-specific IP address is included in this package.

## Requirements

- Raspberry Pi 4 with a 64-bit OS (`aarch64` / `arm64`).
- Docker Engine and the Docker Compose plugin.
- At least 4 GB of free disk space for the game files and working space.
- Internet access from the Pi for SteamCMD, game updates and Crossplay/PlayFab registration.
- A Valheim client version compatible with the server version.

The Pi is an emulation-based platform. Use a heatsink/fan and monitor temperature during the first build and during gameplay.

## 1. Prepare the Raspberry Pi

Check the architecture:

```bash
uname -m
dpkg --print-architecture
```

The expected output is `aarch64` and `arm64`.

Install basic tools:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl git htop rsync tar gzip unzip ufw
```

Install Docker from the official repository. If a distribution Docker package is already installed, remove only the conflicting packages first:

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc docker-buildx; do
  sudo apt remove -y "$pkg" 2>/dev/null || true
done
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker version
sudo docker compose version
```

If Docker installation was interrupted, repair the package database before continuing:

```bash
sudo dpkg --audit
sudo apt -f install
```

## 2. Copy the project to the Pi

From PowerShell, copy this directory to the Pi. Replace the account and address with your own values:

```powershell
scp -r .\rasbery_pi_server USER@PI_ADDRESS:/home/USER/
```

On the Pi:

```bash
sudo mkdir -p /srv/valheim
sudo cp -a /home/USER/rasbery_pi_server/. /srv/valheim/
sudo chown -R "$USER:$USER" /srv/valheim
cd /srv/valheim
```

Do not copy a live world over a running server. Stop the server and make a backup before replacing files in `config/worlds_local`.

## 3. Configure the server

Create the private environment file:

```bash
cd /srv/valheim
cp .env.example .env
nano .env
```

At minimum, set a unique password with at least five characters:

```dotenv
NAME=Valheim Dedicated Server
WORLD=DedicatedWorld
PASSWORD=replace-with-a-strong-password
SERVER_PUBLIC=0
CROSSPLAY=true
```

`WORLD` is the directory name of the save without `.db`, `.db2`, `.fwl` or `.fwl2`. The default `DedicatedWorld` is only a placeholder; change it to the name of the world you copy to the Pi. `SERVER_PUBLIC` is deliberately not named `PUBLIC`: Windows reserves `PUBLIC` for `C:\\Users\\Public`, which otherwise overrides the Compose setting.

Protect the file and create persistent directories:

```bash
chmod 600 .env
chmod +x scripts/*.sh
./scripts/prepare-directories.sh
```

The default save interval is 15 minutes (`SAVEINTERVAL=900`). Change it in `.env` and recreate the container when needed.

## 4. Crossplay with a Join Code (recommended)

The default configuration uses Crossplay:

```dotenv
CROSSPLAY=true
SERVER_PUBLIC=0
```

`SERVER_PUBLIC=0` keeps the server out of the public browser list. Players join using the Join Code shown by the game/server UI. Crossplay uses the relay service, so router port forwarding is normally not required. The Pi still needs outbound Internet access.

Start the services:

```bash
cd /srv/valheim
sudo docker compose config --quiet
sudo docker compose build --pull
sudo docker compose up -d --no-build
sudo docker compose logs -f --tail=100 valheim
```

Wait for messages such as `Steam game server initialized`, `Opened Steam server`, world loading and a successful server registration. Leaving `logs -f` with `Ctrl+C` does not stop the container.

Useful Crossplay log filter:

```bash
sudo docker compose logs -f valheim | grep -iE 'join code|game server connected|playfab|registering|opened steam server'
```

## 5. Local network or private overlay mode (optional)

Crossplay remains the recommended default. For a local-only or private-overlay server, set:

```dotenv
CROSSPLAY=false
SERVER_PUBLIC=0
```

Players then connect to the Pi's reachable address on UDP port `2456` (for example, `192.168.1.20:2456` on a LAN or the Pi's overlay address on a private VPN). Allow UDP ports `2456-2457` on the interface used by the players. Do not run the ZeroTier firewall helper unless you actually use ZeroTier:

```bash
sudo ./scripts/ufw-zerotier.sh ztXXXXXXXXXX
```

The helper is optional and is not needed for Crossplay.

## 6. Import an existing world

On Windows, a local Valheim world is usually under:

```text
%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local\WORLD_NAME
```

Close Valheim and allow Steam Cloud to finish syncing before copying the world. Copy the complete directory, including all `.fwl*` and `.db*` files:

```powershell
scp -r "$env:USERPROFILE\AppData\LocalLow\IronGate\Valheim\worlds_local\WORLD_NAME" "USER@PI_ADDRESS:/home/USER/"
```

On the Pi, replace `WORLD_NAME` with the actual save name and stop the server first:

```bash
cd /srv/valheim
sudo docker compose stop -t 180 valheim
mkdir -p config/worlds_local
mv "config/worlds_local/WORLD_NAME" "config/worlds_local/WORLD_NAME.before-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
mv "/home/USER/WORLD_NAME" config/worlds_local/
sudo chown -R "$USER:$USER" "config/worlds_local/WORLD_NAME"
find "config/worlds_local/WORLD_NAME" -maxdepth 1 -type f -printf '%f %s bytes\n'
```

Set the same name in `.env`:

```dotenv
WORLD=WORLD_NAME
```

For an archive, validate it before extraction:

```bash
gzip -t /home/USER/world-save.tar.gz
tar -tzf /home/USER/world-save.tar.gz | head
```

Never use a zero-byte or incomplete archive.

## 7. Difficulty, admins and access lists

Optional difficulty flags are configured with `SERVER_ARGS`:

```dotenv
SERVER_ARGS=-preset hard
# or:
# SERVER_ARGS=-preset hard -modifier combat hard -modifier deathpenalty casual -modifier resources more -modifier raids none
# SERVER_ARGS=-setkey nobuildcost -setkey nomap
```

Set administrator and access-list platform IDs in `.env`. Use the exact ID format printed by Valheim, such as `Steam_...` or `Xbox_...`:

```dotenv
ADMINLIST_IDS=Steam_00000000000000000
# BANNEDLIST_IDS=Steam_00000000000000000
# PERMITTEDLIST_IDS=Steam_00000000000000000
```

Separate multiple IDs with spaces or commas. The image writes them to `/config/adminlist.txt`, `/config/bannedlist.txt` and `/config/permittedlist.txt`.

Apply changes without rebuilding the image:

```bash
sudo docker compose up -d --force-recreate --no-build
```

## 8. Backups and updates

There is one periodic archive scheduler: the `valheim-backup` program included in the Valheim image. It creates a ZIP of `worlds_local` in `backups/valheim` on startup and then every hour. It removes old archives by both age and count; the first limit reached wins:

```dotenv
# Four emergency copies maintained by Valheim itself beside the world.
BACKUPS=4

# Image-managed rolling archives in ./backups/valheim.
BACKUPS_INTERVAL=3600
BACKUPS_MAX_AGE=14
BACKUPS_MAX_COUNT=168
BACKUPS_ZIP=true
```

At the default hourly interval, `BACKUPS_MAX_COUNT=168` caps the rolling set at roughly seven days even if `BACKUPS_MAX_AGE` is larger. Use `336` if the available disk space permits keeping up to 14 days of hourly archives. `BACKUPS_CRON` may replace the interval when a specific schedule is needed.

Valheim itself also maintains the `WORLD_backup_auto-*` copies inside `config/worlds_local`; their count is controlled by `BACKUPS`. Do not put any backup directory inside `worlds_local`, otherwise every archive would include older archives.

Create and verify a full manual backup:

```bash
sudo ./scripts/backup.sh
ls -lah backups/manual backups/valheim config/worlds_local
```

The manual archive contains `config` (worlds and access lists), is made only after a clean server stop, and is verified before the server is started again. `MANUAL_BACKUP_RETENTION_DAYS=30` controls its cleanup; set it to `0` to retain manual archives indefinitely.

### Migrating from the previous duplicate-backup setup

Older revisions created duplicate `.tar.gz` archives with a separate Compose sidecar. The following preserves all existing files, moves the image-created ZIP archives into their new managed directory, and removes only the obsolete sidecar container:

```bash
cd /srv/valheim
sudo docker compose stop -t 180
sudo docker stop -t 30 valheim-backup 2>/dev/null || true
stamp=$(date +%Y%m%d-%H%M%S)
sudo install -d -m 0750 backups/valheim backups/legacy
sudo find backups -maxdepth 1 -type f -name 'worlds-*.zip' -exec mv -t backups/valheim -- {} +
if [ -d backups/compose ]; then sudo mv backups/compose "backups/legacy/compose-$stamp"; fi
sudo docker compose up -d --remove-orphans --no-build
```

Replace any legacy `PUBLIC=...` line in `.env` with `SERVER_PUBLIC=...` before starting. The old `.tar.gz` files stay under `backups/legacy` and are not deleted automatically. Inspect them, copy any you want to keep elsewhere, and remove them manually only when you are satisfied with the new backups.

To update the image, stop it gracefully, rebuild and start it again:

```bash
sudo docker compose stop -t 180
sudo docker compose build --pull
sudo docker compose up -d --no-build
```

Do not run `docker compose down -v` and do not delete `config` if you need to keep the world.

## 9. Monitoring and troubleshooting

```bash
sudo ./scripts/health.sh
sudo docker compose ps -a
sudo docker compose logs --tail=200 valheim
sudo docker inspect --format='status={{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}}' valheim
free -h
df -h /srv/valheim
sudo docker stats --no-stream valheim
vcgencmd measure_temp
vcgencmd get_throttled
sudo ss -lunp | grep -E ':(2456|2457)([[:space:]]|$)'
```

On a Pi 4, keep the CPU temperature below the throttling range and use active cooling. If SteamCMD aborts or the server exits with code `139`, inspect `dmesg`, available memory/swap and the Steam diagnostics directory:

```bash
dmesg | tail -n 100
free -h
swapon --show
df -h /srv/valheim
ls -lah steam-diagnostics
```

The game server is still running when `logs -f` is closed. Check `docker compose ps` instead of using the log view as the process status.

## Persistent paths

```text
/srv/valheim/config/worlds_local   world saves
/srv/valheim/backups/valheim       hourly ZIP archives, automatically pruned
/srv/valheim/backups/manual        verified manual archives, age-pruned
/srv/valheim/backups/legacy        preserved pre-migration archives, never auto-pruned
/srv/valheim/data                  downloaded Valheim files
/srv/valheim/steam-diagnostics     SteamCMD logs
```

Keep these directories outside Git. The included `.gitignore` and `.dockerignore` exclude saves, backups, downloaded files, diagnostics and `.env`.

## License and upstream components

This setup is a community Docker configuration. Valheim, SteamCMD, Box64, Box32 and the referenced base images remain subject to their respective licenses and terms. Do not redistribute proprietary game files or Steam credentials.
