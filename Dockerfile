# syntax=docker/dockerfile:1.7
# Raspberry Pi 4 image: x86 SteamCMD through Box32 and Valheim through Box64.
# The native ARM64 SteamCMD can fail with Illegal instruction on some Pi 4 systems.

FROM ghcr.io/riptidewave93/arm64-valheim:pi4 AS valheim_scripts

FROM ghcr.io/sonroyaalmerol/steamcmd-arm64:root-trixie

USER root
ENV ARM64_DEVICE=rpi4 \
    DEBUGGER=/usr/local/bin/box64 \
    STEAM_PLATFORM=linux32

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tini zip libatomic1 libpulse0 libpulse-mainloop-glib0 \
        libsdl2-2.0-0 libsdl3-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the supervisor from the layouts used by released arm64-valheim images.
# Current images keep it at /usr/local/lib/valheim/bootstrap; some older images
# used /root/bootstrap or /usr/local/sbin/bootstrap. A floating base-image tag
# may contain any one of these layouts.
# BuildKit's bind mount lets us detect the layout before copying files, whereas
# COPY --from would fail immediately when one source path does not exist.
RUN --mount=type=bind,from=valheim_scripts,source=/,target=/mnt/valheim_scripts \
    set -eux; \
    scripts=/mnt/valheim_scripts; \
    if [ -f "$scripts/root/bootstrap" ]; then \
        cp "$scripts/root/bootstrap" /root/bootstrap; \
    elif [ -f "$scripts/usr/local/sbin/bootstrap" ]; then \
        cp "$scripts/usr/local/sbin/bootstrap" /root/bootstrap; \
    elif [ -f "$scripts/usr/local/lib/valheim/bootstrap" ]; then \
        cp "$scripts/usr/local/lib/valheim/bootstrap" /root/bootstrap; \
    else \
        echo 'No Valheim bootstrap script found in the base image' >&2; exit 1; \
    fi; \
    mkdir -p /usr/local/lib /usr/local/etc /usr/local/share/valheim /usr/local/sbin; \
    if [ -d "$scripts/usr/local/lib/valheim" ]; then \
        cp -a "$scripts/usr/local/lib/valheim" /usr/local/lib/; \
    fi; \
    if [ -d "$scripts/usr/local/etc/valheim" ]; then \
        cp -a "$scripts/usr/local/etc/valheim" /usr/local/etc/; \
    fi; \
    if [ -d "$scripts/usr/local/share/valheim" ]; then \
        cp -a "$scripts/usr/local/share/valheim" /usr/local/share/; \
    fi; \
    for name in valheim-backup valheim-updater valheim-server valheim-bootstrap valheim-is-idle valheim-status; do \
        if [ -f "$scripts/usr/local/bin/$name" ]; then cp "$scripts/usr/local/bin/$name" /usr/local/bin/; fi; \
    done; \
    if [ -f "$scripts/usr/local/bin/busybox" ]; then cp "$scripts/usr/local/bin/busybox" /usr/local/bin/; fi; \
    for name in supervisord supervisorctl; do \
        if [ -f "$scripts/usr/bin/$name" ]; then cp "$scripts/usr/bin/$name" /usr/bin/; fi; \
    done; \
    if [ -f "$scripts/usr/lib/x86_64-linux-gnu/libogg.so.0" ]; then \
        mkdir -p /usr/lib/x86_64-linux-gnu; \
        cp "$scripts/usr/lib/x86_64-linux-gnu/libogg.so.0" /usr/lib/x86_64-linux-gnu/; \
    fi; \
    test -x /home/steam/steamcmd/linux32/steamcmd; \
    mkdir -p /opt; \
    if [ ! -e /opt/steamcmd ]; then ln -s /home/steam/steamcmd /opt/steamcmd; fi; \
    for file in /root/bootstrap /usr/local/lib/valheim/* /usr/local/etc/valheim/* /usr/local/bin/valheim-*; do \
        if [ -f "$file" ]; then \
            sed -i \
                -e 's|^STEAMCMD_DIR=.*|STEAMCMD_DIR="/home/steam/steamcmd"|' \
                -e 's|steamcmd_linuxarm64\.tar\.gz|steamcmd_linux.tar.gz|g' \
                -e 's|/linuxarm64/steamcmd|/linux32/steamcmd|g' \
                "$file"; \
        fi; \
    done; \
    chown -R root:root /home/steam/steamcmd; \
    bash -n /root/bootstrap; \
    if [ -f /usr/local/lib/valheim/common ]; then bash -n /usr/local/lib/valheim/common; fi; \
    if [ -f /usr/local/etc/valheim/common ]; then bash -n /usr/local/etc/valheim/common; fi; \
    mkdir -p /opt/valheim

WORKDIR /root
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/root/bootstrap"]
