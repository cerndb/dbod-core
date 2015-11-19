#
# Database On Demand (DBOD) core library SPEC file
#

%define version 0.67

# Trying to avoid Koji post-generation issues
%define __arch_install_post %{nil} # /usr/lib/rpm/check-buildroot
%define debug_package %{nil} # Disables building debug RPM

Summary: DB On Demand Core library
Name: cerndb-sw-dbod-core
Version: %{version}
Release: 1%{?dist}
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
Requires: perl-File-ShareDir
Requires: perl-Log-Log4perl
Requires: perl-YAML-Syck 
Requires: perl-DBD-Oracle
Requires: perl-Config-General


%description
DB On Demand core library

%prep
%setup -n DBOD-%{version}
exit 0

%build
perl Makefile.PL PREFIX=$RPM_BUILD_ROOT/usr/local
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
%config /usr/local/share/perl5/auto/share/dist/DBOD/configpath.conf
%config /usr/local/share/perl5/auto/share/dist/DBOD/dbod-core.conf-template
/usr/local/share/perl5/auto/share/dist/DBOD/test.json
/usr/local/share/perl5/DBOD/
%attr (-, dbod, dbod) /var/log/dbod
/usr/local/lib64/perl5/auto/DBOD/.packlist
/usr/local/lib64/perl5/perllocal.pod

%changelog
* Tue Nov 19 2015 Ignacio Coterillo <icoteril@cern.ch> 0.67.1
- Changed release format
* Tue Jun 2 2015 Ignacio Coterillo <icoteril@cern.ch> 0.5.1
- Initial packaging
