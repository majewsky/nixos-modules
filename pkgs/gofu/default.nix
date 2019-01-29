{ stdenv, fetchFromGitHub, go, ... }:

stdenv.mkDerivation rec {
  name = "gofu";

  src = fetchFromGitHub {
    repo = "gofu";
    owner = "majewsky";
    rev = "ef84ca3e82f422118c69a0c562433c185e1dcb9b";
    sha256 = "17ijpgin99m8icn54fq8dd8vkfmz1fqv4xl7wxnv0rqdsi2xyxgd";
  };

  buildInputs = [ go ];
  makeFlags = [ "GOCACHE=off" "PREFIX=$(out)" ];

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
