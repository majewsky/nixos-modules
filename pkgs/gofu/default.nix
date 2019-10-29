{ stdenv, fetchFromGitHub, go }:

stdenv.mkDerivation rec {
  name = "gofu";

  src = fetchFromGitHub {
    repo = "gofu";
    owner = "majewsky";
    rev = "1ff86053ddef8de3247909434e0bd7000c060f2a";
    sha256 = "0nxh6n4dw0gxq0z9f6wfdrn8ccn7ljvw1rf6vkfwf1bv0w3wvkw7";
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
