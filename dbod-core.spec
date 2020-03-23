#
# Database On Demand (DBOD) core library SPEC file
#

%define version 0.78

# Trying to avoid Koji post-generation issues
%define __arch_install_post %{nil} # /usr/lib/rpm/check-buildroot
%define debug_package %{nil} # Disables building debug RPM
%define CORE_ROOT /opt/dbod/perl5

Summary: DB On Demand Core library
Name: cerndb-sw-dbod-core
Version: %{version}
Release: 17%{?dist}
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

Requires: perl-Log-Log4perl
Requires: perl-Log-Log4perl
Requires: perl-Log-Dispatch-FileRotate
Requires: perl-YAML-Syck
Requires: perl-File-ShareDir
Requires: perl-Moose
Requires: perl-MooseX-Getopt
Requires: perl-Config-General
Requires: perl-DBD-MySQL
Requires: perl-DBD-Pg
Requires: perl-REST-Client
Requires: perl-Template-Toolkit
Requires: perl-IPC-Run
Requires: perl-Net-OpenSSH
Requires: perl-LDAP
Requires: perl-JSON
Requires: perl-Try-Tiny
Requires: perl-Readonly
Requires: perl-SOAP-Lite
Requires: perl-autodie
Requires: perl-Pod-Parser
Requires: perl-Module-Loaded
Requires: perl-autobox
Requires: perl-LWP-Protocol-https

Requires: cerndb-perl-netapp
Requires: cerndb-infra-storage

Obsoletes: cerndb-sw-dbod-core-deps

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
mkdir -p $RPM_BUILD_ROOT/%{CORE_ROOT}
tar xvzf resources/perl5.tar.gz -C $RPM_BUILD_ROOT/opt/dbod > /dev/null 2>&1
mkdir -p $RPM_BUILD_ROOT/etc/profile.d
cp -r profile.d/dbod-core.sh $RPM_BUILD_ROOT/etc/profile.d/
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
%{CORE_ROOT}
%config %{CORE_ROOT}/lib/perl5/auto/share/dist/DBOD

%doc %{CORE_ROOT}/man
%attr (-, dbod, dbod) /var/log/dbod

%changelog
* Wed Jan 30 2019 Charles Delort <cdelort@cern.ch> 0.78.4
- Improve logging
* Thu Oct 4 2018 Ignacio Coterillo <icoteril@cern.ch> 0.78.3
- Fix remote InfluxDB ping
* Wed Jan 7 2018 Ignacio Coterillo <icoteril@cern.ch> 0.78.2
- Add missing dependencies: LWP-https, autobox and Module-Loder
- Add Conflicts directive
* Thu Dec 14 2017 Ignacio Coterillo <icoteril@cern.ch> 0.78.1
- Add cerndb-perl-netapp requirement
- Add cerndb-infra-storage requirement
* Tue Dec 12 2017 Ignacio Coterillo <icoteril@cern.ch> 0.78.0
- Fix RAC52 Volume suffix issue
- Remove dbod-core-deps as dependency
* Thu Nov 30 2017 Ignacio Coterillo <icoteril@cern.ch> 0.77.0
- Fix NetApp SDK path
- Fix MANIFEST
* Fri Oct 6 2017 Ignacio Coterillo <icoteril@cern.ch> 0.76.0
- Remove AppDynamics references
- Fix dbod-destroy deployment
- Fix dbod-init call for volume creation
* Tue Sep 26 2017 Ignacio Coterillo <icoteril@cern.ch> 0.75.0
- Add InfluxDB Upgrade scripts
- Add prefix to InfluxDB script
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
