{ stdenv, coreutils }:

stdenv.mkDerivation rec {
  name = "clone-archlinux-mirror";
  src = ./clone-archlinux-mirror.sh;

  builder = ../generic/builder-single-shellscript.sh;
  inherit coreutils;

  meta = with stdenv.lib; {
    description = "Script for cloning an Arch Linux mirror";
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux;
  };
}

