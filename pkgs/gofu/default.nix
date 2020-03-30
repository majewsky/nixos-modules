{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "gofu-${version}";
  version = "2020.1";

  src = fetchurl {
    url = "https://github.com/majewsky/gofu/archive/v${version}.tar.gz";
    sha256 = "1wgy04fnc74n7b2j2v3syci8aqdkizp34wp38l2lwzhn3p8pglx9";
  };

  buildInputs = [ go ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

  meta = with stdenv.lib; {
    description = "My personal busybox built in Go";
    homepage = https://github.com/majewsky/gofu/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
