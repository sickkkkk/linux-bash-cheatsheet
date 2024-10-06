# executes job in background allowing to leave terminal session
```
#!/bin/bash
setsid nohup rsync -avz --progress --partial vmDataStore-HDD/vmbackup prometei-nfs/vmbackup > /var/log/rsync_log.txt 2>&1 &
```
