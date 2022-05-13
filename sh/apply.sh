#!/bin/bash
set -euo pipefail

# cleanup old secrets
install -d -m 0700 /nix/my/unpacked
find /nix/my/unpacked -type f ! -name key -delete

# unpack new secrets
age -d -i /etc/ssh/ssh_host_ed25519_key "./secrets/$(cat /etc/hostname).age" \
  | (cd /nix/my/unpacked; tar x)

# link /etc/nixos/configuration.nix
if [ ! -f /nix/my/unpacked/root.nix ]; then
  echo "file not found: /nix/my/unpacked/root.nix" >&2
  exit 1
fi
if [ -f /etc/nixos/configuration.nix ]; then
  mv /etc/nixos/configuration.nix /etc/nixos/configuration.bak
fi
ln -sf /nix/my/unpacked/root.nix /etc/nixos/configuration.nix
ln -sf /x/src/github.com/majewsky/nixos-modules /nix/my/modules
