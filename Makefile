all:
	@printf 'Available targets:\n\n\tmake unpack\n\n'

unpack:
	bash ./unpack-secrets.sh
