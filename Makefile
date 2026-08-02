#! /usr/bin/make -f

script_dir=script
test_dir=t
SCRIPTS=iconvgrep.pl
TESTS=iconvgrep.t

HOME_TARGETS=README.md
MANUALS=$(SCRIPTS:%=%.1)
TARGETS=$(HOME_TARGETS) $(script_dir)/$(MANUALS)

PREFIX=$(HOME)/.local
bindir=$(PREFIX)/bin
mandir=$(PREFIX)/man
man1dir=$(mandir)/man1

.PHONY: all check clean install uninstall
all: $(TARGETS)
README.md: $(script_dir)/$(SCRIPTS)
	pod2markdown $< > $@
check:
	cd $(test_dir) && prove -l $(TESTS)
	perlcritic $(script_dir)/$(SCRIPTS)
	podchecker $(script_dir)/$(SCRIPTS)
	perlcritic $(test_dir)/$(TESTS)
clean:
	rm -f $(TARGETS) $(script_dir)/$(SCRIPTS:%=%.tdy) \
		$(test_dir)/$(TESTS:%=%.tdy)
install:
	install -m 755 -d $(DESTDIR)$(bindir) $(DESTDIR)$(man1dir)
	install -m 644 $(script_dir)/$(MANUALS) $(DESTDIR)$(man1dir)
	install -m 755 $(script_dir)/$(SCRIPTS) $(DESTDIR)$(bindir)
uninstall:
	cd $(DESTDIR)$(bindir) && rm -f $(SCRIPTS)
	cd $(DESTDIR)$(man1dir) && rm -f $(MANUALS)
%.1: %
	pod2man $< > $@
%.tdy: %
	perltidy $^
