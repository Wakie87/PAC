#!/bin/sh


# Variables:
# These variables control the script's function. The only item you should change is the scrape address (the first variable, see above)
#

# Are you setting up a Ionode? if so you want to set these variables
# Set varIonode to 1 if you want to run a node, otherwise set it to zero. 
varPacMNode=0
# This will set the external IP to your IP address (linux only), or you can put your IP address in here
vaPacMNodeExternalIP=$(curl -s ipinfo.io/ip)
# This is your ionode private key. To get it run ion-cli ionode genkey
varPacMNodePrivateKey=ReplaceMeWithOutputFrom_ion-cli_ionode_genkey
# This is the label you want to give your ionode
varPacMNodeLabel=""



# Location of PAC Binaries, GIT Directories, and other useful files
# Do not use the GIT directory (/PAC/) for anything other than GIT stuff
varUserDirectory=/root/
varPacBinaries="${varUserDirectory}Pac/bin/"
varScriptsDirectory="${varUserDirectory}Pac/UserScripts/"
varPacConfigDirectory="${varUserDirectory}.paccoincore/"
varPacConfigFile="${varUserDirectory}.paccoincore/paccoin.conf"
varGITRootPath="${varUserDirectory}"
varGITPacPath="${varGITRootPath}Pac/"
varBackupDirectory="${varUserDirectory}Pac/Backups/"

version=0.12.3.1
old_version=0.12.3.0
base_url=https://github.com/PACCommunity/PAC/releases/download/v${version}
tarball_name=PAC-v${version}-linux-x86_64.tar.gz
binary_url=${base_url}/${tarball_name}
SENTINELGITHUB=https://github.com/PACCommunity/sentinel


DEBIAN_FRONTEND=noninteractive

#Expand Swap File
varExpandSwapFile=true


# QuickStart Binaries
varQuickStart=true
# Quickstart compressed file location and name
varQuickStartCompressedFileLocation=${base_url}/${tarball_name}
varQuickStartCompressedFileName=PAC-v${version}-linux-x86_64.tar.gz
varQuickStartCompressedFilePathForDaemon=paccoind
varQuickStartCompressedFilePathForCLI=paccoin-cli


#Filenames of Generated Scripts
PacStop="${varScriptsDirectory}pacStopPaccoind.sh"
PacStart="${varScriptsDirectory}pacStart.sh"

if [ "$1" == "--testnet" ]; then
    COINRPCPORT=17111
    COINPORT=17112
    is_testnet=1
else
    COINRPCPORT=7111
    COINPORT=7112
    is_testnet=0
fi



#End of Variables




### Prep your VPS (Increase Swap Space and update) ###

if [ "$varExpandSwapFile" = true ]; then
    cd $varUserDirectory
    # This will expand your swap file. It is not necessary if your VPS has more than 4G of ram, but it wont hurt to have
    echo "Expanding the swap file for optimization with low RAM VPS..."
    echo "sudo fallocate -l 4G /swapfile"
	sudo fallocate -l 4G /swapfile
    echo "sudo chmod 600 /swapfile"
	sudo chmod 600 /swapfile
	echo "sudo mkswap /swapfile"
    sudo mkswap /swapfile
    echo "sudo swapon /swapfile"
	sudo swapon /swapfile

    # the following command will append text to fstab to make sure your swap file stays there even after a reboot.
	varSwapFileLine=$(cat /etc/fstab | grep "/swapfile none swap sw 0 0")
	if [  "varSwapFileLine" = "" ]; then
	    echo "Adding swap file line to /etc/fstab"
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
	else
	    echo "Swap file line is already in /etc/fstab"
	fi
    echo "Swap file expanded."	
	
	echo "Current Swap File Status:"
	echo "sudo swapon -s"
	sudo swapon -s
	echo ""
	echo "Let's check the memory"
	echo "free -m"
	free -m
	echo ""
	echo "Ok, now let's check the swapieness"
	echo "cat /proc/sys/vm/swappiness"
	cat /proc/sys/vm/swappiness
	echo ""
	echo "Desktops usually have a swapieness of 60 or so, VPS's are usually lower. It should not matter for this application. It is just a curiosity."
	echo "End of Swap File expansion"
	echo "-------------------------------------------"
fi

# Ensure that your system is up to date and fully patched
echo ""
echo "Updating OS and packages..."
echo "sleeping for 60 seconds, this is because some VPS's are not fully up if you use this as a startup script"
sleep 60
echo "sudo apt-get update"
sudo apt-get update
echo "sudo apt-get -y upgrade"
sudo apt-get -y upgrade
echo "OS and packages updated."
echo ""

#Install any utilities you need for the script
echo ""
echo "Installing dependecies. Please wait..."
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
echo ""


## make the directories we are going to use
echo "Make the directories we are going to use"
mkdir -pv $varPacBinaries
mkdir -pv $varScriptsDirectory
mkdir -pv $varBackupDirectory




### Script #1: Stop paccoind ###
# Filename PacStopPaccoind.sh
cd $varScriptsDirectory
echo "Creating The Stop paccoind Script: PacStopPaccoind.sh"
echo '#!/bin/sh' > PacStopPaccoind.sh
echo "# This file was generated. $(date +%F_%T) Version: $varVersion" >> PacStopPaccoind.sh
echo "# This script is here to force stop or force kill paccoind" >> PacStopPaccoind.sh
echo "echo \"\$(date +%F_%T) Stopping the paccoind if it already running \"" >> PacStopPaccoind.sh
echo "PID=\`ps -eaf | grep paccoind | grep -v grep | awk '{print \$2}'\`" >> PacStopPaccoind.sh
echo "if [ \"\" !=  \"\$PID\" ]; then" >> PacStopPaccoind.sh
echo "    if [ -e ${varPacBinaries}ion-cli ]; then"  >> PacStopPaccoind.sh
echo "        sudo ${varPacBinaries}ion-cli stop" >> PacStopPaccoind.sh
echo "        echo \"\$(date +%F_%T) Stop sent, waiting 30 seconds\""  >> PacStopPaccoind.sh
echo "        sleep 30" >> PacStopPaccoind.sh
echo "    fi"  >> PacStopPaccoind.sh
echo "# At this point we should be stopped. Let's recheck and kill if we need to. "  >> PacStopPaccoind.sh
echo "    PID=\`ps -eaf | grep paccoind | grep -v grep | awk '{print \$2}'\`" >> PacStopPaccoind.sh
echo "    if [ \"\" !=  \"\$PID\" ]; then" >> PacStopPaccoind.sh
echo "        echo \"\$(date +%F_%T) Rouge paccoind process found. Killing PID: \$PID\""  >> PacStopPaccoind.sh
echo "        sudo kill -9 \$PID" >> PacStopPaccoind.sh
echo "        sleep 5" >> PacStopPaccoind.sh
echo "        echo \"\$(date +%F_%T) Paccoind has been Killed! PID: \$PID\""  >> PacStopPaccoind.sh
echo "    else"  >> PacStopPaccoind.sh
echo "        echo \"\$(date +%F_%T) Paccoind has been stopped.\""  >> PacStopPaccoind.sh
echo "    fi" >> PacStopPaccoind.sh
echo "else"  >> PacStopPaccoind.sh
echo "    echo \"\$(date +%F_%T) Pac is not running. No need for shutdown commands.\""  >> PacStopPaccoind.sh
echo "fi" >> PacStopPaccoind.sh
echo "# End of generated Script" >> PacStopPaccoind.sh
echo "Changing the file attributes so we can run the script"
chmod +x PacStopPaccoind.sh
echo "Created PacStopPaccoind.sh"
PacStop="${varScriptsDirectory}PacStopPaccoind.sh"
echo "--"

### Script #2: Start Paccoind ###
# Filename PacStart.sh
cd $varScriptsDirectory
echo "Creating Mining Start script: PacStart.sh"
echo '#!/bin/sh' > PacStart.sh
echo "" >> PacStart.sh
echo "# This file, PacStart.sh, was generated. $(date +%F_%T) Version: $varVersion" >> PacStart.sh
echo "echo \"\$(date +%F_%T) Starting Pac miner: \$(date)\"" >> PacStart.sh
echo "sudo ${varPacBinaries}paccoind --daemon" >> PacStart.sh
echo "echo \"\$(date +%F_%T) Waiting 15 seconds \"" >> PacStart.sh
echo "sleep 15" >> PacStart.sh
echo "# End of generated Script" >> PacStart.sh

echo "Changing the file attributes so we can run the script"
chmod +x PacStart.sh
echo "Created PacStart.sh."
PacStart="${varScriptsDirectory}PacStart.sh"
echo "--"


echo "Done creating scripts"
echo "-------------------------------------------"

### Functions ###

funcCreatePacConfFile ()
{
 echo "---------------------------------"
 echo "- Creating the configuration file."
 echo "- Creating the paccoin.conf file, this replaces any existing file. "
 echo "Need to crate a random password and user name. Check current entropy"
 sudo cat /proc/sys/kernel/random/entropy_avail

 sleep 1
 rpcuser=$(sudo tr -d -c "a-zA-Z0-9" < /dev/urandom | sudo head -c 34)
 echo "rpcuser=$rpcuser"
 sleep 1
 rpcpassword=$(sudo tr -d -c "a-zA-Z0-9" < /dev/urandom | sudo head -c $(shuf -i 30-36 -n 1))
 echo "rpcpassword=$rpcpassword"
 
 mkdir -pv $varPacConfigDirectory
 echo "# This file was generated. $(date +%F_%T)  Version: $varVersion" > $varPacConfigFile
 echo "# Do not use special characters or spaces with username/password" >> $varPacConfigFile
 echo "rpcuser=$rpcuser" >> $varPacConfigFile
 echo "rpcpassword=$rpcpassword" >> $varPacConfigFile
 echo "rpcallowip=127.0.0.1" >> $varPacConfigFile
 echo "rpcport=7111" >> $varPacConfigFile
 echo "port=7112" >> $varPacConfigFile
 echo "externalip=$varPacMNodeExternalIP" >> $varPacConfigFile
 echo "server=1" >> $varPacConfigFile
 echo "daemon=1" >> $varPacConfigFile
 echo "listen=1" >> $varPacConfigFile
 echo "" >> $varPacConfigFile
 
 if [ "$varPacMNode" = 1 ]; then
  echo "# MNNODE: " >> $varPacConfigFile
  echo "masternodeaddr=$varPacMNodeExternalIP:$COINPORT" >> paccoin.conf
  echo "masternode=$varPacMNode" >> $varPacConfigFile
  echo "masternodeprivkey=$varPacMNodePrivateKey" >> $varPacConfigFile
  echo "" >> $varPacConfigFile
 fi

 echo "# End of generated file" >> $varPacConfigFile
 echo "- Finished creating paccoin.conf"
 echo "---------------------------------"
 sleep 1
}



funcCreatePacConfFile


## Quick Start (get binaries from the web, not completely safe or reliable, but fast!)
if [ "$varQuickStart" = true ]; then

echo "Beginning QuickStart Executable (binaries) download and start"

echo "If the paccoind process is running, this will kill it."
sudo ${PacStop}

mkdir -pv ${varUserDirectory}QuickStart
cd ${varUserDirectory}QuickStart
echo "Downloading and extracting Pac binaries"
rm -fdr $varQuickStartCompressedFileName
echo "wget -o /dev/null $varQuickStartCompressedFileLocation"
wget -o /dev/null $varQuickStartCompressedFileLocation
tar -xvzf $varQuickStartCompressedFileName

echo "Copy QuickStart binaries"
mkdir -pv $varPacBinaries
sudo cp -v $varQuickStartCompressedFilePathForDaemon $varPacBinaries
sudo cp -v $varQuickStartCompressedFilePathForCLI $varPacBinaries
sudo cp -v $varQuickStartCompressedFilePathForDaemon /usr/local/bin
sudo cp -v $varQuickStartCompressedFilePathForCLI /usr/local/bin

echo "Launching daemon for the first time."
echo "sudo ${varPacBinaries}paccoind --daemon"
sudo ${varPacBinaries}paccoind --daemon
sleep 60

is_pac_running=`ps ax | grep -v grep | grep paccoind | wc -l`
if [ $is_pac_running -eq 0 ]; then
	echo "The daemon is not running or there is an issue, please restart the daemon!"
fi

echo "The Daemon has started."


cd ~/
git clone $SENTINELGITHUB > /dev/null 2>&1
cd sentinel
virtualenv ./venv > /dev/null 2>&1
./venv/bin/pip install -r requirements.txt > /dev/null 2>&1
venv/bin/python bin/sentinel.py > /dev/null 2>&1
sleep 3
crontab 'crontab.txt'

sudo ${varPacBinaries}paccoin-cli getinfo

echo "Your PAC server is ready!"

echo "SCRIPT END"

echo "QuickStart complete"
fi
#End of QuickStart
