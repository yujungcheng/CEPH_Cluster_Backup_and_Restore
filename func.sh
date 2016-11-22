#!/bin/bash

. ./config

function ceph_mon() {
    for mon in ${ceph_monitor_list[@]};
    do
        echo     "[ ${mon} ]: ${1} ceph-mon daemon id=${mon}"

        case ${1} in
            stop)
                ssh ${mon} ${ceph_mon_stop}${mon}
                ;;
            start)
                ssh ${mon} ${ceph_mon_start}${mon}
                ;;
            status)
                ssh ${mon} ${ceph_mon_status}${mon}
                ;;
            *)
                echo "Unknown manage option. ${1}"
                ;;
        esac

        ssh         ${mon} "sync"
    done
}


function ceph_osd() {
    for osd in ${ceph_osd_list[@]};
    do
        ssh             ${osd} "ls -l ${var_lib_ceph_osd} | grep ceph-" | awk '{print $9}' > /tmp/osds

        while read osd_dir
        do
            oid=${osd_dir#${osd_prefix}}

            echo     "[ ${osd} ]: ${1} ceph-osd daemon id=${oid}"

            case ${1} in
                stop)
                    ssh ${osd} ${ceph_osd_stop}${oid}
                    ;;
                start)
                    ssh ${osd} ${ceph_osd_start}${oid}
                    ;;
                status)
                    ssh ${osd} ${ceph_osd_status}${oid}
                    ;;
                *)
                    echo "Unknown manage option. ${1}"
                    ;;

            esac
        done < /tmp/osds

        ssh             ${osd} "sync"
    done
}
