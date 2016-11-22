#!/bin/bash
set -o nounset
set -o errexit

. ./config
echo

backup_timepoint=`ls -l ${backup_directory} | grep -v "total\|journal\|xfsdump" | awk '{print $9 }' | awk -F[_.] '{print $2}' | sort -u`


echo "Time point         Node Name"
echo ---------------------------------------------------------------------------

for timepoint in ${backup_timepoint[@]};
do

  if [ ! -z ${timepoint} ]; then
    echo "$timepoint    " `ls -l ${backup_directory} | grep ${timepoint} | grep -v "journal\|xfsdump" | awk '{print $9 }' | awk -F[_.] '{print $1}' | sort -u`
  fi

done

echo
