{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "gofu";
  version = "2026.2";

  src = fetchFromGitHub { # NOTE: not fetching from git.xyrillian.de here to avoid circular dependency
    owner = "majewsky";
    repo = "gofu";
    rev = "v${version}";
    sha256 = "sha256-4ssDfWsV1/3iQ7beR+kyqsN+rMe6cxda4OB6f8KkWVY=";
  };

  vendorHash = null;

  subPackages = [ "." ];

  postInstall = ''
    ln -s $out/bin/gofu $out/bin/mdedit
    ln -s $out/bin/gofu $out/bin/rtree
    ln -s $out/bin/gofu $out/bin/prettyprompt
  '';

  meta = {
    description = "Multibinary containing several utilities";
    homepage = "https://github.com/majewsky/gofu";
    license = lib.licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
  };
}
