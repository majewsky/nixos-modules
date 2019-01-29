all:
	@printf 'Available targets:\n\n'
	@grep -E '^[a-z]' Makefile | sed '/^all:/d; s/^/\tmake /; s/:.*$$//'
	@echo

pull:
	git pull
	git reset --hard origin/master
	@make apply

apply:
	sudo bash ./sh/apply.sh

build: apply
	sudo nixos-rebuild build
switch: apply
	sudo nixos-rebuild switch --upgrade
