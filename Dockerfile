# syntax=docker/dockerfile:1.7
# ARM64 image: x86 SteamCMD through Box32 and Valheim through Box64.
# Base-image digests are deliberately pinned; see docs/UPSTREAM.md before updating.

ARG VALHEIM_SCRIPTS_IMAGE=ghcr.io/riptidewave93/arm64-valheim@sha256:1ebe7e5a31a8f12c0d852cb11695a526431dd6d1629b3bf3a33f88d7538eee49
ARG STEAMCMD_IMAGE=ghcr.io/sonroyaalmerol/steamcmd-arm64@sha256:11ca8c6dd83931bc8a26f2b33eb7a6a452740ea55a9afc27aa744e68dcb448f8

FROM ${VALHEIM_SCRIPTS_IMAGE} AS valheim_scripts
FROM ${STEAMCMD_IMAGE}

USER root
ENV ARM64_DEVICE=generic \
    DEBUGGER=/usr/local/bin/valheim-box64 \
    STEAM_PLATFORM=linux32

# The paths below are a contract with the pinned valheim_scripts image.
COPY --from=valheim_scripts /usr/local/lib/valheim/bootstrap /usr/local/lib/valheim/bootstrap
COPY --from=valheim_scripts /usr/local/lib/valheim/common /usr/local/lib/valheim/common
COPY --from=valheim_scripts /usr/local/bin/valheim-backup /usr/local/bin/valheim-backup
COPY --from=valheim_scripts /usr/local/bin/valheim-updater /usr/local/bin/valheim-updater
COPY --from=valheim_scripts /usr/lib/x86_64-linux-gnu/libogg.so.0 /usr/lib/x86_64-linux-gnu/libogg.so.0

COPY --chmod=0755 docker/patch-upstream-for-box32.sh /usr/local/sbin/patch-upstream-for-box32
COPY --chmod=0755 docker/valheim-box64.sh /usr/local/bin/valheim-box64

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tini zip libatomic1 libpulse0 libpulse-mainloop-glib0 \
        libsdl2-2.0-0 libsdl3-0 \
    && chown -R root:root /home/steam/steamcmd \
    && /usr/local/sbin/patch-upstream-for-box32 \
    && bash -n /usr/local/bin/valheim-box64 \
    && mkdir -p /opt/valheim \
    && rm -f /usr/local/sbin/patch-upstream-for-box32 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/usr/local/lib/valheim/bootstrap"]
