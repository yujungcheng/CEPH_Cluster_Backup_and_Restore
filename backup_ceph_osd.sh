#!/bin/bash

# import configs and functions
. ./config
. ./func.sh


# stop ceph osd daemon
ceph_osd status
ceph_osd stop
echo


mkdir -p ${backup_directory}
sleep ${interval}
echo


# backup each osd dir
for osd in ${ceph_osd_list[@]};
do
    tar_file_name="${osd}_${time_point}${tar_extension}"
    tar_file_path="${temp_directory}${tar_file_name}"

    # tar /var/lib/ceph  (exclude /var/lib/ceph/osd/*)
    echo     "[ ${osd} ]: tar ${var_lib_ceph} ${etc_ceph} to ${tar_file_path} (exclude ${var_lib_ceph_osd}/${osd_prefix}*)"
    ssh         ${osd}   "${tar_create_cmd} ${tar_file_path} --exclude=${var_lib_ceph_osd}/${osd_prefix}* ${var_lib_ceph} ${etc_ceph} ${var_log_ceph}"

    echo     "[ ${osd} ]: scp ${osd}:${tar_file_path} to local dir ${backup_directory}"
    scp -pr     ${osd}:${tar_file_path} ${backup_directory}

    echo     "[ ${osd} ]: rm ${tar_file_path} on ${osd}"
    ssh         ${osd}   "rm -rf ${tar_file_path}"

    # dump osd file and journal data
    echo     "[ ${osd} ]: get sub-dirname in ${var_lib_ceph_osd}"
    ssh         ${osd} "ls -l ${var_lib_ceph_osd} | grep ceph-" | awk '{print $9}' > ${osd_list}

    cat         ${osd_list}
    readarray osd_dirs < ${osd_list}

    for osd_dir in "${osd_dirs[@]}"
    do
        osd_dir=${osd_dir//$'\n'/}
        ## dump osd journal data
        journal_path="${var_lib_ceph_osd}/${osd_dir}/journal"
        journal_dump="${temp_directory}${osd}.${osd_dir}.journal_${time_point}"
        journal__tar="${journal_dump}${tar_extension}"

        echo "[ ${osd} ]: dd ${journal_path} to ${journal_dump}"
        ssh     ${osd}   "dd if=${journal_path} of=${journal_dump} bs=4096"

        echo "[ ${osd} ]: tar journal dump file to ${journal_dump}.tar"
        ssh     ${osd}   "${tar_create_cmd} ${journal__tar} ${journal_dump}"

        echo "[ ${osd} ]: scp ${osd}:${journal_dump}.tar to ${backup_directory}"
        scp -pr ${osd}:${journal__tar} ${backup_directory}

        echo "[ ${osd} ]: rm ${journal_dump} and ${journal_dump}${tar_extension} on ${osd}"
        ssh     ${osd}   "rm -rf ${journal_dump} ${journal__tar}"

        ## xfsdump the osd mounted file system
        osd_mount_point="${var_lib_ceph_osd}/${osd_dir}"
        osd_xfsdump_file="${temp_directory}${osd}.${osd_dir}.xfsdump_${time_point}"

        echo "[ ${osd} ]: xfsdump ${osd_mount_point} to ${osd_xfsdump_file}"
        ssh     ${osd}   "${xfsdump_cmd} -f ${osd_xfsdump_file} -L ${osd_dir} -M ${temp_directory} ${osd_mount_point}"

        echo "[ ${osd} ]: scp ${osd}:${osd_xfsdump_file} to ${backup_directory}"
        scp -pr ${osd}:${osd_xfsdump_file} ${backup_directory}

        echo "[ ${osd} ]: rm ${osd_xfsdump_file} on ${osd}"
        ssh     ${osd}   "rm -rf ${osd_xfsdump_file}"
    done

    rm -f ${osd_list}

    echo
    sleep ${interval}
done


# start osd daemon if first argument is specified as 'start'
action_after=${1}
if [ "${action_after}" == "start" ]; then
    ceph_osd start
fi


echo "Backuped OSD data to tar file in \"${backup_directory}\""
echo "-------------------------------------------------------------------------"
ls -al ${backup_directory} | grep ${time_point}
