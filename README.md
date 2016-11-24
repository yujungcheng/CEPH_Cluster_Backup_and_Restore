請用 RAW 模式觀看

# ceph_backup_restore
說明：
  1. 備份 ceph monitor 與 osd 上的 /var/lib/ceph 與 /etc/ceph 兩個資料夾。/var/lib/ceph 內儲存各 ceph 角色的資料，/etc/ceph 儲存 ceph 的設定與 keyring 等檔案。亦可額外備份 /var/log/ceph 資料夾。
  2. 備份或還原前會強制停止該 Ceph 角色所有 Node 的 ceph daemon。如備份 monitor 時，所有 monitor Node 的 monitor daemon 皆會停止後再進行備份。
  3. 備份工具為 tar 及 xfsdump/xfsrestore。tar 使用 gz 格式壓縮。
  4. 所有 osd 主機上需裝有 xfsdump 與 xfsrestore 工具。(apt-get install xfsdump)
  5. 備份 monitor 時，各 monitor node 產生1個 tar 檔，檔名格式為 
    <主機名稱>_<時間點>.tar.gz
    時間點格式為 YYYYMMDDhhmmss
  6. 備份 osd 時，各 osd node 至少產生2個 tar 檔及1個 xfsdump 檔，分別備份：
    a. /var/lib/ceph/ 底下各資料夾，除了 /var/lib/ceph/osd/ 底下的資料夾。檔名格式為 <主機名稱>_<時間點>.tar.gz
    b. 各 ceph osd 的 journal 檔案。檔名格式為
      <主機名稱>.<掛載資料夾名稱>.journal_<時間點>.tar.gz
    c. /var/lib/ceph/osd/ 底下的 XFS 掛載點，以 xfsdump 工具備份。檔名格式為 <主機名稱>.<掛載資料夾名稱>.xfsdump_<時間點>
  7. 所有備份的檔案會傳送至至行備份腳本的主機上，預設資料夾為當前路徑的 ceph_backup 資料夾 (ceph_backup 資料夾會自行創建)
  8. 執行備份與還原的主機需設有與 ceph cluster 的 ssh 免輸入密碼。
  9. 還原時，目標 ceph cluster 的網路環境，主機名稱，/etc/hosts，monitor 與 osd 數量必須與原先的 ceph cluster 一致。其儲存的容量大小亦必須大於備份檔案大小 (需後續測試)。
  10. 備份或還原時，暫存用的資料夾空間需大於備份檔。儲存備份的資料夾需要大於所有 ceph node 的 ceph 資料大小。
  11. ceph cluster 環境上，osd journal 應使用額外的 partition。
  12. OSD 備份所佔用空間約為 RAW USED + 每個 OSD Journal 大小 ( journal 會以 gz 壓縮後儲存) 
    root@admin:~/backup_restore_ceph# ceph df
    GLOBAL:
        SIZE       AVAIL      RAW USED     %RAW USED 
        24158M     23246M         912M          3.78 
    POOLS:
        NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
        rbd      0      301M      3.74         7748M          86 


操作腳本：
  backup_ceph_monitor.sh [start]
    備份 monitor ，直接執行即可。
    第1個參數指定為 ”start” 時，備份後啟動 monitor daemon。
  backup_ceph_osd.sh
    備份 osd ，直接執行即可。
    第1個參數指定為 ”start” 時，備份後啟動 osd daemon。
  restore_ceph_monitor.sh <還原時間> [start]
    還原 monitor ，指令第一個參數需帶入還原時間點。
    第2個參數指定為 ”start” 時，還原後啟動 monitor daemon。
  restore_ceph_osd.sh <還原時間> [stop]
    還原 osd ，指令第一個參數需帶入還原時間。
    第2個參數指定為”stop”時，還原後不啟動osd daemon。
  list_ceph_backup.sh
    列出目前備份的 ceph monitor 資訊，直接執行即可 ，輸出範例:
    root@admin:~/backup_restore_ceph# ./list_ceph_backup.sh
    Time point         Node Name
    -------------------------------------------------------------------
    20160831151037     mon01 mon02 mon03
    20160831151046     osd01 osd02 osd03
    20160831160328     mon01 mon02 mon03
    20160831160337     osd01 osd02 osd03
    20160831162208     mon01 mon02 mon03
    20160831162217     osd01 osd02 osd03


設定檔與共用函數：
  func.sh
   共用函數，包含啟動與停止 ceph monitor 和 osd daemon 。
  config
   設定檔, ceph 主機名稱，備份路徑等設定 。


後續可能附加功能與相關測試：
  1. 還原至與原 Ceph Cluster 的 OSD 容量不同的 Ceph Cluster。OSD 容量必須大於備份。
  2. 還原至與原 Ceph Cluster 的 Journal 大小不同的 Ceph Cluster。Journal 大小必須大於備份。
  3. Monitor 與 OSD 的非同步版本還原測試。
  4. 加入其他 Ceph 角色的備份 RGW, MDS & Client, 加入 fsid 資訊等等...
  5. 後續會考慮加入以下主機環境等相關檔案的到tar備份中，同步必要的設定從原環境至目標環境上。
    /etc/hostname
    /etc/hosts
    /etc/resolv.conf
    /etc/resolvconf/
    /etc/network/interfaces
  6. 是否可從 OSD 中只萃取出一份 replica，根據 PG 號碼比對之類的方式...使還原後由ceph自行修復至 replica 數量。
  7. 容量檢查，網路檢查，本地端掛載NFS備份，全 Node 同時備份與還原，所有Ceph OSD 的備份檔案再打包壓縮成一個壓縮檔(可能可以降低至三分之一的總備份大小) ......
  8. 其他再想想...。

實測備份與還原：

# 一套剛完成部屬的 Ceph Cluster, 其 fsid 為 72cfef0e-4cb9-41d3-b58d-0770037a62bc  
root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 32, quorum 0,1,2 mon01,mon02,mon03
     osdmap e46: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v226: 64 pgs, 1 pools, 0 bytes data, 1 objects
            103 MB used, 24054 MB / 24158 MB avail
                  64 active+clean
root@admin:~/backup_restore_ceph# rbd ls -l
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     24054M         103M          0.43 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0         0         0         8018M           1


# 建立 RBD Image (rbd0, 128M)，格式化後並掛載，dd 寫入一個亂數資料檔案。
root@admin:~/backup_restore_ceph# rbd create -s 128 rbd0
root@admin:~/backup_restore_ceph# rbd map rbd0
/dev/rbd0
root@admin:~/backup_restore_ceph# mkfs.ext4 /dev/rbd0
mke2fs 1.42.9 (4-Feb-2014)
Discarding device blocks: done                            
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=4096 blocks, Stripe width=4096 blocks
32768 inodes, 131072 blocks
6553 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=67371008
16 block groups
8192 blocks per group, 8192 fragments per group
2048 inodes per group
Superblock backups stored on blocks: 
	8193, 24577, 40961, 57345, 73729


Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done 


root@admin:~/backup_restore_ceph# mount /dev/rbd0 /mnt
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  2.2G  4.8G  32% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  392K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M  1.6M  110M   2% /mnt
root@admin:~/backup_restore_ceph# dd if=/dev/urandom of=/mnt/file bs=1M count=64
64+0 records in
64+0 records out
67108864 bytes (67 MB) copied, 2.26314 s, 29.7 MB/s
root@admin:~/backup_restore_ceph# sync


# 複製一分該檔案到 /tmp 底下
root@admin:~/backup_restore_ceph# cp -afpR /mnt/file /tmp/
root@admin:~/backup_restore_ceph# diff /mnt/file /tmp/file


# 檢查 Ceph 使用空間, 最後使用約 310 MB 。
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  2.2G  4.8G  32% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  392K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M   66M   46M  60% /mnt
root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 32, quorum 0,1,2 mon01,mon02,mon03
     osdmap e46: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v272: 64 pgs, 1 pools, 84573 kB data, 26 objects
            499 MB used, 23658 MB / 24158 MB avail
                  64 active+clean
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23658M         499M          2.07 
POOLS:
    NAME     ID     USED       %USED     MAX AVAIL     OBJECTS 
    rbd      0      84573k      1.03         7885M          26 
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23848M         310M          1.28 
POOLS:
    NAME     ID     USED       %USED     MAX AVAIL     OBJECTS 
    rbd      0      84573k      1.03         7949M          26 


root@admin:~/backup_restore_ceph# rbd ls -l
NAME SIZE PARENT FMT PROT LOCK 
rbd0 128M          2 


# 卸載與unmap rbd0, 然後開始進行備份 monitor 與 osd ，此次備份中含有 128MB 的 RBD Image (rbd0), RAW USED 佔用 312MB
root@admin:~/backup_restore_ceph# umount /mnt
root@admin:~/backup_restore_ceph# rbd unmap rbd0
root@admin:~/backup_restore_ceph# rbd ls -l
NAME SIZE PARENT FMT PROT LOCK 
rbd0 128M          2           
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23846M         312M          1.29 
POOLS:
    NAME     ID     USED       %USED     MAX AVAIL     OBJECTS 
    rbd      0      84573k      1.03         7947M          26


root@admin:~/backup_restore_ceph# ./backup_ceph_monitor.sh ; ./backup_ceph_osd.sh 


[ mon01 ]: status ceph-mon daemon id=mon01
ceph-mon (ceph/mon01) start/running, process 4383
[ mon02 ]: status ceph-mon daemon id=mon02
ceph-mon (ceph/mon02) start/running, process 4366
[ mon03 ]: status ceph-mon daemon id=mon03
ceph-mon (ceph/mon03) start/running, process 4405
[ mon01 ]: stop ceph-mon daemon id=mon01
ceph-mon stop/waiting
[ mon02 ]: stop ceph-mon daemon id=mon02
ceph-mon stop/waiting
[ mon03 ]: stop ceph-mon daemon id=mon03
ceph-mon stop/waiting


[ mon01 ]: tar /var/lib/ceph and /etc/ceph to /tmp/mon01_20160902155856.tar.gz
/bin/tar: Removing leading `/' from member names
[ mon01 ]: scp mon01:/tmp/mon01_20160902155856.tar.gz to local dir ./ceph_backup/
mon01_20160902155856.tar.gz                                                                                                                                 100%  372KB 371.8KB/s   00:00    
[ mon01 ]: rm the /tmp/mon01_20160902155856.tar.gz on mon01


[ mon02 ]: tar /var/lib/ceph and /etc/ceph to /tmp/mon02_20160902155856.tar.gz
/bin/tar: Removing leading `/' from member names
[ mon02 ]: scp mon02:/tmp/mon02_20160902155856.tar.gz to local dir ./ceph_backup/
mon02_20160902155856.tar.gz                                                                                                                                 100%  379KB 379.3KB/s   00:00    
[ mon02 ]: rm the /tmp/mon02_20160902155856.tar.gz on mon02


[ mon03 ]: tar /var/lib/ceph and /etc/ceph to /tmp/mon03_20160902155856.tar.gz
/bin/tar: Removing leading `/' from member names
[ mon03 ]: scp mon03:/tmp/mon03_20160902155856.tar.gz to local dir ./ceph_backup/
mon03_20160902155856.tar.gz                                                                                                                                 100%  379KB 379.3KB/s   00:00    
[ mon03 ]: rm the /tmp/mon03_20160902155856.tar.gz on mon03




Backuped monitor data to tar file in ./ceph_backup/
-------------------------------------------------------------------------
-rw-r--r-- 1 root root 380762 Sep  2 15:59 mon01_20160902155856.tar.gz
-rw-r--r-- 1 root root 388349 Sep  2 15:59 mon02_20160902155856.tar.gz
-rw-r--r-- 1 root root 388405 Sep  2 15:59 mon03_20160902155856.tar.gz




[ osd01 ]: status ceph-osd daemon id=0
ceph-osd (ceph/0) start/running, process 7976
[ osd02 ]: status ceph-osd daemon id=1
ceph-osd (ceph/1) start/running, process 8010
[ osd03 ]: status ceph-osd daemon id=2
ceph-osd (ceph/2) start/running, process 8019
[ osd01 ]: stop ceph-osd daemon id=0
ceph-osd stop/waiting
[ osd02 ]: stop ceph-osd daemon id=1
ceph-osd stop/waiting
[ osd03 ]: stop ceph-osd daemon id=2
ceph-osd stop/waiting


[ osd01 ]: tar /var/lib/ceph /etc/ceph to /tmp/osd01_20160902155905.tar.gz (exclude /var/lib/ceph/osd/ceph-*)
/bin/tar: Removing leading `/' from member names
[ osd01 ]: scp osd01:/tmp/osd01_20160902155905.tar.gz to local dir ./ceph_backup/
osd01_20160902155905.tar.gz                                                                                                                                 100%  910     0.9KB/s   00:00    
[ osd01 ]: rm /tmp/osd01_20160902155905.tar.gz on osd01
[ osd01 ]: get sub-dirname in /var/lib/ceph/osd
ceph-0
[ osd01 ]: dd /var/lib/ceph/osd/ceph-0/journal to /tmp/osd01.ceph-0.journal_20160902155905
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.240508 s, 558 MB/s
[ osd01 ]: tar journal dump file to /tmp/osd01.ceph-0.journal_20160902155905.tar
/bin/tar: Removing leading `/' from member names
[ osd01 ]: scp osd01:/tmp/osd01.ceph-0.journal_20160902155905.tar to ./ceph_backup/
osd01.ceph-0.journal_20160902155905.tar.gz                                                                                                                  100%  116MB 116.2MB/s   00:00    
[ osd01 ]: rm /tmp/osd01.ceph-0.journal_20160902155905 and /tmp/osd01.ceph-0.journal_20160902155905.tar.gz on osd01
[ osd01 ]: xfsdump /var/lib/ceph/osd/ceph-0 to /tmp/osd01.ceph-0.xfsdump_20160902155905
/usr/sbin/xfsdump: using file dump (drive_simple) strategy
/usr/sbin/xfsdump: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsdump: level 0 dump of osd01:/var/lib/ceph/osd/ceph-0
/usr/sbin/xfsdump: dump date: Fri Sep  2 15:59:30 2016
/usr/sbin/xfsdump: session id: 98d1cf99-01ce-43cf-b89f-f76799601af9
/usr/sbin/xfsdump: session label: "ceph-0"
/usr/sbin/xfsdump: ino map phase 1: constructing initial dump list
/usr/sbin/xfsdump: ino map phase 2: skipping (no pruning necessary)
/usr/sbin/xfsdump: ino map phase 3: skipping (only one dump stream)
/usr/sbin/xfsdump: ino map construction complete
/usr/sbin/xfsdump: estimated dump size: 73828928 bytes
/usr/sbin/xfsdump: creating dump session media file 0 (media 0, file 0)
/usr/sbin/xfsdump: dumping ino map
/usr/sbin/xfsdump: dumping directories
/usr/sbin/xfsdump: dumping non-directory files
/usr/sbin/xfsdump: ending media file
/usr/sbin/xfsdump: media file size 73740760 bytes
/usr/sbin/xfsdump: dump size (non-dir files) : 73485008 bytes
/usr/sbin/xfsdump: dump complete: 2 seconds elapsed
/usr/sbin/xfsdump: Dump Summary:
/usr/sbin/xfsdump:   stream 0 /tmp/osd01.ceph-0.xfsdump_20160902155905 OK (success)
/usr/sbin/xfsdump: Dump Status: SUCCESS
[ osd01 ]: scp osd01:/tmp/osd01.ceph-0.xfsdump_20160902155905 to ./ceph_backup/
osd01.ceph-0.xfsdump_20160902155905                                                                                                                         100%   70MB  70.3MB/s   00:01    
[ osd01 ]: rm /tmp/osd01.ceph-0.xfsdump_20160902155905 on osd01


[ osd02 ]: tar /var/lib/ceph /etc/ceph to /tmp/osd02_20160902155905.tar.gz (exclude /var/lib/ceph/osd/ceph-*)
/bin/tar: Removing leading `/' from member names
[ osd02 ]: scp osd02:/tmp/osd02_20160902155905.tar.gz to local dir ./ceph_backup/
osd02_20160902155905.tar.gz                                                                                                                                 100%  912     0.9KB/s   00:00    
[ osd02 ]: rm /tmp/osd02_20160902155905.tar.gz on osd02
[ osd02 ]: get sub-dirname in /var/lib/ceph/osd
ceph-1
[ osd02 ]: dd /var/lib/ceph/osd/ceph-1/journal to /tmp/osd02.ceph-1.journal_20160902155905
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.227181 s, 591 MB/s
[ osd02 ]: tar journal dump file to /tmp/osd02.ceph-1.journal_20160902155905.tar
/bin/tar: Removing leading `/' from member names
[ osd02 ]: scp osd02:/tmp/osd02.ceph-1.journal_20160902155905.tar to ./ceph_backup/
osd02.ceph-1.journal_20160902155905.tar.gz                                                                                                                  100%  116MB 116.1MB/s   00:00    
[ osd02 ]: rm /tmp/osd02.ceph-1.journal_20160902155905 and /tmp/osd02.ceph-1.journal_20160902155905.tar.gz on osd02
[ osd02 ]: xfsdump /var/lib/ceph/osd/ceph-1 to /tmp/osd02.ceph-1.xfsdump_20160902155905
/usr/sbin/xfsdump: using file dump (drive_simple) strategy
/usr/sbin/xfsdump: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsdump: level 0 dump of osd02:/var/lib/ceph/osd/ceph-1
/usr/sbin/xfsdump: dump date: Fri Sep  2 15:59:39 2016
/usr/sbin/xfsdump: session id: c7e89214-619c-46b7-98a7-e4cc233429a2
/usr/sbin/xfsdump: session label: "ceph-1"
/usr/sbin/xfsdump: ino map phase 1: constructing initial dump list
/usr/sbin/xfsdump: ino map phase 2: skipping (no pruning necessary)
/usr/sbin/xfsdump: ino map phase 3: skipping (only one dump stream)
/usr/sbin/xfsdump: ino map construction complete
/usr/sbin/xfsdump: estimated dump size: 73684288 bytes
/usr/sbin/xfsdump: creating dump session media file 0 (media 0, file 0)
/usr/sbin/xfsdump: dumping ino map
/usr/sbin/xfsdump: dumping directories
/usr/sbin/xfsdump: dumping non-directory files
/usr/sbin/xfsdump: ending media file
/usr/sbin/xfsdump: media file size 73592824 bytes
/usr/sbin/xfsdump: dump size (non-dir files) : 73339696 bytes
/usr/sbin/xfsdump: dump complete: 2 seconds elapsed
/usr/sbin/xfsdump: Dump Summary:
/usr/sbin/xfsdump:   stream 0 /tmp/osd02.ceph-1.xfsdump_20160902155905 OK (success)
/usr/sbin/xfsdump: Dump Status: SUCCESS
[ osd02 ]: scp osd02:/tmp/osd02.ceph-1.xfsdump_20160902155905 to ./ceph_backup/
osd02.ceph-1.xfsdump_20160902155905                                                                                                                         100%   70MB  70.2MB/s   00:00    
[ osd02 ]: rm /tmp/osd02.ceph-1.xfsdump_20160902155905 on osd02


[ osd03 ]: tar /var/lib/ceph /etc/ceph to /tmp/osd03_20160902155905.tar.gz (exclude /var/lib/ceph/osd/ceph-*)
/bin/tar: Removing leading `/' from member names
[ osd03 ]: scp osd03:/tmp/osd03_20160902155905.tar.gz to local dir ./ceph_backup/
osd03_20160902155905.tar.gz                                                                                                                                 100%  913     0.9KB/s   00:00    
[ osd03 ]: rm /tmp/osd03_20160902155905.tar.gz on osd03
[ osd03 ]: get sub-dirname in /var/lib/ceph/osd
ceph-2
[ osd03 ]: dd /var/lib/ceph/osd/ceph-2/journal to /tmp/osd03.ceph-2.journal_20160902155905
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.230263 s, 583 MB/s
[ osd03 ]: tar journal dump file to /tmp/osd03.ceph-2.journal_20160902155905.tar
/bin/tar: Removing leading `/' from member names
[ osd03 ]: scp osd03:/tmp/osd03.ceph-2.journal_20160902155905.tar to ./ceph_backup/
osd03.ceph-2.journal_20160902155905.tar.gz                                                                                                                  100%  116MB 116.3MB/s   00:01    
[ osd03 ]: rm /tmp/osd03.ceph-2.journal_20160902155905 and /tmp/osd03.ceph-2.journal_20160902155905.tar.gz on osd03
[ osd03 ]: xfsdump /var/lib/ceph/osd/ceph-2 to /tmp/osd03.ceph-2.xfsdump_20160902155905
/usr/sbin/xfsdump: using file dump (drive_simple) strategy
/usr/sbin/xfsdump: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsdump: level 0 dump of osd03:/var/lib/ceph/osd/ceph-2
/usr/sbin/xfsdump: dump date: Fri Sep  2 15:59:50 2016
/usr/sbin/xfsdump: session id: 30d95715-4164-48bb-ba4b-08380901f1f8
/usr/sbin/xfsdump: session label: "ceph-2"
/usr/sbin/xfsdump: ino map phase 1: constructing initial dump list
/usr/sbin/xfsdump: ino map phase 2: skipping (no pruning necessary)
/usr/sbin/xfsdump: ino map phase 3: skipping (only one dump stream)
/usr/sbin/xfsdump: ino map construction complete
/usr/sbin/xfsdump: estimated dump size: 73348736 bytes
/usr/sbin/xfsdump: creating dump session media file 0 (media 0, file 0)
/usr/sbin/xfsdump: dumping ino map
/usr/sbin/xfsdump: dumping directories
/usr/sbin/xfsdump: dumping non-directory files
/usr/sbin/xfsdump: ending media file
/usr/sbin/xfsdump: media file size 73253488 bytes
/usr/sbin/xfsdump: dump size (non-dir files) : 72999704 bytes
/usr/sbin/xfsdump: dump complete: 0 seconds elapsed
/usr/sbin/xfsdump: Dump Summary:
/usr/sbin/xfsdump:   stream 0 /tmp/osd03.ceph-2.xfsdump_20160902155905 OK (success)
/usr/sbin/xfsdump: Dump Status: SUCCESS
[ osd03 ]: scp osd03:/tmp/osd03.ceph-2.xfsdump_20160902155905 to ./ceph_backup/
osd03.ceph-2.xfsdump_20160902155905                                                                                                                         100%   70MB  69.9MB/s   00:01    
[ osd03 ]: rm /tmp/osd03.ceph-2.xfsdump_20160902155905 on osd03


Backuped OSD data to tar file in "./ceph_backup/"
-------------------------------------------------------------------------
-rw-r--r-- 1 root root 121790866 Sep  2 15:59 osd01.ceph-0.journal_20160902155905.tar.gz
-rw-r--r-- 1 root root  73740760 Sep  2 15:59 osd01.ceph-0.xfsdump_20160902155905
-rw-r--r-- 1 root root       910 Sep  2 15:59 osd01_20160902155905.tar.gz
-rw-r--r-- 1 root root 121752269 Sep  2 15:59 osd02.ceph-1.journal_20160902155905.tar.gz
-rw-r--r-- 1 root root  73592824 Sep  2 15:59 osd02.ceph-1.xfsdump_20160902155905
-rw-r--r-- 1 root root       912 Sep  2 15:59 osd02_20160902155905.tar.gz
-rw-r--r-- 1 root root 121921802 Sep  2 15:59 osd03.ceph-2.journal_20160902155905.tar.gz
-rw-r--r-- 1 root root  73253488 Sep  2 15:59 osd03.ceph-2.xfsdump_20160902155905
-rw-r--r-- 1 root root       913 Sep  2 15:59 osd03_20160902155905.tar.gz


# 完成備份後，啟動所有 Ceph daemon, 檢查是否正常運作。
root@admin:~/backup_restore_ceph# ../ceph_tool/ceph_start.sh all
ceph-mon (ceph/mon01) start/running, process 4933
ceph-mon (ceph/mon02) start/running, process 4932
ceph-mon (ceph/mon03) start/running, process 4961
ceph-osd (ceph/0) start/running, process 9203
ceph-osd (ceph/1) start/running, process 9241
ceph-osd (ceph/2) start/running, process 9266


root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 36, quorum 0,1,2 mon01,mon02,mon03
     osdmap e50: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v339: 64 pgs, 1 pools, 84573 kB data, 26 objects
            308 MB used, 23850 MB / 24158 MB avail
                  64 active+clean
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23850M         308M          1.28 
POOLS:
    NAME     ID     USED       %USED     MAX AVAIL     OBJECTS 
    rbd      0      84573k      1.03         7950M          26 
root@admin:~/backup_restore_ceph# rbd ls -l
NAME SIZE PARENT FMT PROT LOCK 
rbd0 128M          2      


# 刪除 rbd0, 檢查 ceph 容量使用，使用減至 100 多 MB, (原先有308MB)
root@admin:~/backup_restore_ceph# rbd rm rbd0
Removing image: 100% complete...done.
root@admin:~/backup_restore_ceph# rbd ls -l
root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 36, quorum 0,1,2 mon01,mon02,mon03
     osdmap e50: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v344: 64 pgs, 1 pools, 0 bytes data, 1 objects
            104 MB used, 24054 MB / 24158 MB avail
                  64 active+clean
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     24054M         104M          0.43 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0         0         0         8018M           1 


# 使用之前的備份進行還原
root@admin:~/backup_restore_ceph# ./list_ceph_backup.sh 


Time point         Node Name
---------------------------------------------------------------------------
20160902155856     mon01 mon02 mon03
20160902155905     osd01 osd02 osd03


root@admin:~/backup_restore_ceph# ./restore_ceph_monitor.sh 20160902155856; ./restore_ceph_osd.sh 20160902155905


Restore monitor from time point "20160902155856"


[ mon01 ]: status ceph-mon daemon id=mon01
ceph-mon (ceph/mon01) start/running, process 4933
[ mon02 ]: status ceph-mon daemon id=mon02
ceph-mon (ceph/mon02) start/running, process 4932
[ mon03 ]: status ceph-mon daemon id=mon03
ceph-mon (ceph/mon03) start/running, process 4961
[ mon01 ]: stop ceph-mon daemon id=mon01
ceph-mon stop/waiting
[ mon02 ]: stop ceph-mon daemon id=mon02
ceph-mon stop/waiting
[ mon03 ]: stop ceph-mon daemon id=mon03
ceph-mon stop/waiting


[ mon01 ]: scp ./ceph_backup/mon01_20160902155856.tar.gz to /tmp/ on monitor mon01
mon01_20160902155856.tar.gz                                                                                                                                 100%  372KB 371.8KB/s   00:00    
[ mon01 ]: rm /var/lib/ceph /etc/ceph 
[ mon01 ]: untar /tmp/mon01_20160902155856.tar.gz on mon01
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-mds/ceph.keyring
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/bootstrap-rgw/ceph.keyring
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mon/ceph-mon01/
var/lib/ceph/mon/ceph-mon01/keyring
var/lib/ceph/mon/ceph-mon01/done
var/lib/ceph/mon/ceph-mon01/upstart
var/lib/ceph/mon/ceph-mon01/store.db/
var/lib/ceph/mon/ceph-mon01/store.db/MANIFEST-000028
var/lib/ceph/mon/ceph-mon01/store.db/CURRENT
var/lib/ceph/mon/ceph-mon01/store.db/000041.ldb
var/lib/ceph/mon/ceph-mon01/store.db/LOCK
var/lib/ceph/mon/ceph-mon01/store.db/000039.ldb
var/lib/ceph/mon/ceph-mon01/store.db/000036.log
var/lib/ceph/mon/ceph-mon01/store.db/000040.ldb
var/lib/ceph/mon/ceph-mon01/store.db/000038.ldb
var/lib/ceph/mon/ceph-mon01/store.db/000042.ldb
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpZVg4fa
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ mon01 ]: rm /tmp/mon01_20160902155856.tar.gz on mon01


[ mon02 ]: scp ./ceph_backup/mon02_20160902155856.tar.gz to /tmp/ on monitor mon02
mon02_20160902155856.tar.gz                                                                                                                                 100%  379KB 379.3KB/s   00:00    
[ mon02 ]: rm /var/lib/ceph /etc/ceph 
[ mon02 ]: untar /tmp/mon02_20160902155856.tar.gz on mon02
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-mds/ceph.keyring
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/bootstrap-rgw/ceph.keyring
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mon/ceph-mon02/
var/lib/ceph/mon/ceph-mon02/keyring
var/lib/ceph/mon/ceph-mon02/done
var/lib/ceph/mon/ceph-mon02/upstart
var/lib/ceph/mon/ceph-mon02/store.db/
var/lib/ceph/mon/ceph-mon02/store.db/MANIFEST-000028
var/lib/ceph/mon/ceph-mon02/store.db/CURRENT
var/lib/ceph/mon/ceph-mon02/store.db/000041.ldb
var/lib/ceph/mon/ceph-mon02/store.db/LOCK
var/lib/ceph/mon/ceph-mon02/store.db/000039.ldb
var/lib/ceph/mon/ceph-mon02/store.db/000036.log
var/lib/ceph/mon/ceph-mon02/store.db/000040.ldb
var/lib/ceph/mon/ceph-mon02/store.db/000038.ldb
var/lib/ceph/mon/ceph-mon02/store.db/000042.ldb
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
etc/ceph/tmp3vemGY
[ mon02 ]: rm /tmp/mon02_20160902155856.tar.gz on mon02


[ mon03 ]: scp ./ceph_backup/mon03_20160902155856.tar.gz to /tmp/ on monitor mon03
mon03_20160902155856.tar.gz                                                                                                                                 100%  379KB 379.3KB/s   00:00    
[ mon03 ]: rm /var/lib/ceph /etc/ceph 
[ mon03 ]: untar /tmp/mon03_20160902155856.tar.gz on mon03
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-mds/ceph.keyring
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/bootstrap-rgw/ceph.keyring
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mon/ceph-mon03/
var/lib/ceph/mon/ceph-mon03/keyring
var/lib/ceph/mon/ceph-mon03/done
var/lib/ceph/mon/ceph-mon03/upstart
var/lib/ceph/mon/ceph-mon03/store.db/
var/lib/ceph/mon/ceph-mon03/store.db/MANIFEST-000028
var/lib/ceph/mon/ceph-mon03/store.db/CURRENT
var/lib/ceph/mon/ceph-mon03/store.db/000041.ldb
var/lib/ceph/mon/ceph-mon03/store.db/LOCK
var/lib/ceph/mon/ceph-mon03/store.db/000039.ldb
var/lib/ceph/mon/ceph-mon03/store.db/000036.log
var/lib/ceph/mon/ceph-mon03/store.db/000040.ldb
var/lib/ceph/mon/ceph-mon03/store.db/000038.ldb
var/lib/ceph/mon/ceph-mon03/store.db/000042.ldb
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpiTL4Dv
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ mon03 ]: rm /tmp/mon03_20160902155856.tar.gz on mon03






Restore osd from time point "20160902155905"


[ osd01 ]: status ceph-osd daemon id=0
ceph-osd (ceph/0) start/running, process 9203
[ osd02 ]: status ceph-osd daemon id=1
ceph-osd (ceph/1) start/running, process 9241
[ osd03 ]: status ceph-osd daemon id=2
ceph-osd (ceph/2) start/running, process 9266
[ osd01 ]: stop ceph-osd daemon id=0
ceph-osd stop/waiting
[ osd02 ]: stop ceph-osd daemon id=1
ceph-osd stop/waiting
[ osd03 ]: stop ceph-osd daemon id=2
ceph-osd stop/waiting


[ osd01 ]: scp ./ceph_backup/osd01_20160902155905.tar.gz to /tmp/osd01_20160902155905.tar.gz on osd osd01
osd01_20160902155905.tar.gz                                                                                                                                 100%  910     0.9KB/s   00:00    
[ osd01 ]: untar /tmp/osd01_20160902155905.tar.gz on osd01
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/tmp/ceph-disk.activate.lock
var/lib/ceph/tmp/ceph-disk.prepare.lock
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpHe3at3
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ osd01 ]: rm /tmp/osd01_20160902155905.tar.gz on osd01
[ osd01 ]: get sub-dirname in /var/lib/ceph/osd
ceph-0
[ osd01 ]: copy the journal symbolic and journal_uuid file.
[ osd01 ]: rm all osd data in /var/lib/ceph/osd/ceph-0
[ osd01 ]: scp osd01.ceph-0.xfsdump_20160902155905 file to /tmp/
osd01.ceph-0.xfsdump_20160902155905                                                                                                                         100%   70MB  70.3MB/s   00:00    
[ osd01 ]: xfsrestore /var/lib/ceph/osd/ceph-0
/usr/sbin/xfsrestore: using file dump (drive_simple) strategy
/usr/sbin/xfsrestore: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsrestore: searching media for dump
/usr/sbin/xfsrestore: examining media file 0
/usr/sbin/xfsrestore: dump description: 
/usr/sbin/xfsrestore: hostname: osd01
/usr/sbin/xfsrestore: mount point: /var/lib/ceph/osd/ceph-0
/usr/sbin/xfsrestore: volume: /dev/vdb1
/usr/sbin/xfsrestore: session time: Fri Sep  2 15:59:30 2016
/usr/sbin/xfsrestore: level: 0
/usr/sbin/xfsrestore: session label: "ceph-0"
/usr/sbin/xfsrestore: media label: "/tmp/"
/usr/sbin/xfsrestore: file system id: 1e016a53-6c82-44f2-8c10-0e4be934f487
/usr/sbin/xfsrestore: session id: 98d1cf99-01ce-43cf-b89f-f76799601af9
/usr/sbin/xfsrestore: media id: 7eca4f15-36f2-4e8a-b00b-2728beaff2a9
/usr/sbin/xfsrestore: using online session inventory
/usr/sbin/xfsrestore: searching media for directory dump
/usr/sbin/xfsrestore: reading directories
/usr/sbin/xfsrestore: 132 directories and 340 entries processed
/usr/sbin/xfsrestore: directory post-processing
/usr/sbin/xfsrestore: restoring non-directory files
/usr/sbin/xfsrestore: restore complete: 0 seconds elapsed
/usr/sbin/xfsrestore: Restore Summary:
/usr/sbin/xfsrestore:   stream 0 /tmp/osd01.ceph-0.xfsdump_20160902155905 OK (success)
/usr/sbin/xfsrestore: Restore Status: SUCCESS
[ osd01 ]: rm osd01.ceph-0.xfsdump_20160902155905
[ osd01 ]: mv back the journal symbolic and journal_uuid file.
[ osd01 ]: scp ./ceph_backup/osd01.ceph-0.journal_20160902155905.tar.gz to /tmp/ on osd01
osd01.ceph-0.journal_20160902155905.tar.gz                                                                                                                  100%  116MB 116.2MB/s   00:01    
[ osd01 ]: untar osd01.ceph-0.journal_20160902155905.tar.gz on osd01
tmp/osd01.ceph-0.journal_20160902155905
[ osd01 ]: dd /tmp/osd01.ceph-0.journal_20160902155905 to /var/lib/ceph/osd/ceph-0/journal
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.108244 s, 1.2 GB/s
[ osd01 ]: rm /tmp/osd01.ceph-0.journal_20160902155905 on osd01
[ osd01 ]: rm /tmp/osd01.ceph-0.journal_20160902155905.tar.gz on osd01


[ osd02 ]: scp ./ceph_backup/osd02_20160902155905.tar.gz to /tmp/osd02_20160902155905.tar.gz on osd osd02
osd02_20160902155905.tar.gz                                                                                                                                 100%  912     0.9KB/s   00:00    
[ osd02 ]: untar /tmp/osd02_20160902155905.tar.gz on osd02
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/tmp/ceph-disk.activate.lock
var/lib/ceph/tmp/ceph-disk.prepare.lock
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
etc/ceph/tmpbd9wHP
[ osd02 ]: rm /tmp/osd02_20160902155905.tar.gz on osd02
[ osd02 ]: get sub-dirname in /var/lib/ceph/osd
ceph-1
[ osd02 ]: copy the journal symbolic and journal_uuid file.
[ osd02 ]: rm all osd data in /var/lib/ceph/osd/ceph-1
[ osd02 ]: scp osd02.ceph-1.xfsdump_20160902155905 file to /tmp/
osd02.ceph-1.xfsdump_20160902155905                                                                                                                         100%   70MB  70.2MB/s   00:00    
[ osd02 ]: xfsrestore /var/lib/ceph/osd/ceph-1
/usr/sbin/xfsrestore: using file dump (drive_simple) strategy
/usr/sbin/xfsrestore: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsrestore: searching media for dump
/usr/sbin/xfsrestore: examining media file 0
/usr/sbin/xfsrestore: dump description: 
/usr/sbin/xfsrestore: hostname: osd02
/usr/sbin/xfsrestore: mount point: /var/lib/ceph/osd/ceph-1
/usr/sbin/xfsrestore: volume: /dev/vdb1
/usr/sbin/xfsrestore: session time: Fri Sep  2 15:59:39 2016
/usr/sbin/xfsrestore: level: 0
/usr/sbin/xfsrestore: session label: "ceph-1"
/usr/sbin/xfsrestore: media label: "/tmp/"
/usr/sbin/xfsrestore: file system id: 930b7455-4533-4ad8-ad78-f8023411415e
/usr/sbin/xfsrestore: session id: c7e89214-619c-46b7-98a7-e4cc233429a2
/usr/sbin/xfsrestore: media id: 6efe3151-24b0-42b1-8e7e-85bee760a1cb
/usr/sbin/xfsrestore: using online session inventory
/usr/sbin/xfsrestore: searching media for directory dump
/usr/sbin/xfsrestore: reading directories
/usr/sbin/xfsrestore: 132 directories and 336 entries processed
/usr/sbin/xfsrestore: directory post-processing
/usr/sbin/xfsrestore: restoring non-directory files
/usr/sbin/xfsrestore: restore complete: 0 seconds elapsed
/usr/sbin/xfsrestore: Restore Summary:
/usr/sbin/xfsrestore:   stream 0 /tmp/osd02.ceph-1.xfsdump_20160902155905 OK (success)
/usr/sbin/xfsrestore: Restore Status: SUCCESS
[ osd02 ]: rm osd02.ceph-1.xfsdump_20160902155905
[ osd02 ]: mv back the journal symbolic and journal_uuid file.
[ osd02 ]: scp ./ceph_backup/osd02.ceph-1.journal_20160902155905.tar.gz to /tmp/ on osd02
osd02.ceph-1.journal_20160902155905.tar.gz                                                                                                                  100%  116MB 116.1MB/s   00:01    
[ osd02 ]: untar osd02.ceph-1.journal_20160902155905.tar.gz on osd02
tmp/osd02.ceph-1.journal_20160902155905
[ osd02 ]: dd /tmp/osd02.ceph-1.journal_20160902155905 to /var/lib/ceph/osd/ceph-1/journal
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.11366 s, 1.2 GB/s
[ osd02 ]: rm /tmp/osd02.ceph-1.journal_20160902155905 on osd02
[ osd02 ]: rm /tmp/osd02.ceph-1.journal_20160902155905.tar.gz on osd02


[ osd03 ]: scp ./ceph_backup/osd03_20160902155905.tar.gz to /tmp/osd03_20160902155905.tar.gz on osd osd03
osd03_20160902155905.tar.gz                                                                                                                                 100%  913     0.9KB/s   00:00    
[ osd03 ]: untar /tmp/osd03_20160902155905.tar.gz on osd03
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/tmp/ceph-disk.activate.lock
var/lib/ceph/tmp/ceph-disk.prepare.lock
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpxTDfWv
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ osd03 ]: rm /tmp/osd03_20160902155905.tar.gz on osd03
[ osd03 ]: get sub-dirname in /var/lib/ceph/osd
ceph-2
[ osd03 ]: copy the journal symbolic and journal_uuid file.
[ osd03 ]: rm all osd data in /var/lib/ceph/osd/ceph-2
[ osd03 ]: scp osd03.ceph-2.xfsdump_20160902155905 file to /tmp/
osd03.ceph-2.xfsdump_20160902155905                                                                                                                         100%   70MB  69.9MB/s   00:00    
[ osd03 ]: xfsrestore /var/lib/ceph/osd/ceph-2
/usr/sbin/xfsrestore: using file dump (drive_simple) strategy
/usr/sbin/xfsrestore: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsrestore: searching media for dump
/usr/sbin/xfsrestore: examining media file 0
/usr/sbin/xfsrestore: dump description: 
/usr/sbin/xfsrestore: hostname: osd03
/usr/sbin/xfsrestore: mount point: /var/lib/ceph/osd/ceph-2
/usr/sbin/xfsrestore: volume: /dev/vdb1
/usr/sbin/xfsrestore: session time: Fri Sep  2 15:59:50 2016
/usr/sbin/xfsrestore: level: 0
/usr/sbin/xfsrestore: session label: "ceph-2"
/usr/sbin/xfsrestore: media label: "/tmp/"
/usr/sbin/xfsrestore: file system id: 3a04a02a-099a-4a12-b597-7636e0ff61ec
/usr/sbin/xfsrestore: session id: 30d95715-4164-48bb-ba4b-08380901f1f8
/usr/sbin/xfsrestore: media id: 5ff29b33-fea8-4c7b-9ae2-2388c7e15e37
/usr/sbin/xfsrestore: using online session inventory
/usr/sbin/xfsrestore: searching media for directory dump
/usr/sbin/xfsrestore: reading directories
/usr/sbin/xfsrestore: 132 directories and 337 entries processed
/usr/sbin/xfsrestore: directory post-processing
/usr/sbin/xfsrestore: restoring non-directory files
/usr/sbin/xfsrestore: restore complete: 0 seconds elapsed
/usr/sbin/xfsrestore: Restore Summary:
/usr/sbin/xfsrestore:   stream 0 /tmp/osd03.ceph-2.xfsdump_20160902155905 OK (success)
/usr/sbin/xfsrestore: Restore Status: SUCCESS
[ osd03 ]: rm osd03.ceph-2.xfsdump_20160902155905
[ osd03 ]: mv back the journal symbolic and journal_uuid file.
[ osd03 ]: scp ./ceph_backup/osd03.ceph-2.journal_20160902155905.tar.gz to /tmp/ on osd03
osd03.ceph-2.journal_20160902155905.tar.gz                                                                                                                  100%  116MB 116.3MB/s   00:00    
[ osd03 ]: untar osd03.ceph-2.journal_20160902155905.tar.gz on osd03
tmp/osd03.ceph-2.journal_20160902155905
[ osd03 ]: dd /tmp/osd03.ceph-2.journal_20160902155905 to /var/lib/ceph/osd/ceph-2/journal
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.123865 s, 1.1 GB/s
[ osd03 ]: rm /tmp/osd03.ceph-2.journal_20160902155905 on osd03
[ osd03 ]: rm /tmp/osd03.ceph-2.journal_20160902155905.tar.gz on osd03




# 完成還原後，啟動所有 Ceph daemon，檢查 Ceph 與 rbd 狀態, ceph 使用空間。rbd0 成功回復，空間使用 309MB
root@admin:~/backup_restore_ceph# ../ceph_tool/ceph_start.sh all
ceph-mon (ceph/mon01) start/running, process 5447
ceph-mon (ceph/mon02) start/running, process 5450
ceph-mon (ceph/mon03) start/running, process 5479
ceph-osd (ceph/0) start/running, process 10484
ceph-osd (ceph/1) start/running, process 10524
ceph-osd (ceph/2) start/running, process 10551


root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_WARN
            64 pgs stale
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 34, quorum 0,1,2 mon01,mon02,mon03
     osdmap e50: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v334: 64 pgs, 1 pools, 84573 kB data, 26 objects
            312 MB used, 23846 MB / 24158 MB avail
                  64 stale+active+clean       
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23849M         309M          1.28 
POOLS:
    NAME     ID     USED       %USED     MAX AVAIL     OBJECTS 
    rbd      0      84573k      1.03         7949M          26 
root@admin:~/backup_restore_ceph# rbd ls -l
NAME SIZE PARENT FMT PROT LOCK 
rbd0 128M          2    


# 再掛載 rbd0，diff 比較其 file 檔與 /tmp 的複製，檔案內容沒有改變
root@admin:~/backup_restore_ceph# rbd map rbd0
/dev/rbd0
root@admin:~/backup_restore_ceph# mount /dev/rbd0 /mnt
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  2.8G  4.2G  40% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  396K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M   66M   46M  60% /mnt
root@admin:~/backup_restore_ceph# diff /mnt/file /tmp/file


# 建立 rbd1, 256MB, 格式化後並掛載。
root@admin:~/backup_restore_ceph# rbd create -s 256 rbd1
root@admin:~/backup_restore_ceph# rbd map rbd1
/dev/rbd1
root@admin:~/backup_restore_ceph# mkfs.ext4 /dev/rbd1
mke2fs 1.42.9 (4-Feb-2014)
Discarding device blocks: done                            
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=4096 blocks, Stripe width=4096 blocks
65536 inodes, 262144 blocks
13107 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=67371008
32 block groups
8192 blocks per group, 8192 fragments per group
2048 inodes per group
Superblock backups stored on blocks: 
	8193, 24577, 40961, 57345, 73729, 204801, 221185


Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done 


root@admin:~/backup_restore_ceph# mount /dev/rbd1 /mnt2
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  2.8G  4.2G  40% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  400K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M   66M   46M  60% /mnt
/dev/rbd1       240M  2.1M  222M   1% /mnt2


# 複製 /tmp/file 至 /mnt2 (rbd1), 並再 dd 寫入 128MB 亂數資料檔 (file2) 至 mnt2 中。
root@admin:~/backup_restore_ceph# cp /tmp/file /mnt2/
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  2.8G  4.2G  40% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  400K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M   66M   46M  60% /mnt
/dev/rbd1       240M   67M  158M  30% /mnt2
root@admin:~/backup_restore_ceph# dd if=/dev/urandom of=/mnt2/file2 bs=1M count=128
128+0 records in
128+0 records out
134217728 bytes (134 MB) copied, 4.50023 s, 29.8 MB/s


# Ceph 的 RAW USED 使用達到 1470MB , 但實際佔用空間應只有約 (66MB + 195MB)*3 + 100MB = 883 MB
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  2.8G  4.2G  40% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  400K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M   66M   46M  60% /mnt
/dev/rbd1       240M  195M   30M  87% /mnt2
root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 34, quorum 0,1,2 mon01,mon02,mon03
     osdmap e50: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v396: 64 pgs, 1 pools, 301 MB data, 86 objects
            1470 MB used, 22688 MB / 24158 MB avail
                  64 active+clean
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     22688M        1470M          6.09 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0      301M      3.74         7560M          86 
root@admin:~/backup_restore_ceph# rbd ls -l
NAME SIZE PARENT FMT PROT LOCK 
rbd0 128M          2           
rbd1 256M          2 


# 卸載和 unmap rbd0 和 rbd1 後, RAW USED 空間降至 912 MB, 大小接近之前計算的的 883 MB
root@admin:~/backup_restore_ceph# umount /mnt/
root@admin:~/backup_restore_ceph# umount /mnt2
root@admin:~/backup_restore_ceph# rbd unmap rbd0
root@admin:~/backup_restore_ceph# rbd unmap rbd1
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23246M         912M          3.78 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0      301M      3.74         7748M          86


# 進行第2次備份，此次備份資料含有 rbd0 及 rbd1 ，佔用空間 912 MB
root@admin:~/backup_restore_ceph# ./backup_ceph_monitor.sh start; ./backup_ceph_osd.sh start


[ mon01 ]: status ceph-mon daemon id=mon01
ceph-mon (ceph/mon01) start/running, process 5447
[ mon02 ]: status ceph-mon daemon id=mon02
ceph-mon (ceph/mon02) start/running, process 5450
[ mon03 ]: status ceph-mon daemon id=mon03
ceph-mon (ceph/mon03) start/running, process 5479
[ mon01 ]: stop ceph-mon daemon id=mon01
ceph-mon stop/waiting
[ mon02 ]: stop ceph-mon daemon id=mon02
ceph-mon stop/waiting
[ mon03 ]: stop ceph-mon daemon id=mon03
ceph-mon stop/waiting


[ mon01 ]: tar /var/lib/ceph and /etc/ceph to /tmp/mon01_20160902165230.tar.gz
/bin/tar: Removing leading `/' from member names
[ mon01 ]: scp mon01:/tmp/mon01_20160902165230.tar.gz to local dir ./ceph_backup/
mon01_20160902165230.tar.gz                                                                                                                                 100%  466KB 466.1KB/s   00:00    
[ mon01 ]: rm the /tmp/mon01_20160902165230.tar.gz on mon01


[ mon02 ]: tar /var/lib/ceph and /etc/ceph to /tmp/mon02_20160902165230.tar.gz
/bin/tar: Removing leading `/' from member names
[ mon02 ]: scp mon02:/tmp/mon02_20160902165230.tar.gz to local dir ./ceph_backup/
mon02_20160902165230.tar.gz                                                                                                                                 100%  501KB 501.4KB/s   00:00    
[ mon02 ]: rm the /tmp/mon02_20160902165230.tar.gz on mon02


[ mon03 ]: tar /var/lib/ceph and /etc/ceph to /tmp/mon03_20160902165230.tar.gz
/bin/tar: Removing leading `/' from member names
[ mon03 ]: scp mon03:/tmp/mon03_20160902165230.tar.gz to local dir ./ceph_backup/
mon03_20160902165230.tar.gz                                                                                                                                 100%  501KB 501.4KB/s   00:00    
[ mon03 ]: rm the /tmp/mon03_20160902165230.tar.gz on mon03


[ mon01 ]: start ceph-mon daemon id=mon01
ceph-mon (ceph/mon01) start/running, process 5894
[ mon02 ]: start ceph-mon daemon id=mon02
ceph-mon (ceph/mon02) start/running, process 5897
[ mon03 ]: start ceph-mon daemon id=mon03
ceph-mon (ceph/mon03) start/running, process 5934


Backuped monitor data to tar file in ./ceph_backup/
-------------------------------------------------------------------------
-rw-r--r-- 1 root root    477243 Sep  2 16:52 mon01_20160902165230.tar.gz
-rw-r--r-- 1 root root    513398 Sep  2 16:52 mon02_20160902165230.tar.gz
-rw-r--r-- 1 root root    513469 Sep  2 16:52 mon03_20160902165230.tar.gz




[ osd01 ]: status ceph-osd daemon id=0
ceph-osd (ceph/0) start/running, process 10484
[ osd02 ]: status ceph-osd daemon id=1
ceph-osd (ceph/1) start/running, process 10524
[ osd03 ]: status ceph-osd daemon id=2
ceph-osd (ceph/2) start/running, process 10551
[ osd01 ]: stop ceph-osd daemon id=0
ceph-osd stop/waiting
[ osd02 ]: stop ceph-osd daemon id=1
ceph-osd stop/waiting
[ osd03 ]: stop ceph-osd daemon id=2
ceph-osd stop/waiting


[ osd01 ]: tar /var/lib/ceph /etc/ceph to /tmp/osd01_20160902165240.tar.gz (exclude /var/lib/ceph/osd/ceph-*)
/bin/tar: Removing leading `/' from member names
[ osd01 ]: scp osd01:/tmp/osd01_20160902165240.tar.gz to local dir ./ceph_backup/
osd01_20160902165240.tar.gz                                                                                                                                 100%  910     0.9KB/s   00:00    
[ osd01 ]: rm /tmp/osd01_20160902165240.tar.gz on osd01
[ osd01 ]: get sub-dirname in /var/lib/ceph/osd
ceph-0
[ osd01 ]: dd /var/lib/ceph/osd/ceph-0/journal to /tmp/osd01.ceph-0.journal_20160902165240
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.0982304 s, 1.4 GB/s
[ osd01 ]: tar journal dump file to /tmp/osd01.ceph-0.journal_20160902165240.tar
/bin/tar: Removing leading `/' from member names
[ osd01 ]: scp osd01:/tmp/osd01.ceph-0.journal_20160902165240.tar to ./ceph_backup/
osd01.ceph-0.journal_20160902165240.tar.gz                                                                                                                  100%  127MB 126.5MB/s   00:01    
[ osd01 ]: rm /tmp/osd01.ceph-0.journal_20160902165240 and /tmp/osd01.ceph-0.journal_20160902165240.tar.gz on osd01
[ osd01 ]: xfsdump /var/lib/ceph/osd/ceph-0 to /tmp/osd01.ceph-0.xfsdump_20160902165240
/usr/sbin/xfsdump: using file dump (drive_simple) strategy
/usr/sbin/xfsdump: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsdump: level 0 dump of osd01:/var/lib/ceph/osd/ceph-0
/usr/sbin/xfsdump: dump date: Fri Sep  2 16:52:59 2016
/usr/sbin/xfsdump: session id: 3bcf2d7b-2093-4925-8eaf-c9da03a8ca60
/usr/sbin/xfsdump: session label: "ceph-0"
/usr/sbin/xfsdump: ino map phase 1: constructing initial dump list
/usr/sbin/xfsdump: ino map phase 2: skipping (no pruning necessary)
/usr/sbin/xfsdump: ino map phase 3: skipping (only one dump stream)
/usr/sbin/xfsdump: ino map construction complete
/usr/sbin/xfsdump: estimated dump size: 283691904 bytes
/usr/sbin/xfsdump: creating dump session media file 0 (media 0, file 0)
/usr/sbin/xfsdump: dumping ino map
/usr/sbin/xfsdump: dumping directories
/usr/sbin/xfsdump: dumping non-directory files
/usr/sbin/xfsdump: ending media file
/usr/sbin/xfsdump: media file size 283821032 bytes
/usr/sbin/xfsdump: dump size (non-dir files) : 283496344 bytes
/usr/sbin/xfsdump: dump complete: 2 seconds elapsed
/usr/sbin/xfsdump: Dump Summary:
/usr/sbin/xfsdump:   stream 0 /tmp/osd01.ceph-0.xfsdump_20160902165240 OK (success)
/usr/sbin/xfsdump: Dump Status: SUCCESS
[ osd01 ]: scp osd01:/tmp/osd01.ceph-0.xfsdump_20160902165240 to ./ceph_backup/
osd01.ceph-0.xfsdump_20160902165240                                                                                                                         100%  271MB 270.7MB/s   00:01    
[ osd01 ]: rm /tmp/osd01.ceph-0.xfsdump_20160902165240 on osd01


[ osd02 ]: tar /var/lib/ceph /etc/ceph to /tmp/osd02_20160902165240.tar.gz (exclude /var/lib/ceph/osd/ceph-*)
/bin/tar: Removing leading `/' from member names
[ osd02 ]: scp osd02:/tmp/osd02_20160902165240.tar.gz to local dir ./ceph_backup/
osd02_20160902165240.tar.gz                                                                                                                                 100%  912     0.9KB/s   00:00    
[ osd02 ]: rm /tmp/osd02_20160902165240.tar.gz on osd02
[ osd02 ]: get sub-dirname in /var/lib/ceph/osd
ceph-1
[ osd02 ]: dd /var/lib/ceph/osd/ceph-1/journal to /tmp/osd02.ceph-1.journal_20160902165240
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.0994037 s, 1.4 GB/s
[ osd02 ]: tar journal dump file to /tmp/osd02.ceph-1.journal_20160902165240.tar
/bin/tar: Removing leading `/' from member names
[ osd02 ]: scp osd02:/tmp/osd02.ceph-1.journal_20160902165240.tar to ./ceph_backup/
osd02.ceph-1.journal_20160902165240.tar.gz                                                                                                                  100%  125MB  31.4MB/s   00:04    
[ osd02 ]: rm /tmp/osd02.ceph-1.journal_20160902165240 and /tmp/osd02.ceph-1.journal_20160902165240.tar.gz on osd02
[ osd02 ]: xfsdump /var/lib/ceph/osd/ceph-1 to /tmp/osd02.ceph-1.xfsdump_20160902165240
/usr/sbin/xfsdump: using file dump (drive_simple) strategy
/usr/sbin/xfsdump: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsdump: level 0 dump of osd02:/var/lib/ceph/osd/ceph-1
/usr/sbin/xfsdump: dump date: Fri Sep  2 16:53:12 2016
/usr/sbin/xfsdump: session id: 8b40b292-4239-4944-932e-026a37b90b1a
/usr/sbin/xfsdump: session label: "ceph-1"
/usr/sbin/xfsdump: ino map phase 1: constructing initial dump list
/usr/sbin/xfsdump: ino map phase 2: skipping (no pruning necessary)
/usr/sbin/xfsdump: ino map phase 3: skipping (only one dump stream)
/usr/sbin/xfsdump: ino map construction complete
/usr/sbin/xfsdump: estimated dump size: 284035968 bytes
/usr/sbin/xfsdump: creating dump session media file 0 (media 0, file 0)
/usr/sbin/xfsdump: dumping ino map
/usr/sbin/xfsdump: dumping directories
/usr/sbin/xfsdump: dumping non-directory files
/usr/sbin/xfsdump: ending media file
/usr/sbin/xfsdump: media file size 284153928 bytes
/usr/sbin/xfsdump: dump size (non-dir files) : 283829256 bytes
/usr/sbin/xfsdump: dump complete: 0 seconds elapsed
/usr/sbin/xfsdump: Dump Summary:
/usr/sbin/xfsdump:   stream 0 /tmp/osd02.ceph-1.xfsdump_20160902165240 OK (success)
/usr/sbin/xfsdump: Dump Status: SUCCESS
[ osd02 ]: scp osd02:/tmp/osd02.ceph-1.xfsdump_20160902165240 to ./ceph_backup/
osd02.ceph-1.xfsdump_20160902165240                                                                                                                         100%  271MB 271.0MB/s   00:01    
[ osd02 ]: rm /tmp/osd02.ceph-1.xfsdump_20160902165240 on osd02


[ osd03 ]: tar /var/lib/ceph /etc/ceph to /tmp/osd03_20160902165240.tar.gz (exclude /var/lib/ceph/osd/ceph-*)
/bin/tar: Removing leading `/' from member names
[ osd03 ]: scp osd03:/tmp/osd03_20160902165240.tar.gz to local dir ./ceph_backup/
osd03_20160902165240.tar.gz                                                                                                                                 100%  913     0.9KB/s   00:00    
[ osd03 ]: rm /tmp/osd03_20160902165240.tar.gz on osd03
[ osd03 ]: get sub-dirname in /var/lib/ceph/osd
ceph-2
[ osd03 ]: dd /var/lib/ceph/osd/ceph-2/journal to /tmp/osd03.ceph-2.journal_20160902165240
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.109019 s, 1.2 GB/s
[ osd03 ]: tar journal dump file to /tmp/osd03.ceph-2.journal_20160902165240.tar
/bin/tar: Removing leading `/' from member names
[ osd03 ]: scp osd03:/tmp/osd03.ceph-2.journal_20160902165240.tar to ./ceph_backup/
osd03.ceph-2.journal_20160902165240.tar.gz                                                                                                                  100%  124MB  41.5MB/s   00:03    
[ osd03 ]: rm /tmp/osd03.ceph-2.journal_20160902165240 and /tmp/osd03.ceph-2.journal_20160902165240.tar.gz on osd03
[ osd03 ]: xfsdump /var/lib/ceph/osd/ceph-2 to /tmp/osd03.ceph-2.xfsdump_20160902165240
/usr/sbin/xfsdump: using file dump (drive_simple) strategy
/usr/sbin/xfsdump: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsdump: level 0 dump of osd03:/var/lib/ceph/osd/ceph-2
/usr/sbin/xfsdump: dump date: Fri Sep  2 16:53:24 2016
/usr/sbin/xfsdump: session id: 68d58d8e-b5b8-42b9-88f3-77703afcc464
/usr/sbin/xfsdump: session label: "ceph-2"
/usr/sbin/xfsdump: ino map phase 1: constructing initial dump list
/usr/sbin/xfsdump: ino map phase 2: skipping (no pruning necessary)
/usr/sbin/xfsdump: ino map phase 3: skipping (only one dump stream)
/usr/sbin/xfsdump: ino map construction complete
/usr/sbin/xfsdump: estimated dump size: 284115072 bytes
/usr/sbin/xfsdump: creating dump session media file 0 (media 0, file 0)
/usr/sbin/xfsdump: dumping ino map
/usr/sbin/xfsdump: dumping directories
/usr/sbin/xfsdump: dumping non-directory files
/usr/sbin/xfsdump: ending media file
/usr/sbin/xfsdump: media file size 284215368 bytes
/usr/sbin/xfsdump: dump size (non-dir files) : 283888088 bytes
/usr/sbin/xfsdump: dump complete: 0 seconds elapsed
/usr/sbin/xfsdump: Dump Summary:
/usr/sbin/xfsdump:   stream 0 /tmp/osd03.ceph-2.xfsdump_20160902165240 OK (success)
/usr/sbin/xfsdump: Dump Status: SUCCESS
[ osd03 ]: scp osd03:/tmp/osd03.ceph-2.xfsdump_20160902165240 to ./ceph_backup/
osd03.ceph-2.xfsdump_20160902165240                                                                                                                         100%  271MB 135.5MB/s   00:02    
[ osd03 ]: rm /tmp/osd03.ceph-2.xfsdump_20160902165240 on osd03


[ osd01 ]: start ceph-osd daemon id=0
ceph-osd (ceph/0) start/running, process 11612
[ osd02 ]: start ceph-osd daemon id=1
ceph-osd (ceph/1) start/running, process 11668
[ osd03 ]: start ceph-osd daemon id=2
ceph-osd (ceph/2) start/running, process 11692
Backuped OSD data to tar file in "./ceph_backup/"
-------------------------------------------------------------------------
-rw-r--r-- 1 root root 132689343 Sep  2 16:52 osd01.ceph-0.journal_20160902165240.tar.gz
-rw-r--r-- 1 root root 283821032 Sep  2 16:53 osd01.ceph-0.xfsdump_20160902165240
-rw-r--r-- 1 root root       910 Sep  2 16:52 osd01_20160902165240.tar.gz
-rw-r--r-- 1 root root 131476552 Sep  2 16:53 osd02.ceph-1.journal_20160902165240.tar.gz
-rw-r--r-- 1 root root 284153928 Sep  2 16:53 osd02.ceph-1.xfsdump_20160902165240
-rw-r--r-- 1 root root       912 Sep  2 16:53 osd02_20160902165240.tar.gz
-rw-r--r-- 1 root root 130535655 Sep  2 16:53 osd03.ceph-2.journal_20160902165240.tar.gz
-rw-r--r-- 1 root root 284215368 Sep  2 16:53 osd03.ceph-2.xfsdump_20160902165240
-rw-r--r-- 1 root root       913 Sep  2 16:53 osd03_20160902165240.tar.gz


# 完成備份後，再檢查 ceph 服務狀態
root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 38, quorum 0,1,2 mon01,mon02,mon03
     osdmap e61: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v430: 64 pgs, 1 pools, 301 MB data, 86 objects
            912 MB used, 23246 MB / 24158 MB avail
                  64 active+clean
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23246M         912M          3.77 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0      301M      3.74         7748M          86 
root@admin:~/backup_restore_ceph# rbd ls -l
NAME SIZE PARENT FMT PROT LOCK 
rbd0 128M          2           
rbd1 256M          2 


# 目前有 monitor 及 osd 各有兩個備份。
一份是有 rbd0 (128MB) 的備份()，另一份有 rbd0 (128MB) 及 rbd1 (256MB)。
root@admin:~/backup_restore_ceph# ./list_ceph_backup.sh 


Time point         Node Name
---------------------------------------------------------------------------
20160902155856     mon01 mon02 mon03
20160902155905     osd01 osd02 osd03
20160902165230     mon01 mon02 mon03
20160902165240     osd01 osd02 osd03




# 在相同的設備環境上重新再佈署 Ceph Cluster。完成部屬後，其 fsid 為719997ba-0010-4f87-8df9-f4c751af7172，無 rbd image，RAW USED 為 100MB
root@admin:~# ceph -s
    cluster 719997ba-0010-4f87-8df9-f4c751af7172
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 6, quorum 0,1,2 mon01,mon02,mon03
     osdmap e14: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v45: 64 pgs, 1 pools, 0 bytes data, 0 objects
            100 MB used, 24058 MB / 24158 MB avail
                  64 active+clean
root@admin:~# rbd ls -l
root@admin:~# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     24058M         100M          0.42 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0         0         0         8019M           0


# 進行還原至前 cluster 環境與狀態，含有 rbd0 及 rbd1 的 RBD image 資料。
root@admin:~/backup_restore_ceph# ./list_ceph_backup.sh 


Time point         Node Name
---------------------------------------------------------------------------
20160902155856     mon01 mon02 mon03
20160902155905     osd01 osd02 osd03
20160902165230     mon01 mon02 mon03
20160902165240     osd01 osd02 osd03


root@admin:~/backup_restore_ceph# ./restore_ceph_monitor.sh 20160902165230; ./restore_ceph_osd.sh 20160902165240


Restore monitor from time point "20160902165230"


[ mon01 ]: status ceph-mon daemon id=mon01
ceph-mon (ceph/mon01) start/running, process 10117
[ mon02 ]: status ceph-mon daemon id=mon02
ceph-mon (ceph/mon02) start/running, process 10121
[ mon03 ]: status ceph-mon daemon id=mon03
ceph-mon (ceph/mon03) start/running, process 10156
[ mon01 ]: stop ceph-mon daemon id=mon01
ceph-mon stop/waiting
[ mon02 ]: stop ceph-mon daemon id=mon02
ceph-mon stop/waiting
[ mon03 ]: stop ceph-mon daemon id=mon03
ceph-mon stop/waiting


[ mon01 ]: scp ./ceph_backup/mon01_20160902165230.tar.gz to /tmp/ on monitor mon01
mon01_20160902165230.tar.gz                                                                                                                                 100%  466KB 466.1KB/s   00:00    
[ mon01 ]: rm /var/lib/ceph /etc/ceph 
[ mon01 ]: untar /tmp/mon01_20160902165230.tar.gz on mon01
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-mds/ceph.keyring
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/bootstrap-rgw/ceph.keyring
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mon/ceph-mon01/
var/lib/ceph/mon/ceph-mon01/keyring
var/lib/ceph/mon/ceph-mon01/done
var/lib/ceph/mon/ceph-mon01/upstart
var/lib/ceph/mon/ceph-mon01/store.db/
var/lib/ceph/mon/ceph-mon01/store.db/MANIFEST-000043
var/lib/ceph/mon/ceph-mon01/store.db/CURRENT
var/lib/ceph/mon/ceph-mon01/store.db/000041.ldb
var/lib/ceph/mon/ceph-mon01/store.db/LOCK
var/lib/ceph/mon/ceph-mon01/store.db/000039.ldb
var/lib/ceph/mon/ceph-mon01/store.db/000045.log
var/lib/ceph/mon/ceph-mon01/store.db/000040.ldb
var/lib/ceph/mon/ceph-mon01/store.db/000038.ldb
var/lib/ceph/mon/ceph-mon01/store.db/000042.ldb
var/lib/ceph/mon/ceph-mon01/store.db/000044.ldb
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpZVg4fa
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ mon01 ]: rm /tmp/mon01_20160902165230.tar.gz on mon01


[ mon02 ]: scp ./ceph_backup/mon02_20160902165230.tar.gz to /tmp/ on monitor mon02
mon02_20160902165230.tar.gz                                                                                                                                 100%  501KB 501.4KB/s   00:00    
[ mon02 ]: rm /var/lib/ceph /etc/ceph 
[ mon02 ]: untar /tmp/mon02_20160902165230.tar.gz on mon02
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-mds/ceph.keyring
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/bootstrap-rgw/ceph.keyring
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mon/ceph-mon02/
var/lib/ceph/mon/ceph-mon02/keyring
var/lib/ceph/mon/ceph-mon02/done
var/lib/ceph/mon/ceph-mon02/upstart
var/lib/ceph/mon/ceph-mon02/store.db/
var/lib/ceph/mon/ceph-mon02/store.db/MANIFEST-000043
var/lib/ceph/mon/ceph-mon02/store.db/CURRENT
var/lib/ceph/mon/ceph-mon02/store.db/000041.ldb
var/lib/ceph/mon/ceph-mon02/store.db/LOCK
var/lib/ceph/mon/ceph-mon02/store.db/000039.ldb
var/lib/ceph/mon/ceph-mon02/store.db/000045.log
var/lib/ceph/mon/ceph-mon02/store.db/000040.ldb
var/lib/ceph/mon/ceph-mon02/store.db/000038.ldb
var/lib/ceph/mon/ceph-mon02/store.db/000042.ldb
var/lib/ceph/mon/ceph-mon02/store.db/000044.ldb
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
etc/ceph/tmp3vemGY
[ mon02 ]: rm /tmp/mon02_20160902165230.tar.gz on mon02


[ mon03 ]: scp ./ceph_backup/mon03_20160902165230.tar.gz to /tmp/ on monitor mon03
mon03_20160902165230.tar.gz                                                                                                                                 100%  501KB 501.4KB/s   00:00    
[ mon03 ]: rm /var/lib/ceph /etc/ceph 
[ mon03 ]: untar /tmp/mon03_20160902165230.tar.gz on mon03
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-mds/ceph.keyring
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/bootstrap-rgw/ceph.keyring
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mon/ceph-mon03/
var/lib/ceph/mon/ceph-mon03/keyring
var/lib/ceph/mon/ceph-mon03/done
var/lib/ceph/mon/ceph-mon03/upstart
var/lib/ceph/mon/ceph-mon03/store.db/
var/lib/ceph/mon/ceph-mon03/store.db/MANIFEST-000043
var/lib/ceph/mon/ceph-mon03/store.db/CURRENT
var/lib/ceph/mon/ceph-mon03/store.db/000041.ldb
var/lib/ceph/mon/ceph-mon03/store.db/LOCK
var/lib/ceph/mon/ceph-mon03/store.db/000039.ldb
var/lib/ceph/mon/ceph-mon03/store.db/000045.log
var/lib/ceph/mon/ceph-mon03/store.db/000040.ldb
var/lib/ceph/mon/ceph-mon03/store.db/000038.ldb
var/lib/ceph/mon/ceph-mon03/store.db/000042.ldb
var/lib/ceph/mon/ceph-mon03/store.db/000044.ldb
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpiTL4Dv
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ mon03 ]: rm /tmp/mon03_20160902165230.tar.gz on mon03






Restore osd from time point "20160902165240"


[ osd01 ]: status ceph-osd daemon id=0
ceph-osd (ceph/0) start/running, process 15851
[ osd02 ]: status ceph-osd daemon id=1
ceph-osd (ceph/1) start/running, process 15927
[ osd03 ]: status ceph-osd daemon id=2
ceph-osd (ceph/2) start/running, process 15959
[ osd01 ]: stop ceph-osd daemon id=0
ceph-osd stop/waiting
[ osd02 ]: stop ceph-osd daemon id=1
ceph-osd stop/waiting
[ osd03 ]: stop ceph-osd daemon id=2
ceph-osd stop/waiting


[ osd01 ]: scp ./ceph_backup/osd01_20160902165240.tar.gz to /tmp/osd01_20160902165240.tar.gz on osd osd01
osd01_20160902165240.tar.gz                                                                                                                                 100%  910     0.9KB/s   00:00    
[ osd01 ]: untar /tmp/osd01_20160902165240.tar.gz on osd01
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/tmp/ceph-disk.activate.lock
var/lib/ceph/tmp/ceph-disk.prepare.lock
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpHe3at3
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ osd01 ]: rm /tmp/osd01_20160902165240.tar.gz on osd01
[ osd01 ]: get sub-dirname in /var/lib/ceph/osd
ceph-0
[ osd01 ]: copy the journal symbolic and journal_uuid file.
[ osd01 ]: rm all osd data in /var/lib/ceph/osd/ceph-0
[ osd01 ]: scp osd01.ceph-0.xfsdump_20160902165240 file to /tmp/
osd01.ceph-0.xfsdump_20160902165240                                                                                                                         100%  271MB 270.7MB/s   00:01    
[ osd01 ]: xfsrestore /var/lib/ceph/osd/ceph-0
/usr/sbin/xfsrestore: using file dump (drive_simple) strategy
/usr/sbin/xfsrestore: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsrestore: searching media for dump
/usr/sbin/xfsrestore: examining media file 0
/usr/sbin/xfsrestore: dump description: 
/usr/sbin/xfsrestore: hostname: osd01
/usr/sbin/xfsrestore: mount point: /var/lib/ceph/osd/ceph-0
/usr/sbin/xfsrestore: volume: /dev/vdb1
/usr/sbin/xfsrestore: session time: Fri Sep  2 16:52:59 2016
/usr/sbin/xfsrestore: level: 0
/usr/sbin/xfsrestore: session label: "ceph-0"
/usr/sbin/xfsrestore: media label: "/tmp/"
/usr/sbin/xfsrestore: file system id: 1e016a53-6c82-44f2-8c10-0e4be934f487
/usr/sbin/xfsrestore: session id: 3bcf2d7b-2093-4925-8eaf-c9da03a8ca60
/usr/sbin/xfsrestore: media id: 258b68bb-41f9-44bf-baba-7c2c231646b9
/usr/sbin/xfsrestore: using online session inventory
/usr/sbin/xfsrestore: searching media for directory dump
/usr/sbin/xfsrestore: reading directories
/usr/sbin/xfsrestore: 132 directories and 405 entries processed
/usr/sbin/xfsrestore: directory post-processing
/usr/sbin/xfsrestore: restoring non-directory files
/usr/sbin/xfsrestore: restore complete: 4 seconds elapsed
/usr/sbin/xfsrestore: Restore Summary:
/usr/sbin/xfsrestore:   stream 0 /tmp/osd01.ceph-0.xfsdump_20160902165240 OK (success)
/usr/sbin/xfsrestore: Restore Status: SUCCESS
[ osd01 ]: rm osd01.ceph-0.xfsdump_20160902165240
[ osd01 ]: mv back the journal symbolic and journal_uuid file.
[ osd01 ]: scp ./ceph_backup/osd01.ceph-0.journal_20160902165240.tar.gz to /tmp/ on osd01
osd01.ceph-0.journal_20160902165240.tar.gz                                                                                                                  100%  127MB 126.5MB/s   00:00    
[ osd01 ]: untar osd01.ceph-0.journal_20160902165240.tar.gz on osd01
tmp/osd01.ceph-0.journal_20160902165240
[ osd01 ]: dd /tmp/osd01.ceph-0.journal_20160902165240 to /var/lib/ceph/osd/ceph-0/journal
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.131686 s, 1.0 GB/s
[ osd01 ]: rm /tmp/osd01.ceph-0.journal_20160902165240 on osd01
[ osd01 ]: rm /tmp/osd01.ceph-0.journal_20160902165240.tar.gz on osd01


[ osd02 ]: scp ./ceph_backup/osd02_20160902165240.tar.gz to /tmp/osd02_20160902165240.tar.gz on osd osd02
osd02_20160902165240.tar.gz                                                                                                                                 100%  912     0.9KB/s   00:00    
[ osd02 ]: untar /tmp/osd02_20160902165240.tar.gz on osd02
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/tmp/ceph-disk.activate.lock
var/lib/ceph/tmp/ceph-disk.prepare.lock
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
etc/ceph/tmpbd9wHP
[ osd02 ]: rm /tmp/osd02_20160902165240.tar.gz on osd02
[ osd02 ]: get sub-dirname in /var/lib/ceph/osd
ceph-1
[ osd02 ]: copy the journal symbolic and journal_uuid file.
[ osd02 ]: rm all osd data in /var/lib/ceph/osd/ceph-1
[ osd02 ]: scp osd02.ceph-1.xfsdump_20160902165240 file to /tmp/
osd02.ceph-1.xfsdump_20160902165240                                                                                                                         100%  271MB 271.0MB/s   00:01    
[ osd02 ]: xfsrestore /var/lib/ceph/osd/ceph-1
/usr/sbin/xfsrestore: using file dump (drive_simple) strategy
/usr/sbin/xfsrestore: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsrestore: searching media for dump
/usr/sbin/xfsrestore: examining media file 0
/usr/sbin/xfsrestore: dump description: 
/usr/sbin/xfsrestore: hostname: osd02
/usr/sbin/xfsrestore: mount point: /var/lib/ceph/osd/ceph-1
/usr/sbin/xfsrestore: volume: /dev/vdb1
/usr/sbin/xfsrestore: session time: Fri Sep  2 16:53:12 2016
/usr/sbin/xfsrestore: level: 0
/usr/sbin/xfsrestore: session label: "ceph-1"
/usr/sbin/xfsrestore: media label: "/tmp/"
/usr/sbin/xfsrestore: file system id: 930b7455-4533-4ad8-ad78-f8023411415e
/usr/sbin/xfsrestore: session id: 8b40b292-4239-4944-932e-026a37b90b1a
/usr/sbin/xfsrestore: media id: da645972-4648-45ee-8bc3-9516b561b6aa
/usr/sbin/xfsrestore: using online session inventory
/usr/sbin/xfsrestore: searching media for directory dump
/usr/sbin/xfsrestore: reading directories
/usr/sbin/xfsrestore: 132 directories and 405 entries processed
/usr/sbin/xfsrestore: directory post-processing
/usr/sbin/xfsrestore: restoring non-directory files
/usr/sbin/xfsrestore: restore complete: 3 seconds elapsed
/usr/sbin/xfsrestore: Restore Summary:
/usr/sbin/xfsrestore:   stream 0 /tmp/osd02.ceph-1.xfsdump_20160902165240 OK (success)
/usr/sbin/xfsrestore: Restore Status: SUCCESS
[ osd02 ]: rm osd02.ceph-1.xfsdump_20160902165240
[ osd02 ]: mv back the journal symbolic and journal_uuid file.
[ osd02 ]: scp ./ceph_backup/osd02.ceph-1.journal_20160902165240.tar.gz to /tmp/ on osd02
osd02.ceph-1.journal_20160902165240.tar.gz                                                                                                                  100%  125MB 125.4MB/s   00:00    
[ osd02 ]: untar osd02.ceph-1.journal_20160902165240.tar.gz on osd02
tmp/osd02.ceph-1.journal_20160902165240
[ osd02 ]: dd /tmp/osd02.ceph-1.journal_20160902165240 to /var/lib/ceph/osd/ceph-1/journal
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.135576 s, 990 MB/s
[ osd02 ]: rm /tmp/osd02.ceph-1.journal_20160902165240 on osd02
[ osd02 ]: rm /tmp/osd02.ceph-1.journal_20160902165240.tar.gz on osd02


[ osd03 ]: scp ./ceph_backup/osd03_20160902165240.tar.gz to /tmp/osd03_20160902165240.tar.gz on osd osd03
osd03_20160902165240.tar.gz                                                                                                                                 100%  913     0.9KB/s   00:00    
[ osd03 ]: untar /tmp/osd03_20160902165240.tar.gz on osd03
var/lib/ceph/
var/lib/ceph/tmp/
var/lib/ceph/tmp/ceph-disk.activate.lock
var/lib/ceph/tmp/ceph-disk.prepare.lock
var/lib/ceph/bootstrap-mds/
var/lib/ceph/bootstrap-rgw/
var/lib/ceph/radosgw/
var/lib/ceph/bootstrap-osd/
var/lib/ceph/bootstrap-osd/ceph.keyring
var/lib/ceph/mon/
var/lib/ceph/mds/
var/lib/ceph/osd/
etc/ceph/
etc/ceph/rbdmap
etc/ceph/tmpxTDfWv
etc/ceph/ceph.conf
etc/ceph/ceph.client.admin.keyring
[ osd03 ]: rm /tmp/osd03_20160902165240.tar.gz on osd03
[ osd03 ]: get sub-dirname in /var/lib/ceph/osd
ceph-2
[ osd03 ]: copy the journal symbolic and journal_uuid file.
[ osd03 ]: rm all osd data in /var/lib/ceph/osd/ceph-2
[ osd03 ]: scp osd03.ceph-2.xfsdump_20160902165240 file to /tmp/
osd03.ceph-2.xfsdump_20160902165240                                                                                                                         100%  271MB 271.1MB/s   00:01    
[ osd03 ]: xfsrestore /var/lib/ceph/osd/ceph-2
/usr/sbin/xfsrestore: using file dump (drive_simple) strategy
/usr/sbin/xfsrestore: version 3.1.1 (dump format 3.0)
/usr/sbin/xfsrestore: searching media for dump
/usr/sbin/xfsrestore: examining media file 0
/usr/sbin/xfsrestore: dump description: 
/usr/sbin/xfsrestore: hostname: osd03
/usr/sbin/xfsrestore: mount point: /var/lib/ceph/osd/ceph-2
/usr/sbin/xfsrestore: volume: /dev/vdb1
/usr/sbin/xfsrestore: session time: Fri Sep  2 16:53:24 2016
/usr/sbin/xfsrestore: level: 0
/usr/sbin/xfsrestore: session label: "ceph-2"
/usr/sbin/xfsrestore: media label: "/tmp/"
/usr/sbin/xfsrestore: file system id: 3a04a02a-099a-4a12-b597-7636e0ff61ec
/usr/sbin/xfsrestore: session id: 68d58d8e-b5b8-42b9-88f3-77703afcc464
/usr/sbin/xfsrestore: media id: 7ce88786-491c-46e4-8f63-60a7747af0be
/usr/sbin/xfsrestore: using online session inventory
/usr/sbin/xfsrestore: searching media for directory dump
/usr/sbin/xfsrestore: reading directories
/usr/sbin/xfsrestore: 132 directories and 409 entries processed
/usr/sbin/xfsrestore: directory post-processing
/usr/sbin/xfsrestore: restoring non-directory files
/usr/sbin/xfsrestore: restore complete: 3 seconds elapsed
/usr/sbin/xfsrestore: Restore Summary:
/usr/sbin/xfsrestore:   stream 0 /tmp/osd03.ceph-2.xfsdump_20160902165240 OK (success)
/usr/sbin/xfsrestore: Restore Status: SUCCESS
[ osd03 ]: rm osd03.ceph-2.xfsdump_20160902165240
[ osd03 ]: mv back the journal symbolic and journal_uuid file.
[ osd03 ]: scp ./ceph_backup/osd03.ceph-2.journal_20160902165240.tar.gz to /tmp/ on osd03
osd03.ceph-2.journal_20160902165240.tar.gz                                                                                                                  100%  124MB 124.5MB/s   00:01    
[ osd03 ]: untar osd03.ceph-2.journal_20160902165240.tar.gz on osd03
tmp/osd03.ceph-2.journal_20160902165240
[ osd03 ]: dd /tmp/osd03.ceph-2.journal_20160902165240 to /var/lib/ceph/osd/ceph-2/journal
32768+0 records in
32768+0 records out
134217728 bytes (134 MB) copied, 0.146557 s, 916 MB/s
[ osd03 ]: rm /tmp/osd03.ceph-2.journal_20160902165240 on osd03
[ osd03 ]: rm /tmp/osd03.ceph-2.journal_20160902165240.tar.gz on osd03


# 完成還原後，將 mon01 的 ceph config 及 keyring 複製回 admin node (deploy server)
root@admin:~/backup_restore_ceph# scp -pr mon01:/etc/ceph /etc/
rbdmap                                                                                                                                                      100%   92     0.1KB/s   00:00    
tmpZVg4fa                                                                                                                                                   100%    0     0.0KB/s   00:00    
ceph.conf                                                                                                                                                   100%  420     0.4KB/s   00:00    
ceph.client.admin.keyring                                                                                                                                   100%   63     0.1KB/s   00:00    


# 檢查 ceph 服務狀態與資料。fsid 還原至先前的 72cfef0e-4cb9-41d3-b58d-0770037a62bc ,RBD Image 也成功還原，並可成功掛載與讀寫資料
root@admin:~/backup_restore_ceph# ceph -s
    cluster 72cfef0e-4cb9-41d3-b58d-0770037a62bc
     health HEALTH_OK
     monmap e1: 3 mons at {mon01=192.168.124.101:6789/0,mon02=192.168.124.102:6789/0,mon03=192.168.124.103:6789/0}
            election epoch 38, quorum 0,1,2 mon01,mon02,mon03
     osdmap e57: 3 osds: 3 up, 3 in
            flags sortbitwise
      pgmap v440: 64 pgs, 1 pools, 301 MB data, 86 objects
            912 MB used, 23246 MB / 24158 MB avail
                  64 active+clean
root@admin:~/backup_restore_ceph# rbd ls -l
NAME SIZE PARENT FMT PROT LOCK 
rbd0 128M          2           
rbd1 256M          2           
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23246M         912M          3.78 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0      301M      3.74         7748M          86 
root@admin:~/backup_restore_ceph# mount /dev/rbd0 /mnt
root@admin:~/backup_restore_ceph# mount /dev/rbd1 /mnt2
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  3.9G  3.1G  56% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  404K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M   66M   46M  60% /mnt
/dev/rbd1       240M  195M   30M  87% /mnt2
root@admin:~/backup_restore_ceph# diff /mnt/file /tmp/file 
root@admin:~/backup_restore_ceph# diff /mnt/file /mnt2/file
root@admin:~/backup_restore_ceph# dd if=/dev/urandom of=/mnt2/file3 bs=1M count=32
32+0 records in
32+0 records out
33554432 bytes (34 MB) copied, 1.12549 s, 29.8 MB/s
root@admin:~/backup_restore_ceph# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda1       7.3G  3.9G  3.1G  56% /
none            4.0K     0  4.0K   0% /sys/fs/cgroup
udev            235M  4.0K  235M   1% /dev
tmpfs            49M  404K   49M   1% /run
none            5.0M     0  5.0M   0% /run/lock
none            245M     0  245M   0% /run/shm
none            100M     0  100M   0% /run/user
/dev/rbd0       120M   66M   46M  60% /mnt
/dev/rbd1       240M  227M     0 100% /mnt2
root@admin:~/backup_restore_ceph# ceph df
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED 
    24158M     23156M        1002M          4.15 
POOLS:
    NAME     ID     USED     %USED     MAX AVAIL     OBJECTS 
    rbd      0      323M      4.01         7703M          91 
