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
### test write speed on device (usb hdd) 
```
dd if=/dev/null of=/mnt/ext_usb/test1gb bs=1G count=1 oflag=direct
```
### test write speed on device (usb hdd) 
```
dd if=/mnt/ext_usb/test1gb of=/dev/null bs=1G count=1 iflag=direct
```
### encrypt-string with ansible-vault
```
ansible-vault encrypt_string 'fullStringToEncrypt' --name 'variable_name' --ask-vault-pass
```
### install rsync on esxi
```
wget --no-check-certificate -S -O rsync-on-esxi https://github.com/gmasonPCS/rsync-on-esxi/releases/download/Release/rsync-on-esxi.zip
unzip rsync-on-esxi
ln -s /vmfs/volumes/622d4808-61d34746-1916-1866da7f1485/rsync/rsync-static /bin/rsync
chmod +x /bin/rsync
```
