#!/bin/bash
set -euo pipefail

if [ -z "$(cat ./secrets/key)" ]; then
  echo "Cannot unpack secrets because ./secrets/key is empty." >&2
  exit 1
fi

# cleanup old secrets
find secrets -type f ! -name \*.gpg ! -name key -delete

# unpack new secrets
gpg --pinentry-mode loopback --quiet --decrypt --passphrase-fd 3 -o - \
  "./secrets/$(echo -n "$(cat /etc/hostname)" | sha256sum | cut -d' ' -f1).gpg" \
  3< ./secrets/key | (cd secrets; tar x)
