#!/bin/bash

# import configs and functions
. ./config
. ./func.sh

if [[ $# -lt 1 ]]; then
    echo "Please input an time point as parameter for restoring monitor. (You can observe the time point form an tar file name.)"
    echo "restore_ceph_monitor.sh <timepoint> [ start ]"
    exit 1
fi

restore_time=${1}
action_after=${2}

echo
echo "Restore monitor from time point \"${1}\""

echo
ceph_mon status
ceph_mon stop
echo


# restore each monitor
for mon in ${ceph_monitor_list[@]};
do
    tar_file_name=${mon}_${restore_time}${tar_extension}
    tar_file_path=${backup_directory}${tar_file_name}

    if [ ! -f ${tar_file_path} ]; then
        echo "[ ${mon} ]: The time point ${restore_time} is not found for ${mon}. ${tar_file_path}"

    else
        echo "[ ${mon} ]: scp ${tar_file_path} to ${temp_directory} on monitor ${mon}"
        scp  -pr ${tar_file_path} ${mon}:${temp_directory}

        echo "[ ${mon} ]: rm ${var_lib_ceph} ${etc_ceph} ${var_log_ceph}"
        ssh     ${mon}   "rm -rf ${var_lib_ceph} ${etc_ceph} ${var_log_ceph}"

        echo "[ ${mon} ]: untar ${temp_directory}${tar_file_name} on ${mon}"
        ssh     ${mon}   "${tar_extract_cmd} ${temp_directory}${tar_file_name}; sync"

        echo "[ ${mon} ]: rm ${temp_directory}${tar_file_name} on ${mon}"
        ssh     ${mon}   "rm -rf ${temp_directory}${tar_file_name}"
    fi

    echo
    sleep ${interval}
done


# start monitor daemon if second argument is specified as 'start'
if [ "${action_after}" == "start" ]; then
    ceph_mon start
fi

echo
