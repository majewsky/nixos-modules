#!/bin/bash
set -euo pipefail

# TODO make this work before nix-install (gpg might be missing, /etc/hostname is not set)

# prepare target directory
install -d -m 0700 /nix/my/unpacked
if [ -z "$(cat /nix/my/unpacked/key)" ]; then
  echo -n "Enter machine key: "
  read -s SECRET_KEY
  echo "${SECRET_KEY}" > /nix/my/unpacked/key
  unset SECRET_KEY
fi

# cleanup old secrets
find /nix/my/unpacked -type f ! -name key -delete

# unpack new secrets
gpg --pinentry-mode loopback --quiet --decrypt --passphrase-fd 3 -o - \
  "./secrets/$(echo -n "$(cat /etc/hostname)" | sha256sum | cut -d' ' -f1).gpg" \
  3< /nix/my/unpacked/key | (cd /nix/my/unpacked; tar x)

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
