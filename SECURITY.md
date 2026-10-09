# Security policy

## Supported version

Security fixes are applied to the latest commit on the default branch. Older
checkouts, locally modified images and third-party modpacks are not maintained
by this project.

## Report a vulnerability

Use GitHub private vulnerability reporting for issues in this repository. Do
not publish exploit details, credentials, server passwords, Join Codes, world
archives or unredacted logs in a public issue.

If private reporting is unavailable, open a minimal public issue requesting a
private contact channel without including sensitive technical details.

Vulnerabilities in Valheim, Steam, PlayFab, Box64, BepInEx or an upstream image
should also be reported to the responsible upstream project.

## Deployment secrets and sensitive data

- Never commit `.env`, world saves, backups, Steam credentials or mod DLLs.
- Treat server passwords, Join Codes and player platform IDs as private.
- Review logs before sharing them; redact addresses, IDs, tokens and paths.
- Restrict SSH and direct-game ports to the networks that require them.
- Keep the host OS and Docker Engine updated.
- Review every mod as executable third-party code and retain its source and hash.
- Make an offline backup before upgrading images, changing mods or importing a world.

The included `.gitignore` and `.dockerignore` exclude the standard private
paths, but they do not protect files copied elsewhere in the repository.
