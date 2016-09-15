#
# Database On Demand (DBOD) core library SPEC file
#

%define version 0.71

# Trying to avoid Koji post-generation issues
%define __arch_install_post %{nil} # /usr/lib/rpm/check-buildroot
%define debug_package %{nil} # Disables building debug RPM
%define SCL_ROOT /opt/rh/rh-perl520/root

Summary: DB On Demand Core library
Name: cerndb-sw-dbod-core
Version: %{version}
Release: 0%{?dist}
License: GPL
Group: Applications
ExclusiveArch: x86_64
Source: DBOD-%{version}.tar.gz
URL: https://github.com/cerndb/DBOD-core
Distribution: DBOD
Vendor: CERN
Packager: Ignacio Coterillo Coz <icoteril@cern.ch>

# Build requirements
BuildRequires: perl-Module-Install
BuildRequires: perl-File-ShareDir

# Requirements
#Requires: perl-File-ShareDir
#Requires: perl-Log-Log4perl
#Requires: perl-YAML-Syck 
#Requires: perl-DBD-Oracle
#Requires: perl-Config-General
AutoReqProv: no

%description
DB On Demand core library

%prep
%setup -n DBOD-%{version}
unset PERL5LIB;
unset PERL_LOCAL_LIB_ROOT;
export PERL_MB_OPT="--install_base \"${RPM_BUILD_ROOT}/opt/dbod/perl5\""
export PERL_MM_OPT="INSTALL_BASE=${RPM_BUILD_ROOT}/opt/dbod/perl5"
export |grep PERL
bin/cpanm  --from http://dbod-gw.cern.ch/pinto --installdeps .
mkdir -p $RPM_BUILD_ROOT/%{SCL_ROOT}
exit 0

%build
perl Makefile.PL INSTALL_BASE=$RPM_BUILD_ROOT/%{SCL_ROOT}/usr/local
make
exit 0

%install
make install
mkdir -p $RPM_BUILD_ROOT/var/log/dbod
exit 0

%clean
rm -rf $RPM_BUILD_ROOT
exit 0

%files
%config %{SCL_ROOT}/usr/local/lib/perl5/auto/share/dist/DBOD
%{SCL_ROOT}/usr/local/lib/perl5/DBOD/
%{SCL_ROOT}/usr/local/lib/perl5/DBOD.pm
%attr (-, dbod, dbod) /var/log/dbod
%{SCL_ROOT}/usr/local/lib/perl5/x86_64-linux/perllocal.pod
%{SCL_ROOT}/usr/local/lib/perl5/x86_64-linux/auto/DBOD/.packlist
%{SCL_ROOT}/usr/local/bin

%changelog
* Tue Nov 19 2016 Ignacio Coterillo <icoteril@cern.ch> 0.71.0
- Install as part of Red Hat SCL (rh-perl520)
* Tue Nov 19 2015 Ignacio Coterillo <icoteril@cern.ch> 0.67.1
- Changed release format
* Tue Jun 2 2015 Ignacio Coterillo <icoteril@cern.ch> 0.5.1
- Initial packaging
