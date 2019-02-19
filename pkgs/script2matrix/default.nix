{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "script2matrix-${version}";
  version = "0.1.0";

  src = fetchurl {
    url = "https://github.com/majewsky/script2matrix/archive/v${version}.tar.gz";
    sha256 = "1kjhnl1knmyx6ssi6pba0y5vh84jg59wgv11j6cip58pbrccrjav";
  };

  buildInputs = [ go ];
  makeFlags = [ "GOCACHE=off" "GO111MODULE=off" "PREFIX=$(out)" ];

  meta = with stdenv.lib; {
    description = "Runs a script and sends its stdout to a Matrix chat.";
    homepage = https://github.com/majewsky/script2matrix/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
