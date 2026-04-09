# This module configures nginx for a domain name that hosts just Go modules (as a pure vanity domain).
# The actual repositories are hosted in CGit on a different domain.

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.my.services.go-vanity;

  repoDocuments = lib.genAttrs cfg.repos (repoName:
    let
      importPath = "${cfg.domainName}/${repoName}";
      repoURL = "https://${cfg.cgitDomainName}/go-${repoName}";
      directoryURLTemplate = "https://${cfg.cgitDomainName}/go-${repoName}/tree{/dir}";
      fileURLTemplate = "https://${cfg.cgitDomainName}/go-${repoName}/tree{/dir}/{file}#n{line}";
    in ''
      <!DOCTYPE html>
      <meta name="go-import" content="${importPath} git ${repoURL}">
      <meta name="go-source" content="${importPath} ${repoURL} ${directoryURLTemplate} ${fileURLTemplate}">
      <meta http-equiv="refresh" content="0; url=https://pkg.go.dev/${importPath}">
      <p>Redirecting to <a href="https://pkg.go.dev/${importPath}">https://pkg.go.dev/${importPath}</a>...</p>
    ''
  );

  allDocuments = lib.mergeAttrs repoDocuments {
    index = ''
      <!DOCTYPE html>
      <h1>All modules</h1>
      <ul>
      ${lib.concatMapStringsSep "\n" (repoName:
        "<li><a href=\"https://${cfg.domainName}/${repoName}\">${cfg.domainName}/${repoName}</a></li>"
      ) cfg.repos}
      </ul>
    '';
  };

  docroot = pkgs.runCommandLocal "go-get-docroot" {} ''
    mkdir -p $out
    ${lib.concatMapAttrsStringSep "\n" (basename: content: "cat > $out/${basename}.html <<-'EOF'\n${lib.trim content}\nEOF") allDocuments}
  '';

in {

  options.my.services.go-vanity = {
    domainName = mkOption {
      default = null;
      description = "domain name for Go module vanity domain (must be given to enable the service)";
      type = types.nullOr types.str;
    };
    cgitDomainName = mkOption {
      default = null;
      description = "domain name of CGit hosting the respective code repositories";
      type = types.nullOr types.str;
    };
    repos = mkOption {
      default = [];
      description = "list of module names";
      type = types.listOf types.str;
    };
  };

  config = mkIf (cfg.domainName != null) {
    services.nginx.virtualHosts.${cfg.domainName} = {
      forceSSL = true;
      enableACME = true;
      locations."/".root = "${docroot}";
      locations."/oblast/".return = "301 /oblast.html";
      locations."= /oblast".return = "301 /oblast.html";
    };
  };

}
