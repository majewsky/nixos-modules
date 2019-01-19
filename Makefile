all:
	@printf 'Available targets:\n\n'
	@grep -E '^[a-z]' Makefile | sed '/^all:/d; s/^/\tmake /; s/:.*$$//'
	@echo

pull:
	git pull
	git reset --hard origin/master
	@make unpack

unpack:
	bash ./unpack-secrets.sh
