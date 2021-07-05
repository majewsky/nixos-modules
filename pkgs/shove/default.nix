{ stdenv, lib, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "shove-${version}";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/majewsky/shove/archive/v${version}.tar.gz";
    sha256 = "0nslc2rhan8sgm30zk9k820887svsafkkn4zc3dhjpz2506h6006";
  };

  buildInputs = [ go ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

  meta = with lib; {
    description = "GitHub webhook receiver";
    homepage = https://github.com/majewsky/shove/;
    license = licenses.asl20;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
