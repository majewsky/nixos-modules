{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "gofu-${version}";
  version = "2021.2";

  src = fetchurl {
    url = "https://github.com/majewsky/gofu/archive/v${version}.tar.gz";
    sha256 = "0610hcxl3y8gxlbv9i26rbg79wfixvav06mlcxr3qgq18vbvj1hb";
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
