PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/ralph-codex

.PHONY: install uninstall

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 0755 bin/ralph $(DESTDIR)$(BINDIR)/ralph
	install -d $(DESTDIR)$(DATADIR)
	install -m 0644 README.md $(DESTDIR)$(DATADIR)/README.md

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/ralph
	rm -rf $(DESTDIR)$(DATADIR)
