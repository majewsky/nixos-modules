{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "prometheus-minimum-viable-sd";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = pname;
    rev = "v${version}";
    sha256 = "1j4d7rn0jff4bdwpvb6mszrjb7i123h4kbqhjylr159dpmzqi6h2";
  };

  vendorSha256 = null;
  subpackages = [ "." ];
  ldflags = "-s -w";

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
