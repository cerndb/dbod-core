dbod_core_base=/opt/dbod/perl5
# Initialize SCL for Perl520
export PATH=/opt/rh/rh-perl520/root/usr/local/bin:/opt/rh/rh-perl520/root/usr/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/opt/rh/rh-perl520/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export MANPATH=/opt/rh/rh-perl520/root/usr/share/man:${MANPATH}
# Sets DBOD Core environemnt
export PERL5LIB=${PERL5LIB}:${dbod_core_base}/lib/perl5
export PATH=${PATH}:${dbod_core_base}/bin

