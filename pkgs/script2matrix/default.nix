{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "script2matrix";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "majewsky";
    repo = pname;
    rev = "v${version}";
    sha256 = "0h11kfj9yargmma097d96810j6irnsy32zd3a8i6m5n93c1444cj";
  };

  vendorHash = null;
  subpackages = [ "." ];
  ldflags = "-s -w";

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
