TAIGA_VERSION = $(shell awk -F'"' '/version *=/{print$$2}' default.nix)
TARBALL_BASENAME = taiga-back-$(TAIGA_VERSION)

all: collect-dependencies early-requirements.txt

collect-dependencies: requirements.txt fetch-requirements.nix
	nix-shell fetch-requirements.nix
.PHONY: collect-dependencies

early-requirements.txt: requirements.txt Makefile
	@echo '-i https://pypi.org/simple' > $@
	@# cairocffi needs pytest-runner, but requirements.txt did not get the memo
	@echo 'pytest-runner==5.1' >> $@
	@# django-sampledatahelper needs versiontools, but requirements.txt did not get the memo
	@echo 'versiontools==1.9.1' >> $@
	@# need to install cffi before cairocffi
	@grep '^cffi==' requirements.txt >> $@

requirements.txt: $(TARBALL_BASENAME).tar.gz
	tar Oxf $(TARBALL_BASENAME).tar.gz $(TARBALL_BASENAME)/requirements.txt > $@
.SECONDARY: requirements.txt

$(TARBALL_BASENAME).tar.gz:
	wget -O $@ https://github.com/taigaio/taiga-back/archive/$(TAIGA_VERSION).tar.gz
.SECONDARY: $(TARBALL_BASENAME).tar.gz
