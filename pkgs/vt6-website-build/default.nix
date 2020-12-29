{ stdenv, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "vt6-website-build";
  version = "6";

  src = fetchFromGitHub {
    owner = "vt6";
    repo = "website";
    rev = "v${version}";
    sha256 = "0azflismcv9lpgb7xpm8cqyg5jqb33m8g627c54kjx4gj39plwm9";
  };

  vendorSha256 = null;
  doCheck = false;
  subPackages = [ "." ];

  meta = with stdenv.lib; {
    description = "Renderer for vt6.io";
    homepage = https://github.com/vt6/website/;
    license = licenses.gpl3Plus;
    maintainers = [{
      email = "majewsky@gmx.net";
      github = "majewsky";
      name = "Stefan Majewsky";
    }];
    platforms = platforms.linux;
  };

}
