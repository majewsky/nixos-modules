{ stdenv, fetchurl, go, go-bindata, sassc }:

stdenv.mkDerivation rec {
  name = "alltag-${version}";
  version = "1.0.0-beta.3";

  src = fetchurl {
    url = "https://github.com/majewsky/alltag/archive/v${version}.tar.gz";
    sha256 = "1d8csdi03wgmrbj18fnhnvwk1jlzv39i7vphb613hg6mndq6kb79";
  };

  buildInputs = [ go go-bindata sassc ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

  meta = with stdenv.lib; {
    description = "The ADHD-friendly issue tracker";
    homepage = https://github.com/majewsky/alltag/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
