{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "script2matrix";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-akb4s6drNGgxO7DDp3h15/y4WpxS9dkcv/a5ZsLL2AE=";
  };

  vendorHash = null;

  meta = with lib; {
    description = "Runs a script and sends its stdout to a Matrix chat.";
    homepage = https://github.com/majewsky/script2matrix/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = with platforms; linux ++ darwin;
  };

}
