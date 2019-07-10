{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "portunus-${version}";
  version = "1.0.0-beta.4";

  src = fetchurl {
    url = "https://github.com/majewsky/portunus/archive/v${version}.tar.gz";
    sha256 = "1b4rgls7s84409ai3wc0kj547fs18raf78wf5rygqf12mjrmkqym";
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
