#!/bin/sh
set -euo pipefail
source $stdenv/setup
install -D -m 0755 $src $out/bin/$name
