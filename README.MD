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
### manualy setup ipv4 with NewtorkManager
```
nmcli con mode ens192 ipv4.addresses 10.17.9.236/24
nmcli con mod ens192 ipv4.addresses 10.17.9.236/24
nmcli con mod ens192 ipv4.gateway 10.17.9.2
nmcli con mod ens192 ipv4.dns 10.17.9.15
nmcli con mod ens192 ipv4.method manual
nmcli con up ens192
```
### Set-up notification to telegram
```
#!/bin/bash
# Telegram chat notificator

# /omd/sites/prometei/local/share/check_mk/notifications/telegram_notify
BOT_TOKEN="token"  # Replace with your bot token
CHAT_ID="id"  # Replace with your chat ID

# Message content
MESSAGE="$NOTIFY_LONGDATETIME - Checkmk Notification - $NOTIFY_NOTIFICATIONTYPE for $NOTIFY_HOSTNAME: $NOTIFY_SERVICEDESC - $NOTIFY_SERVICEOUTPUT - $NOTIFY_HOSTOUTPUT"

# Send message to Telegram
curl -s -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
    -d chat_id=$CHAT_ID \
    -d text="$MESSAGE" \
    -d parse_mode="HTML"
```

### Run SSL KeyLogging along Chrome
```
SSLKEYLOGFILE=/tmp/tmp-chrome/sslkeys.log /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --user-data-dir=/tmp/tmp-chrome
```
