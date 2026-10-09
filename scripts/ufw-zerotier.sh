#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: sudo $0 ztxxxxxxxxxx" >&2
  exit 2
fi

zt_interface="$1"

apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 9993/udp

# The first rule allows Valheim only through the specified ZeroTier interface.
# The second rule blocks the same ports on all other interfaces.
ufw insert 1 allow in on "$zt_interface" to any port 2456:2457 proto udp
ufw insert 2 deny in to any port 2456:2457 proto udp
ufw --force enable
ufw status verbose
