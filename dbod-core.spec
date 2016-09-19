#
# Database On Demand (DBOD) core library SPEC file
#

%define version 0.71

# Trying to avoid Koji post-generation issues
%define __arch_install_post %{nil} # /usr/lib/rpm/check-buildroot
%define debug_package %{nil} # Disables building debug RPM
%define CORE_ROOT /opt/dbod/perl5

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

AutoReqProv: no

%description
DB On Demand core framework

%prep
%setup -n DBOD-%{version}
mkdir -p $RPM_BUILD_ROOT/%{CORE_ROOT}
exit 0

%build
perl Makefile.PL INSTALL_BASE=$RPM_BUILD_ROOT/%{CORE_ROOT}/
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
%config %{CORE_ROOT}/lib/perl5/auto/share/dist/DBOD
%{CORE_ROOT}/lib/perl5/DBOD/
%{CORE_ROOT}/lib/perl5/DBOD.pm
%attr (-, dbod, dbod) /var/log/dbod
%{CORE_ROOT}/lib/perl5/x86_64-linux/perllocal.pod
%{CORE_ROOT}/lib/perl5/x86_64-linux/auto/DBOD/.packlist
%{CORE_ROOT}/bin

%changelog
* Mon Sep 19 2016 Ignacio Coterillo <icoteril@cern.ch> 0.71.0
- Install to /opt/dbod/
* Tue Nov 19 2015 Ignacio Coterillo <icoteril@cern.ch> 0.67.1
- Changed release format
* Tue Jun 2 2015 Ignacio Coterillo <icoteril@cern.ch> 0.5.1
- Initial packaging
