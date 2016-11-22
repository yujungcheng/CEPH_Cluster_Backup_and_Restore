#!/bin/bash

# import configs and functions
. ./config
. ./func.sh

if [[ $# -lt 1 ]]; then
    echo "Please input an time point as parameter for restoring osd. (You can observe the time point form an tar file name.)"
    exit 1
fi

restore_time=${1}
action_after=${2}

echo
echo "Restore osd from time point \"${restore_time}\""

echo
ceph_osd status
ceph_osd stop
echo


for osd in ${ceph_osd_list[@]};
do
    tar_file_name="${osd}_${restore_time}${tar_extension}"
    tar_file_path="${backup_directory}${tar_file_name}"

    if [ ! -f ${tar_file_path} ]; then
        echo     "[ ${osd}] The time point ${restore_time} is not found for ${osd}."

    else
        # restore /var/lib/ceph/ directory
        echo     "[ ${osd} ]: scp ${tar_file_path} to ${temp_directory}${tar_file_name} on osd ${osd}"
        scp -pr ${tar_file_path} ${osd}:${temp_directory}

        echo     "[ ${osd} ]: untar ${temp_directory}${tar_file_name} on ${osd}"
        ssh         ${osd}   "${tar_extract_cmd} ${temp_directory}${tar_file_name}; sync"

        echo     "[ ${osd} ]: rm ${temp_directory}${tar_file_name} on ${osd}"
        ssh         ${osd}   "rm -rf ${temp_directory}${tar_file_name}"

        # restore /var/lib/ceph/osd/* directory (XFS mount point)
        echo     "[ ${osd} ]: get sub-dirname in ${var_lib_ceph_osd}"
        ssh         ${osd} "ls -l ${var_lib_ceph_osd} | grep ceph-" | awk '{print $9}' > ${osd_list}

        cat         ${osd_list}
        readarray osd_dirs < ${osd_list}

        for osd_dir in "${osd_dirs[@]}"
        do
            osd_dir=${osd_dir//$'\n'/}
            var_lib_ceph_osd_dir="${var_lib_ceph_osd}/${osd_dir}"

            ## before xfsrestore, copy origional journal symbolic and journal_uuid file first.
            ## then clear all data in /var/lib/ceph/osd/ceph-#/
            journal_path="${var_lib_ceph_osd_dir}/journal"
            journal_uuid="${var_lib_ceph_osd_dir}/journal_uuid"

            echo "[ ${osd} ]: copy the journal symbolic and journal_uuid file."
            ssh     ${osd} "cp -afpR ${journal_path} ${journal_uuid} ${temp_directory}; sync"

            echo "[ ${osd} ]: rm all osd data in ${var_lib_ceph_osd_dir}"
            ssh     ${osd} "rm -rf ${var_lib_ceph_osd_dir}/* ; sync"

            ## xfsrestore osd mount point
            osd_xfsdump_file="${osd}.${osd_dir}.xfsdump_${restore_time}"
            osd_xfsdump_path="${backup_directory}${osd_xfsdump_file}"

            echo "[ ${osd} ]: scp ${osd_xfsdump_file} file to ${temp_directory}"
            scp -pr ${osd_xfsdump_path} ${osd}:${temp_directory}

            echo "[ ${osd} ]: xfsrestore ${var_lib_ceph_osd_dir}"
            ssh     ${osd} "${xfsrestore_cmd} -f ${temp_directory}${osd_xfsdump_file} ${var_lib_ceph_osd_dir}"

            echo "[ ${osd} ]: rm ${osd_xfsdump_file}"
            ssh     ${osd} "rm -f ${temp_directory}${osd_xfsdump_file}"

            ## move back journal symbolic and journal_uuid files
            echo "[ ${osd} ]: mv back the journal symbolic and journal_uuid file."
            ssh     ${osd} "mv ${temp_directory}journal ${temp_directory}journal_uuid ${var_lib_ceph_osd_dir}; sync"

            ## dump back journal data
            journal_dump="${osd}.${osd_dir}.journal_${restore_time}"
            journal__tar="${journal_dump}${tar_extension}"

            echo "[ ${osd} ]: scp ${backup_directory}${journal__tar} to ${temp_directory} on ${osd}"
            scp -pr ${backup_directory}${journal__tar} ${osd}:${temp_directory}

            echo "[ ${osd} ]: untar ${journal__tar} on ${osd}"
            ssh     ${osd} "${tar_extract_cmd} ${temp_directory}${journal__tar}; sync"

            echo "[ ${osd} ]: dd ${temp_directory}${journal_dump} to ${journal_path}"
            ssh     ${osd} "dd if=${temp_directory}${journal_dump} of=${journal_path} bs=4096"

            echo "[ ${osd} ]: rm ${temp_directory}${journal_dump} on ${osd}"
            ssh     ${osd} "rm -f ${temp_directory}${journal_dump}"

            echo "[ ${osd} ]: rm ${temp_directory}${journal__tar} on ${osd}"
            ssh     ${osd} "rm -f ${temp_directory}${journal__tar}"
        done

        rm -f ${osd_list}
    fi

    echo
    sleep ${interval}
done


# start monitor daemon if second argument is specified as 'start'
if [ "${action_after}" == "start" ]; then
    ceph_osd start
fi
