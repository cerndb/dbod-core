#
# Database On Demand (DBOD) core library SPEC file
#

%define version 0.74

# Trying to avoid Koji post-generation issues
%define __arch_install_post %{nil} # /usr/lib/rpm/check-buildroot
%define debug_package %{nil} # Disables building debug RPM
%define CORE_ROOT /opt/dbod/perl5

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

Requires: cerndb-sw-dbod-core-deps

# Build requirements
BuildRequires: perl-Module-Install
BuildRequires: perl-File-ShareDir

AutoReqProv: no

%description
DB On Demand core framework

%prep
%setup -n DBOD-%{version}
exit 0

%build
perl Makefile.PL INSTALL_BASE=$RPM_BUILD_ROOT/%{CORE_ROOT}/
make
exit 0

%install
mkdir -p $RPM_BUILD_ROOT/etc/profile.d
cp -r profile.d/dbod-core.sh $RPM_BUILD_ROOT/etc/profile.d/
mkdir -p $RPM_BUILD_ROOT/%{CORE_ROOT}
mkdir -p $RPM_BUILD_ROOT/var/log/dbod
make install
rm $RPM_BUILD_ROOT/%{CORE_ROOT}/lib/perl5/x86_64-linux-thread-multi/perllocal.pod
exit 0

%clean
rm -rf $RPM_BUILD_ROOT
exit 0

# Post-uninstallation
%postun
# Only remove perlbrew profile if the package is the last one to be removed
# (0 versions remain in the system as this stage (the number of versions
# passed to the %postun script).
if [ $1 -eq 0 ]; then
    rm /etc/profile.d/dbod-core.sh;
fi
exit 0;

%files
/etc/profile.d/dbod-core.sh
%config %{CORE_ROOT}/lib/perl5/auto/share/dist/DBOD
%{CORE_ROOT}/lib/perl5/DBOD/
%{CORE_ROOT}/lib/perl5/DBOD.pm
%{CORE_ROOT}/lib/perl5/x86_64-linux-thread-multi/auto/DBOD/.packlist
%{CORE_ROOT}/lib/perl5/DBOD.pm
%attr (-, dbod, dbod) /var/log/dbod
%{CORE_ROOT}/bin

%changelog
* Tue Apr 4 2017 Ignacio Coterillo <icoteril@cern.ch> 0.74.1
- Automatic port selection
- Fixes memory parameters initialization values issues
- Correct registration of PG types in AppDynamics
* Wed Sep 28 2016 Ignacio Coterillo <icoteril@cern.ch> 0.72.2
- Fixes scripts type selection 
* Wed Sep 28 2016 Ignacio Coterillo <icoteril@cern.ch> 0.72.0
- Fix Cache loading format missmatch
* Mon Sep 19 2016 Ignacio Coterillo <icoteril@cern.ch> 0.71.0
- Install to /opt/dbod/
* Tue Nov 17 2015 Ignacio Coterillo <icoteril@cern.ch> 0.67.1
- Changed release format
* Tue Jun 2 2015 Ignacio Coterillo <icoteril@cern.ch> 0.5.1
- Initial packaging
