{ stdenv, coreutils }:

stdenv.mkDerivation rec {
  name = "bootstrap-devenv";
  src = ./bootstrap-devenv.sh;
  unpackCmd = "${coreutils}/bin/mkdir src && cp \${curSrc} src/bootstrap-devenv.sh";

  builder = ./builder.sh;
  inherit coreutils;

  meta = with stdenv.lib; {
    description = "Bootstrap script for https://github.com/majewsky/devenv/";
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux;
  };
}
