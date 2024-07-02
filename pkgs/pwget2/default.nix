{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "pwget2";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = "pwget";
    rev = "v${version}";
    sha256 = "twsc48lHDzvcGABTEcVz5aO5YHKckutshytz8t9/dPM=";
  };

  vendorHash = null;

  postInstall = ''
    mv $out/bin/pwget $out/bin/pwget2
  '';

  meta = with lib; {
    description = "Stateless password generator with support for password revocation";
    homepage = https://github.com/majewsky/pwget/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
