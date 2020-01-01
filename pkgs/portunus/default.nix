{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "portunus-${version}";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/majewsky/portunus/archive/v${version}.tar.gz";
    sha256 = "1sl02n1ix9dp785za3fknll8jghic13jf7kmf12z9mr4yn7x6zha";
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
