#!/bin/bash

NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
MAX=12


SENTINELGITHUB=https://github.com/PACCommunity/sentinel
COINDAEMON=./paccoind
COINCLI=./paccoin-cli
COINCORE=.paccoincore
COINCONFIG=paccoin.conf


version=0.12.3.1
old_version=0.12.3.0
base_url=https://github.com/PACCommunity/PAC/releases/download/v${version}
tarball_name=PAC-v${version}-linux-x86_64.tar.gz
binary_url=${base_url}/${tarball_name}


if [ "$1" == "--testnet" ]; then
    COINRPCPORT=17111
    COINPORT=17112
    is_testnet=1
else
    COINRPCPORT=7111
    COINPORT=7112
    is_testnet=0
fi

setupSwap() {
    echo && echo -e "${NONE}[3/${MAX}] Adding swap space...${YELLOW}"
    sudo fallocate -l $swap_size /swapfile
    sleep 2
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo -e "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null 2>&1
    sudo sysctl vm.swappiness=10
    sudo sysctl vm.vfs_cache_pressure=50
    echo -e "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
    echo -e "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}


checkForUbuntuVersion() {
   echo "[1/${MAX}] Checking Ubuntu version..."
    if [[ `cat /etc/issue.net`  == *16.04* ]]; then
        echo -e "${GREEN}* You are running `cat /etc/issue.net` . Setup will continue.${NONE}";
    else
        echo -e "${RED}* You are not running Ubuntu 16.04.X. You are running `cat /etc/issue.net` ${NONE}";
        echo && echo "Installation cancelled" && echo;
        exit;
    fi
}

updateAndUpgrade() {
    echo
    echo "[2/${MAX}] Runing update and upgrade. Please wait..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq -y > /dev/null 2>&1
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1
    echo -e "${GREEN}* Done${NONE}";
}


installDependencies() {
    echo
    echo -e "[6/${MAX}] Installing dependecies. Please wait..."
    sudo apt-get install screen curl pwgen apache2 php libapache2-mod-php php-mcrypt php-mysql -qq -y > /dev/null 2>&1
    sudo apt-get install git nano rpl wget python-virtualenv -qq -y > /dev/null 2>&1
    sudo apt-get install build-essential libtool automake autoconf -qq -y > /dev/null 2>&1
    sudo apt-get install autotools-dev autoconf pkg-config libssl-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libgmp3-dev libevent-dev bsdmainutils libboost-all-dev -qq -y > /dev/null 2>&1
    sudo apt-get install software-properties-common python-software-properties -qq -y > /dev/null 2>&1
    sudo add-apt-repository ppa:bitcoin/bitcoin -y > /dev/null 2>&1
    sudo apt-get update -qq -y > /dev/null 2>&1
    sudo apt-get install libdb4.8-dev libdb4.8++-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libminiupnpc-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libzmq5 -qq -y > /dev/null 2>&1
    sudo apt-get install virtualenv -qq -y > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installFail2Ban() {
    echo
    echo -e "[4/${MAX}] Installing fail2ban. Please wait..."
    sudo apt-get -y install fail2ban > /dev/null 2>&1
    sudo systemctl enable fail2ban > /dev/null 2>&1
    sudo systemctl start fail2ban > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installFirewall() {
    echo
    echo -e "[5/${MAX}] Installing UFW. Please wait..."
    sudo apt-get -y install ufw > /dev/null 2>&1
    sudo ufw default deny incoming > /dev/null 2>&1
    sudo ufw default allow outgoing > /dev/null 2>&1
    sudo ufw allow ssh > /dev/null 2>&1
    sudo ufw limit ssh/tcp > /dev/null 2>&1
    sudo ufw allow $COINPORT/tcp > /dev/null 2>&1
    sudo ufw allow $COINRPCPORT/tcp > /dev/null 2>&1
    sudo ufw logging on > /dev/null 2>&1
    echo "y" | sudo ufw enable > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installWallet() {
    echo
    echo -e "[8/${MAX}] Installing wallet. Please wait..."
    if test -e "${tarball_name}"; then
        sudo rm -r $tarball_name
    fi
    wget $binary_url
    echo "Unpacking $PAC distribution"
    sudo tar -xvzf $tarball_name
    sudo chmod +x paccoind
    sudo chmod +x paccoin-cli
    echo "Binaries were saved to: $PWD/$tarball_name"
    sudo rm -r $tarball_name
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installSentinel() {
    echo
    echo -e "[10/${MAX}] Installing Sentinel...${YELLOW}"
    git clone $SENTINELGITHUB sentinel > /dev/null 2>&1
    cd sentinel
    export LC_ALL=C > /dev/null 2>&1
    virtualenv ./venv > /dev/null 2>&1
    ./venv/bin/pip install -r requirements.txt > /dev/null 2>&1
    venv/bin/python bin/sentinel.py > /dev/null 2>&1
    sleep 3
    crontab 'crontab.txt'
    echo -e "${NONE}${GREEN}* Done${NONE}";
}


configureWallet() {
    echo
    echo -e "[9/${MAX}] Configuring wallet. Please wait..."
    $COINDAEMON -daemon > /dev/null 2>&1
    sleep 10

    MNIP=$(curl --silent ipinfo.io/ip)
    RPCUSER=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    RPCPASS=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`

    $COINCLI stop > /dev/null 2>&1
    sleep 10


    echo "Configuring the paccoin.conf"
    echo "rpcuser=$RPCUSER" > paccoin.conf
    echo "rpcpassword=RPCPASS" >> paccoin.conf
    echo "rpcallowip=127.0.0.1" >> paccoin.conf
    echo "rpcport=$COINRPCPORT" >> paccoin.conf
    echo "externalip=$MNIP" >> paccoin.conf
    echo "port=$COINPORT" >> paccoin.conf
    echo "server=1" >> paccoin.conf
    echo "daemon=1" >> paccoin.conf
    echo "listen=1" >> paccoin.conf
    echo "testnet=$is_testnet" >> paccoin.conf
    echo "masternode=1" >> paccoin.conf
    echo "masternodeaddr=$MNIP:$COINPORT" >> paccoin.conf
    echo "masternodeprivkey=$mnkey" >> paccoin.conf
    echo -e "${NONE}${GREEN}* Done${NONE}";
}


startWallet() {
    echo
    echo -e "[11/${MAX}] Starting wallet daemon..."
    $COINDAEMON -daemon > /dev/null 2>&1
    sleep 5
    echo -e "${GREEN}* Done${NONE}";
}

syncWallet() {
    echo
    echo "[12/${MAX}] Waiting for wallet to sync. It will take a while, you can go grab a coffee :)"
    until $COINCLI mnsync status | grep -m 1 '"IsBlockchainSynced": true'; do sleep 1 ; done > /dev/null 2>&1
    echo -e "${GREEN}* Blockchain Synced${NONE}";
    until $COINCLI mnsync status | grep -m 1 '"IsMasternodeListSynced": true'; do sleep 1 ; done > /dev/null 2>&1
    echo -e "${GREEN}* Masternode List Synced${NONE}";
    until $COINCLI mnsync status | grep -m 1 '"IsWinnersListSynced": true'; do sleep 1 ; done > /dev/null 2>&1
    echo -e "${GREEN}* Winners List Synced${NONE}";
    until $COINCLI mnsync status | grep -m 1 '"IsSynced": true'; do sleep 1 ; done > /dev/null 2>&1
    echo -e "${GREEN}* Done reindexing wallet${NONE}";
}




    setupSwap
    checkForUbuntuVersion
    updateAndUpgrade
    installFail2Ban
    installFirewall
    installDependencies
    installWallet
    configureWallet
    installSentinel
    startWallet
    syncWallet
