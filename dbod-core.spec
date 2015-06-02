#
# Database On Demand (DBOD) core library SPEC file
#

%define version 0.5

# Trying to avoid Koji post-generation issues
%define __arch_install_post %{nil} # /usr/lib/rpm/check-buildroot
%define debug_package %{nil} # Disables building debug RPM

Summary: DB On Demand Job Dispatching Daemon 
Name: cerndb-sw-dbod-core
Version: %{version}
Release: 1 
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
/usr/local/share/perl5/auto/share/dist/DBOD/dbod-core.conf-template
/usr/local/share/perl5/DBOD/Api.pm
/usr/local/share/perl5/DBOD/Config.pm
/usr/local/share/perl5/DBOD/DB.pm
/usr/local/share/perl5/DBOD/Job.pm
/usr/local/share/perl5/DBOD/Runtime.pm
%attr (-, dbod, dbod) /var/log/dbod

%changelog
* Tue Jun 2 2015 Ignacio Coterillo <icoteril@cern.ch> 0.5.1
- Initial packaging
