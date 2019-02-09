{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "shove-${version}";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/majewsky/shove/archive/v${version}.tar.gz";
    sha256 = "1mbws35k7sc3284pylvn88pa9zh1cjvv1vh6gf1dfpv67nh7w249";
  };

  buildInputs = [ go ];
  makeFlags = [ "GOCACHE=off" "GO111MODULE=off" "PREFIX=$(out)" ];

  meta = with stdenv.lib; {
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
