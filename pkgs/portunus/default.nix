{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "portunus-${version}";
  version = "1.0.0-beta.3";

  src = fetchurl {
    url = "https://github.com/majewsky/portunus/archive/v${version}.tar.gz";
    sha256 = "04rbjy1v5600xlznw721ykway24s0cg0mc3l5qrf4sz0l7yap8nn";
  };

  buildInputs = [ go ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

  meta = with stdenv.lib; {
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
