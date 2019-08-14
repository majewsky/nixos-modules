let

  pkgs = import <nixpkgs> {};

in pkgs.mkShell {

  buildInputs = with pkgs; [
    gcc
    libffi
    postgresql_11
    python36Packages.pip
  ];

  shellHook = ''
    set -euo pipefail
    mkdir -p ./requirements/
    cd ./requirements/
    pip download -r ../early-requirements.txt
    pip download -r ../requirements.txt
    exit $?
  '';

}
