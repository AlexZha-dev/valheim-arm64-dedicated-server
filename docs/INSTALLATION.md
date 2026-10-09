# Installation

This guide installs the server on a clean Linux ARM64 host. Commands are tested
on Raspberry Pi OS Lite 64-bit, which is Debian-based. On another distribution,
install Docker Engine and the Compose plugin using that distribution's official
instructions, then continue at [Deploy the project](#deploy-the-project).

## Requirements

- A 64-bit ARM CPU and Linux operating system.
- Docker Engine with `docker compose` support.
- At least 4 GB of free storage for a vanilla server.
- More free space for retained backups, a second test installation or mods.
- Outbound Internet access for image pulls, SteamCMD and Crossplay registration.
- Active cooling for small single-board computers under sustained load.

Confirm the host architecture:

```bash
uname -m
dpkg --print-architecture
```

Expected values on Raspberry Pi OS are `aarch64` and `arm64`. `armv7l` is a
32-bit installation and is not supported.

## Install Docker on Raspberry Pi OS or Debian

Install the basic administration tools:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl git htop rsync tar gzip unzip ufw
```

Remove only distribution packages that conflict with Docker CE, then add the
official Docker repository:

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc docker-buildx; do
  sudo apt remove -y "$pkg" 2>/dev/null || true
done
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker version
sudo docker compose version
```

If package installation was previously interrupted:

```bash
sudo dpkg --audit
sudo apt -f install
```

## Deploy the project

Clone the renamed public repository directly into its production location:

```bash
sudo git clone \
  https://github.com/AlexZha-dev/valheim-arm64-dedicated-server.git \
  /srv/valheim
sudo chown -R "$USER:$USER" /srv/valheim
cd /srv/valheim
```

Alternatively, copy an existing checkout from Windows PowerShell:

```powershell
scp -r .\valheim-arm64-dedicated-server USER@SERVER_ADDRESS:/home/USER/
```

Then place it under `/srv` on the host:

```bash
sudo mkdir -p /srv/valheim
sudo cp -a /home/USER/valheim-arm64-dedicated-server/. /srv/valheim/
sudo chown -R "$USER:$USER" /srv/valheim
cd /srv/valheim
```

## Select the ARM64 profile

The portable default is `generic`. The runtime also contains optimized Box64
builds for the following device families:

| Hardware | `ARM64_DEVICE` |
| --- | --- |
| Generic ARM64 | `generic` |
| Raspberry Pi 3 | `rpi3` |
| Raspberry Pi 4 | `rpi4` |
| Raspberry Pi 5, 4 KiB pages | `rpi5` |
| Raspberry Pi 5, 16 KiB pages | `rpi5_16k` |
| Rockchip RK3399 | `rk3399` |
| Orange Pi 5 / Rockchip RK3588 | `rk3588` |
| Apple M-series with Asahi Linux | `m1` |
| Snapdragon 888 | `sd888` |
| Snapdragon Oryon | `sdoryon1` |
| NVIDIA Tegra X1 | `tegrax1` |
| NVIDIA Tegra T194 | `tegra_t194` |
| SolidRun LX2160A | `lx2160a` |

Only `rpi4` has been verified by this project. If a specialized profile causes
an illegal instruction or startup failure, return to `generic` and collect the
diagnostics described in [Operations](OPERATIONS.md).

## Configure and start

```bash
cd /srv/valheim
cp .env.example .env
nano .env
chmod 600 .env
chmod +x scripts/*.sh
./scripts/prepare-directories.sh
```

At minimum, replace the password and review the device profile:

```dotenv
ARM64_DEVICE=generic
NAME=Valheim Dedicated Server
WORLD=DedicatedWorld
PASSWORD=replace-with-a-strong-password
CROSSPLAY=true
SERVER_PUBLIC=0
```

Use `ARM64_DEVICE=rpi4` on the verified Raspberry Pi 4 configuration. The
password must meet Valheim's minimum length requirement and should not be reused
elsewhere.

Start the server:

```bash
sudo docker compose config --quiet
sudo docker compose build --pull
sudo docker compose up -d --no-build
sudo docker compose logs -f --tail=100 valheim
```

The initial build and Steam download can be slow. A healthy first start reaches
world loading and server registration without entering a restart loop.

## Connection modes

### Crossplay and Join Code

This is the default and recommended mode:

```dotenv
CROSSPLAY=true
SERVER_PUBLIC=0
```

Players connect using the Join Code emitted after successful PlayFab
registration. Router port forwarding is normally unnecessary, but the host
still needs unrestricted outbound Internet access.

### LAN or private overlay

```dotenv
CROSSPLAY=false
SERVER_PUBLIC=0
```

Players connect to the reachable host address on UDP port `2456`. Allow
`2456-2457/udp` only on the intended interface. The optional ZeroTier helper is
appropriate only when ZeroTier is already installed and configured:

```bash
sudo ./scripts/ufw-zerotier.sh ztXXXXXXXXXX
```

Review that script before running it because it changes the host firewall.

## Import an existing world

On Windows, local worlds are normally stored under:

```text
%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local
```

Close Valheim, allow Steam Cloud to finish, and transfer the complete world
directory or matching `.db*` and `.fwl*` files. Never copy a live save over a
running server.

Example transfer from PowerShell:

```powershell
scp -r "$env:USERPROFILE\AppData\LocalLow\IronGate\Valheim\worlds_local\WORLD_NAME" `
  "USER@SERVER_ADDRESS:/home/USER/"
```

On the server:

```bash
cd /srv/valheim
sudo ./scripts/backup.sh
sudo docker compose stop -t 180 valheim
mkdir -p config/worlds_local
mv "config/worlds_local/WORLD_NAME" \
  "config/worlds_local/WORLD_NAME.before-$(date +%Y%m%d-%H%M%S)" \
  2>/dev/null || true
mv "/home/USER/WORLD_NAME" config/worlds_local/
find "config/worlds_local/WORLD_NAME" -maxdepth 1 -type f \
  -printf '%f %s bytes\n'
```

Set `WORLD=WORLD_NAME` in `.env`, then start and verify the loaded world:

```bash
sudo docker compose up -d --no-build
sudo docker compose logs -f --tail=150 valheim
```

Validate archives before extracting them:

```bash
gzip -t /home/USER/world-save.tar.gz
tar -tzf /home/USER/world-save.tar.gz | head
```

## Migrate an existing Raspberry Pi 4 deployment

The generic project name changes the local image tag, but not any persistent
path. Preserve the verified Pi profile explicitly:

```bash
cd /srv/valheim
grep -q '^ARM64_DEVICE=' .env \
  && sed -i 's/^ARM64_DEVICE=.*/ARM64_DEVICE=rpi4/' .env \
  || printf '\nARM64_DEVICE=rpi4\n' >> .env
sudo ./scripts/backup.sh
sudo docker compose build --pull
sudo docker compose up -d --no-build --force-recreate valheim
```

The old `valheim-pi4-box32:local` image may remain unused after migration. Do
not remove it until the new container has loaded the correct world and remained
stable.
