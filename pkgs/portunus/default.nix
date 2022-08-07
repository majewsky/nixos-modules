{ stdenv, lib, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "portunus-${version}";
  version = "1.1.0-beta.2";

  src = fetchurl {
    url = "https://github.com/majewsky/portunus/archive/v${version}.tar.gz";
    sha256 = "sha256-VGVGI/5dpfSs6Ai+t0YT6z3w/kq3BTKVSX8Q3Srb6Vs=";
  };

  buildInputs = [ go ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

  meta = with lib; {
    description = "Self-contained user/group management and authentication service";
    homepage = https://github.com/majewsky/portunus/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
