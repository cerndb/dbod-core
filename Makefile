ARCH=x86_64
VERSION=$(shell grep version Makefile.PL | cut -d\' -f2)
SPECFILE=$(shell find -maxdepth 1 -name \*.spec -exec basename {} \; )
REPOURL=git+ssh://git@gitlab.cern.ch:7999
# gitlab group
REPOPREFIX=/db

# Get all the package infos from the spec file
PKGVERSION=$(shell awk '/Version:/ { print $$2 }' ${SPECFILE})
PKGRELEASE=$(shell awk '/Release:/ { print $$2 }' ${SPECFILE} | sed -e 's/\%{?dist}//')
PKGNAME=$(shell awk '/Name:/ { print $$2 }' ${SPECFILE})
PKGID=$(PKGNAME)-$(PKGVERSION)
TARFILE=$(PKGID).tar.gz

# This is Koji required and must generate a suitable tarball
#
# If we have the tarball tracked on Git the tar pre-step can
# be removed.
#
# Executing this steps overwrites the Makefile with the one
# generated on the compile: target

gen-sources:
	perl Makefile.PL 
	make
	make dist
	git checkout Makefile

sources:
	tar xvzf DBOD-$(VERSION).tar.gz
	cp -r bin DBOD-$(VERSION)
	cp -r profile.d DBOD-$(VERSION)
	cp -r resources DBOD-$(VERSION)
	tar cvzf DBOD-$(VERSION).tar.gz DBOD-$(VERSION)

clean:
	rm -f DBOD-*.tar.gz

all: sources

srpm:   all
	rpmbuild -bs --define "_topdir ${PWD}" --define "_sourcedir $(PWD)" ${SPECFILE}

rpm:    all
	rpmbuild -ba --define "_topdir ${PWD}" --define "_sourcedir $(PWD)" ${SPECFILE}

scratch:
	koji build db7 --nowait --scratch  ${REPOURL}${REPOPREFIX}/${PKGNAME}.git#master

build:
	koji build db7 --nowait ${REPOURL}${REPOPREFIX}/${PKGNAME}.git#master

tag-qa:
	koji tag-build db7-qa $(PKGID)-$(PKGRELEASE).el7.cern

tag-stable:
	koji tag-build db7-stable $(PKGID)-$(PKGRELEASE).el7.cern