deps@{
  stdenv, fetchurl, python36Packages,
  # library dependencies
  freetype,
  lcms2,
  libffi,
  libjpeg,
  libtiff,
  libwebp,
  libxml2,
  libxslt,
  openssl_1_1,
  pkgconfig,
  postgresql_11,
  tcl,
  zlib,
  # runtime dependencies for taiga-manage (runs during install phase)
  gettext,
}: let

  libraryDeps = builtins.removeAttrs deps ["stdenv" "fetchurl" "python36Packages"];

in stdenv.mkDerivation rec {
  name = "taiga-back-${version}";
  version = "4.2.11";

  src = fetchurl {
    url = "https://github.com/taigaio/taiga-back/archive/${version}.tar.gz";
    sha256 = "12nh186cqycrdhd5wqpjyhz6kjlhm0ap08mah89gmd346979016w";
  };

  earlyRequirements = ./early-requirements.txt;

  requirements = builtins.path {
    path = ./requirements;
    name = "taiga-back-requirements";
  };

  nativeBuildInputs = [
    libxml2.dev
    libxslt.dev
  ];

  buildInputs = (builtins.attrValues libraryDeps) ++ [
    python36Packages.pip
    python36Packages.virtualenv
  ];

  buildPhase = ''
  '';

  installPhase = let
    pipInstall = "pip install --no-cache-dir --no-index --find-links file:$requirements/ --retries 0 --timeout 0.1";
  in ''
    virtualenv $out/venv
    source $out/venv/bin/activate
    (
      set -x
      ${pipInstall} -r $earlyRequirements
      ${pipInstall} -r requirements.txt
    )
    cp -R . $out/taiga
    ln -sfT /etc/taiga/settings/local.py $out/taiga/settings/local.py

    mkdir $out/bin
    (
      echo '#!/bin/sh'
      echo "cd \"\$(dirname \"\$0\")/../taiga\""
      echo "\"$out/venv/bin/python\" manage.py \"\$@\""
      echo 'exit $?'
    ) > $out/bin/taiga-manage
    chmod +x $out/bin/taiga-manage

    $out/venv/bin/python -m compileall $out/taiga
    $out/bin/taiga-manage compilemessages
    $out/bin/taiga-manage collectstatic --noinput
  '';

  meta = with stdenv.lib; {
    description = "Backend part of Taiga project management software";
    homepage = https://taiga.io/;
    license = licenses.agpl3;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };
}
