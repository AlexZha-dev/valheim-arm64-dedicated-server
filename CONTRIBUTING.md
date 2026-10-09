# Contributing

Contributions should preserve a reproducible, vanilla-by-default Valheim server
for Linux ARM64 hosts. Raspberry Pi 4 with Raspberry Pi OS Lite 64-bit is the
reference test platform; other device results are welcome when the exact host,
kernel, OS, page size and `ARM64_DEVICE` value are included.

## Before changing code

- Do not commit worlds, backups, `.env`, credentials, platform IDs or mod DLLs.
- Keep Crossplay as the default connection mode and BepInEx opt-in.
- Keep persistent paths backward compatible unless a documented migration is included.
- Pin upstream images by digest and update only one upstream input at a time.
- Put build-time adaptation in `docker/` and operational behavior in `scripts/`.
- Use portable Bash where practical and fail safely before destructive actions.

## Documentation style

- Write concise English and define an acronym on first use.
- Distinguish tested behavior from expected or upstream-supported behavior.
- Keep commands copyable and state whether they stop, recreate or delete anything.
- Link to a focused guide instead of duplicating long instructions.
- Do not add badges that imply tests, releases or support which do not exist.

## Local validation

```bash
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.test.example \
  -f compose.yaml -f compose.test.yaml config --quiet
bash -n docker/*.sh scripts/*.sh
git diff --check
```

Also verify that every relative Markdown link resolves and that generated
Compose output uses `linux/arm64`, `ARM64_DEVICE=generic` and the expected bind
mounts.

Changes to the Dockerfile, Box64 settings or upstream digests require an ARM64
build and an end-to-end server start. Record the device profile and whether an
existing world, new world, Crossplay registration and graceful stop succeeded.

## Pull requests

Keep each pull request focused. Describe the failure or operational need, the
compatibility impact, validation performed and any migration required for an
existing `/srv/valheim` deployment.
