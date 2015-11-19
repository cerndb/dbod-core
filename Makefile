ARCH=x86_64
RPMBUILD=rpmbuild
RPMFLAGS=-ba
SRCPATH=${HOME}/rpmbuild
SPECPATH=$(SRCPATH)/SPECS
SOURCESPATH=$(SRCPATH)/SOURCES
RPMPATH=$(SRCPATH)/RPMS/$(ARCH)

pre:	
	yum install perl-Module-Install perl-File-ShareDir

compile: pre
	perl Makefile.PL && make

tar: compile
	make dist

# Installation as PERL Module
install: compile
	make install

# This is Koji required and must generate a suitable tarball
#
# If we have the tarball tracked on Git the tar pre-step can
# be removed.
#
# Executing this steps overwrites the Makefile with the one
# generated on the compile: target
#
sources: tar

# This task will generate an RPM locally
manual-rpm:  
	cp DBOD-*.tar.gz $(SOURCESPATH)
	$(RPMBUILD) $(RPMFLAGS) dbod-core.spec

clean:
	rm -f DBOD-*.tar.gz
