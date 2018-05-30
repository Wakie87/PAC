#!/bin/bash

#SERVERNAME-Example: Loretta
SERVERNAME=

#SERVERNAMELOWER Example: loretta
SERVERNAMELOWER=

#HOSTNAME Example: loretta.hosting.alqo.org
HOSTNAME=

#SERVERIP Example: 12.34.56.78
SERVERIP=

#SET A INITIAL-CODE HERE
INITIAL="test"

#SET A RPC-USER HERE
RPCUSER=""

#SET A RPC-PASS HERE
RPCPASS=""

STAKING=0
MASTERNODE=0
MASTERNODEPRIVKEY=0


echo ${INITIAL} | sudo -E tee /var/ALQO/_initial >/dev/null 2>&1
chmod -f 777 /var/ALQO/_initial

echo '{
"name": "'"${SERVERNAME}"'",
"ip": "'"${SERVERIP}"'"
}' | sudo -E tee /var/ALQO/_serverinfo >/dev/null 2>&1
chmod -f 777 /var/ALQO/_serverinfo


output() {
    printf "\E[0;33;40m"
    echo $1
    printf "\E[0m"
}

clear

output "##################################"
output "##     ALQO HOSTING SERVICE     ##"
output "##################################"

output "Installing Masternode Packages"
apt-get update
apt-get install -y git screen curl pwgen apache2 php libapache2-mod-php php-mcrypt php-mysql automake build-essential libtool autotools-dev autoconf pkg-config libssl-dev libboost-all-dev software-properties-common
add-apt-repository ppa:bitcoin/bitcoin -y
apt-get update
apt-get install -y libdb4.8-dev libdb4.8++-dev libminiupnpc-dev

output "Setting up ALQO Daemon"
mkdir /var/ALQO && chmod 777 /var/ALQO
mkdir /var/ALQO/data && chmod 777 /var/ALQO/data
mkdir /var/ALQO/services && chmod 777 /var/ALQO/services
mkdir /var/ALQO/services/data && chmod 777 /var/ALQO/services/data
wget https://builds.alqo.org/linux/alqod -O /var/ALQO/alqod && chmod -f 777 /var/ALQO/alqod
wget https://builds.alqo.org/linux/alqo-cli -O /var/ALQO/alqo-cli  && chmod -f 777 /var/ALQO/alqo-cli


output "Configurate ALQO Daemon"
echo '
###############################################
##			'"${SERVERNAME}"'
###############################################
rpcuser='"${RPCUSER}"'
rpcpassword='"${RPCPASS}"'
rpcallowip=127.0.0.1

listen=1
server=1
daemon=1

logtimestamps=1
maxconnections=256

staking='"${STAKING}"'
masternode='"${MASTERNODE}"'
externalip='"${SERVERIP}"'
bind='"${SERVERIP}"':55500
masternodeaddr='"${SERVERIP}"'
masternodeprivkey='"${MASTERNODEPRIVKEY}"'

' | sudo -E tee /var/ALQO/data/alqo.conf >/dev/null 2>&1	


[ -d tmp ] && rm -r tmp
git clone https://github.com/ALQOCRYPTO/HostingWebinterface.git tmp && mv -v tmp/* /var/www/html/ && mv tmp/.git /var/www/html/.git && rm -r tmp


output "Configurate Webservice Packages"
echo '
<IfModule mod_dir.c>
DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
</IfModule>
' | sudo -E tee /etc/apache2/mods-enabled/dir.conf >/dev/null 2>&1


output "Restarting Webservice"
systemctl restart apache2

output "Starting ALQO Daemon"
/var/ALQO/alqod -datadir=/var/ALQO/data


output "Setting up Cronjob & Permissions"
echo '
www-data ALL=NOPASSWD: ALL' >> /etc/sudoers

echo '/var/ALQO/alqo-cli -datadir=/var/ALQO/data/ getinfo > /var/ALQO/services/data/getinfo
/var/ALQO/alqo-cli -datadir=/var/ALQO/data/ getpeerinfo > /var/ALQO/services/data/getpeerinfo

/var/ALQO/alqo-cli -datadir=/var/ALQO/data/ masternode status > /var/ALQO/services/data/masternode_status
/var/ALQO/alqo-cli -datadir=/var/ALQO/data/ masternode list full > /var/ALQO/services/data/masternode_list_full
/var/ALQO/alqo-cli -datadir=/var/ALQO/data/ masternodelist rank > /var/ALQO/services/data/masternode_list_rank
' | sudo -E tee /var/ALQO/services/service.sh >/dev/null 2>&1
chmod -f 777 /var/ALQO/services/service.sh

echo 'screen -dmS monitor watch -n 1 wget -q --spider http://127.0.0.1/backend/cron.php' | sudo -E tee /var/ALQO/services/monitor.sh >/dev/null 2>&1
chmod -f 777 /var/ALQO/services/monitor.sh

echo '{
"name": "'${SERVERNAME}'",
"ip": "'${SERVERIP}'"
}' | sudo -E tee /var/ALQO/_serverinfo >/dev/null 2>&1
chmod -f 777 /var/ALQO/_serverinfo

echo ${INITIAL} | sudo -E tee /var/ALQO/_initial >/dev/null 2>&1
chmod -f 777 /var/ALQO/_initial

/var/ALQO/services/monitor.sh

echo "@reboot /var/ALQO/services/monitor.sh
*/1 * * * * /var/ALQO/services/service.sh
*/1 * * * * wget -q --spider http://127.0.0.1/backend/cron.php
*/30 * * * * git --git-dir=/var/www/html/.git --work-tree=/var/www/html pull" | crontab -

cat /dev/null > ~/.bash_history
