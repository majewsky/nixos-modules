{ stdenv, lib, fetchurl, go }:

stdenv.mkDerivation rec {
  name = "prometheus-minimum-viable-sd-${version}";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/majewsky/prometheus-minimum-viable-sd/archive/v${version}.tar.gz";
    sha256 = "0h5scm9315826kbj1bpzwa26sh67rb2v9dm1kw9fli2qiynpz410";
  };

  buildInputs = [ go ];
  makeFlags = [ "PREFIX=$(out)" ];
  preBuild = ''
    makeFlagsArray+=(GOCACHE="$PWD/gocache" GO_BUILDFLAGS="-mod vendor")
  '';

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
