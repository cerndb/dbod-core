#!/bin/bash
if [ "$#" -ne 1 ]; then
    echo "Use: delete_local_files.sh instance_name"
    exit -1
fi
instance_name=$1;
instance_name_uppercase=${1^^};
echo "instance is $instance_name_uppercase: unmounting the volumes, and deleting the scripts";
umount /ORA/dbs02/$instance_name_uppercase;
umount /ORA/dbs03/$instance_name_uppercase;
cp /etc/fstab /etc/fstab.bak;
grep -vwE $instance_name_uppercase /etc/fstab.bak > /etc/fstab;

find /ORA/dbs01/syscontrol/local/logs/dod/ -depth -name "*dod_$instance_name_*" -delete;
find /etc/rc.d/rc*/ /etc/rc.d/init.d/ /etc/init.d/ -depth -name "*dod_$instance_name" -delete;

# Only for MySQL:
rm -f /etc/logrotate.d/dod_$instance_name-slow-queries-rotation;

echo "unmounting and deletion done for instance $instance_name";

