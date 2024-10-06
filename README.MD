### executes job in background allowing to leave terminal session
```
#!/bin/bash
setsid nohup rsync -avz --progress --partial vmDataStore-HDD/vmbackup prometei-nfs/vmbackup > /var/log/rsync_log.txt 2>&1 &
```
### extend partition on a whole disk
```
yum install cloud-utils-growpart -y
growpart /dev/sdb 1
resize2fs /dev/sdb1
```
