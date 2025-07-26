{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "prometheus-minimum-viable-sd";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-g7l5fsBotffNqOpqRpNdE2p7Nyn2m8wuFHGSrIfs1tk=";
  };

  vendorHash = null;

  meta = with lib; {
    description = "Minimum Viable service discovery for Prometheus";
    homepage = https://github.com/majewsky/prometheus-minimum-viable-sd/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
