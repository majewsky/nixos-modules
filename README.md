# nixos-modules

My NixOS modules. Does not use NixOps at the moment, but probably should.

## Bootstrap

Install NixOS according to its manual, using `bootstrap/configuration.nix`.

```
sudo git clone https://github.com/majewsky/nixos-modules /nix/my
```

Get the machine key from `gpg --decrypt < keys.sh.gpg` in the secrets repo and write it into `/nix/my/secrets/key`.

```
cd /nix/my
make unpack
cd /etc/nixos
mv configuration.nix configuration.bak
ln -s /nix/my/secrets/root.nix /etc/nixos/configuration.nix
nixos-rebuild switch
```
