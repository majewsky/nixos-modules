# nixos-modules

My NixOS modules. Does not use NixOps at the moment, but probably should.

As a general pattern, everything in the top-level directory gets imported by `default.nix`.
The modules in `platforms/` only get imported on matching machines.

## Bootstrap

Install NixOS according to its manual, using `bootstrap/configuration.nix`.

```
sudo install -d -m 0700 -o stefan -g users /x
git clone https://github.com/majewsky/nixos-modules /x/src/github.com/majewsky/nixos-modules
```

Get the machine key from `gpg --decrypt < keys.sh.gpg` in the secrets repo.

```
cd /x/src/github.com/majewsky/nixos-modules
make apply # asks for the machine key
sudo nixos-rebuild switch
```
