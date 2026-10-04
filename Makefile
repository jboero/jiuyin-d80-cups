PREFIX     ?= /usr
FILTERDIR  ?= $(PREFIX)/lib/cups/filter
MODELDIR   ?= $(PREFIX)/share/cups/model
BINDIR     ?= $(PREFIX)/local/bin

.PHONY: all install uninstall selinux selinux-remove clean

all:
	@echo "Targets: install, uninstall, selinux (Fedora/RHEL), selinux-remove"

install:
	install -D -m 755 rastertod80 $(DESTDIR)$(FILTERDIR)/rastertod80
	install -D -m 644 jiuyin-d80.ppd $(DESTDIR)$(MODELDIR)/jiuyin-d80.ppd
	install -D -m 755 d80-status $(DESTDIR)$(BINDIR)/d80-status
	-[ -z "$(DESTDIR)" ] && command -v restorecon >/dev/null && restorecon $(DESTDIR)$(FILTERDIR)/rastertod80 $(DESTDIR)$(MODELDIR)/jiuyin-d80.ppd

uninstall:
	rm -f $(DESTDIR)$(FILTERDIR)/rastertod80 $(DESTDIR)$(MODELDIR)/jiuyin-d80.ppd $(DESTDIR)$(BINDIR)/d80-status

cups_bluetooth.pp: cups_bluetooth.te
	checkmodule -M -m -o cups_bluetooth.mod $<
	semodule_package -o $@ -m cups_bluetooth.mod

selinux: cups_bluetooth.pp
	semodule -i cups_bluetooth.pp

selinux-remove:
	semodule -r cups_bluetooth

clean:
	rm -f cups_bluetooth.mod cups_bluetooth.pp
