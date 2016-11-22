#!/bin/bash

# import configs and functions
. ./config
. ./func.sh

echo
mkdir -p ${backup_directory}

ceph_mon status
ceph_mon stop
echo

sleep ${interval}


# backup each monitor
for mon in ${ceph_monitor_list[@]};
do
    tar_file="${temp_directory}${mon}_${time_point}${tar_extension}"

    echo "[ ${mon} ]: tar ${var_lib_ceph} and ${etc_ceph} to ${tar_file}"
    ssh     ${mon}   "${tar_create_cmd} ${tar_file} ${var_lib_ceph} ${etc_ceph} ${var_log_ceph}"

    echo "[ ${mon} ]: scp ${mon}:${tar_file} to local dir ${backup_directory}"
    scp -pr ${mon}:${tar_file} ${backup_directory}

    echo "[ ${mon} ]: rm the ${tar_file} on ${mon}"
    ssh     ${mon}   "rm -rf ${tar_file}"

    echo
    sleep $interval
done


# start monitor daemon if first argument is specified as 'start'
action_after=${1}
if [ "${action_after}" == "start" ]; then
    ceph_mon start
fi

echo
echo "Backuped monitor data to tar file in ${backup_directory}"
echo "-------------------------------------------------------------------------"
ls -al ${backup_directory} | grep ${time_point}

echo
