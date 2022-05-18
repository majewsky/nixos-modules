{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "pwget";
  version = "1.2.1";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = pname;
    rev = "v${version}";
    sha256 = "L0E6IYtlIa0HyFJYQlLlIiuS4ZethKAglzLiarZQgys=";
  };

  vendorSha256 = null;
  subpackages = [ "." ];
  ldflags = "-s -w";

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
