# Copyright (c) 2019 Anton Semjonov
# Licensed under the MIT License

# ---------- install ----------

NAME    := autosnap
VERSION := $(shell sh version.sh describe)

# installation directories
DESTDIR        :=
PREFIX         := /usr
BINARY_DIR     := $(DESTDIR)$(PREFIX)/bin
SYSTEMD_DIR    := $(DESTDIR)$(PREFIX)/lib/systemd/system
MANUAL_DIR     := $(DESTDIR)$(PREFIX)/share/man
LICENSE_DIR    := $(DESTDIR)$(PREFIX)/share/licenses/$(NAME)

# install binary and manuals
.PHONY: install
install : \
	$(BINARY_DIR)/$(NAME) \
	$(MANUAL_DIR)/man8/$(NAME).8 \
	$(SYSTEMD_DIR)/$(NAME).service \
	$(SYSTEMD_DIR)/$(NAME).timer \
	$(SYSTEMD_DIR)/$(NAME)@.service \
	$(SYSTEMD_DIR)/$(NAME)@.timer \
	$(LICENSE_DIR)/LICENSE

$(BINARY_DIR)/$(NAME) : $(NAME).sh
	install -m 755 -D $< $@

$(NAME).8 : README.md
	marked-man --version $(VERSION) --manual 'ZFS Utilities' $< > $@

$(MANUAL_DIR)/man8/$(NAME).8 : $(NAME).8
	install -m 644 -D $< $@

$(SYSTEMD_DIR)/$(NAME)% : etc/$(NAME)%
	install -m 644 -D $< $@
	sed -i 's|/usr/bin|$(PREFIX)/bin|' $@

$(LICENSE_DIR)/LICENSE : LICENSE
	install -m 644 -D $< $@

# ---------- packaging ----------

# package metadata
PKGNAME     := $(NAME)
PKGVERSION  := $(shell echo $(VERSION) | sed s/-/./ )
PKGAUTHOR   := 'ansemjo <anton@semjonov.de>'
PKGLICENSE  := MIT
PKGURL      := https://github.com/ansemjo/$(PKGNAME)
PKGFORMATS  := rpm deb

# how to execute fpm
FPM := docker run --rm --net none -v $$PWD:/src -w /src ghcr.io/ansemjo/fpm

# build a package
.PHONY: package-%
package-% :
	make --no-print-directory install DESTDIR=package
	mkdir -p release
	$(FPM) -s dir -t $* -f --chdir package \
		--name $(PKGNAME) \
		--version $(PKGVERSION) \
		--maintainer $(PKGAUTHOR) \
		--license $(PKGLICENSE) \
		--url $(PKGURL) \
		--package release/$(PKGNAME)-$(PKGVERSION).$*

# build all package formats with fpm
.PHONY: packages
packages : $(addprefix package-,$(PKGFORMATS))

# ---------- misc ----------

# clean untracked files and directories
.PHONY: clean
clean :
	git clean -fdx
