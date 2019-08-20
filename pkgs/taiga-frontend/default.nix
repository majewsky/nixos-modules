{ stdenv, fetchurl }: let

in stdenv.mkDerivation rec {
  name = "taiga-front-${version}";
  version = "4.2.13";

  src = fetchurl {
    url = "https://github.com/taigaio/taiga-front-dist/archive/${version}-stable.tar.gz";
    sha256 = "1qih5imc5z837x2g0vzpyzvxbx04n6nwnqwfkxa22xfh0a95iz9b";
  };

  installPhase = "mkdir $out/ && cp -R * $out/";

  meta = with stdenv.lib; {
    description = "Frontend part of Taiga project management software";
    homepage = https://taiga.io/;
    license = licenses.agpl3;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };
}
