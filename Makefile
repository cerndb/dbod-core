ARCH=x86_64
RPMBUILD=rpmbuild
RPMFLAGS=-ba
SRCPATH=${HOME}/rpmbuild
SPECPATH=$(SRCPATH)/SPECS
SOURCESPATH=$(SRCPATH)/SOURCES
RPMPATH=$(SRCPATH)/RPMS/$(ARCH)

compile:
	cd src && perl Makefile.PL && make

tar: compile
	cd src && make manifest && make dist

# Installation as PERL Module
install: compile
	cd src && make install

# This is Koji required and must generate a suitable tarball

# The tar file needs to be in the repo as the Mock environment doesn't have
# perl-Module-Install available to build it.
sources:
	cp src/DBOD-*.tar.gz .

# This task will generate an RPM locally
manual-rpm:  
	cp src/DBOD-*.tar.gz $(SOURCESPATH)
	$(RPMBUILD) $(RPMFLAGS) dbod-core.spec

clean:
	rm -f DBOD-*.tar.gz
	cd src && make clean
