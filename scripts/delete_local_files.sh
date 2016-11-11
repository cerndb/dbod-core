#!/bin/bash
if [ "$#" -ne 1 ]; then
    echo "Use: delete_local_files.sh instance_name"
    exit -1
fi
instance_name=$1
instance_name_uppercase=${1^^}
echo "Instance: $instance_name_uppercase Unmounting the volumes, and deleting the scripts"
umount /ORA/dbs02/${instance_name_uppercase}
umount /ORA/dbs03/${instance_name_uppercase}
cp /etc/fstab /etc/fstab.bak
sed -i '/${instance_name_uppercase}/d' /etc/fstab

find /ORA/dbs01/syscontrol/local/logs/dod/ -depth -name "*dod_${instance_name}_*" -delete
find /etc/rc.d/rc*/ /etc/rc.d/init.d/ /etc/init.d/ -depth -name "*dod_${instance_name}" -delete

# Only for MySQL:
rm -f /etc/logrotate.d/dod_${instance_name}-*;

echo "Unmounting and deletion done for instance ${instance_name}";

