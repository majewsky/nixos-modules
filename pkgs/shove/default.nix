{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "shove";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = pname;
    rev = "v${version}";
    sha256 = "1q4ix15n04f6qd8r2i1ylzgidiaq6xgylz1a8x7pb395d53vkn8b";
  };

  vendorSha256 = null;
  subpackages = [ "." ];
  ldflags = "-s -w";

  meta = with lib; {
    description = "GitHub webhook receiver";
    homepage = https://github.com/majewsky/shove/;
    license = licenses.asl20;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
