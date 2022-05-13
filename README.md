# nixos-modules

My NixOS modules.

As a general pattern, everything in the top-level directory gets imported by `default.nix`.
The modules in `platforms/` only get imported on matching machines.

## Bootstrap

Install NixOS according to its manual, using `bootstrap/configuration.nix`.

```
sudo install -d -m 0700 -o stefan -g users /x
git clone https://github.com/majewsky/nixos-modules /x/src/github.com/majewsky/nixos-modules
```

Copy the machine's public key from `/etc/ssh/ssh_host_ed25519_key.pub` into the secrets repo. Re-render and commit the secret payloads.

```
cd /x/src/github.com/majewsky/nixos-modules
git pull # to get the re-rendered secrets
make switch
```
