{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "vt6-website-build-${version}";
  version = "5";

  src = fetchurl {
    url = "https://github.com/vt6/website/archive/v${version}.tar.gz";
    sha256 = "1sxy4nqy89s46bbr5ikp759844z1ihsr6hzlj70lzp9d2j3idywk";
  };

  buildInputs = [ go ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

  meta = with stdenv.lib; {
    description = "Renderer for vt6.io";
    homepage = https://github.com/vt6/website/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = platforms.linux;
  };

}
