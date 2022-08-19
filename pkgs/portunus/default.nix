{ stdenv, lib, fetchFromGitHub, go }:

stdenv.mkDerivation rec {
  name = "portunus-${version}";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = "portunus";
    rev = "v${version}";
    sha256 = "sha256-+sq5Wja0tVkPZ0Z++K2A6my9LfLJ4twxtoEAS6LHqzE=";
  };

  buildInputs = [ go ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

  meta = with lib; {
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
