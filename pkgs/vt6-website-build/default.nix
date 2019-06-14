{ stdenv, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "vt6-website-build-${version}";
  version = "4";

  src = fetchurl {
    url = "https://github.com/vt6/website/archive/v${version}.tar.gz";
    sha256 = "1h5qpsxfymq26fw8sc6f13qbm87wrhs17n679wn8vdm4jcfi83xh";
  };

  buildInputs = [ go ];
  makeFlags = [ "GOCACHE=off" "GO111MODULE=off" "PREFIX=$(out)" ];

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
