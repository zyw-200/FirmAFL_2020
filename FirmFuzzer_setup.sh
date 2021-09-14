#!/bin/bash
set -e
#set -x

GITHUB_URL=gitclone.com/github.com
USER_MODE=true
SYSTEM_MODE=true

echo "[+] Install dependencies"
sudo apt-get update
sudo apt-get install -y python python-pip

echo "[+] Change source of python-pip"
if [ ! -e ~/.pip ]
then
    mkdir ~/.pip
fi
cp ./pip.conf ~/.pip/

echo "[+] Unzip FirmAFL source files"
tar zxf FirmAFL.tar.gz

# Move to FirmAFL dir
FIRMAFL_INSTALL_DIR=$(pwd)/FirmAFL
pushd $FIRMAFL_INSTALL_DIR

if $USER_MODE
then
    echo "[+] Install User Mode"
    pushd user_mode

    # Install dependencies
    sudo apt-get install -y pkg-config libglib2.0-dev autoconf automake libtool

    # Compile
    ./configure --target-list=mipsel-linux-user,mips-linux-user,arm-linux-user --static --disable-werror
    make
    popd
fi

if $SYSTEM_MODE
then
    echo "[+] Install System Mode"
    pushd qemu_mode
    pushd DECAF_qemu_2.10

    # Install dependencies
    sudo apt-get install -y binutils-dev libboost-dev

    # Compile
    ./configure --target-list=mipsel-softmmu,mips-softmmu,arm-softmmu --disable-werror
    make
    popd
    popd
fi

echo "[+] Install Firmadyne"
# Install dependencies
sudo apt-get install -y python-pip python3-pip busybox-static fakeroot git dmsetup kpartx netcat-openbsd nmap python3-psycopg2 snmp uml-utilities util-linux vlan postgresql wget qemu-system-arm qemu-system-mips qemu-system-x86 qemu-utils vim unzip

# Move to firmadyne dir
FIRMADYNE_INSTALL_DIR=$(pwd)/firmadyne

echo "[+] Set up binwalk"
pushd binwalk
sudo cp -r deps/* /tmp
sudo ./deps.sh --yes
sudo apt install python-lzma
# Install additional deps
sudo pip install ./pip_deps/python-magic
sudo pip install ./pip_deps/jefferson
#sudo pip install git+https://$GITHUB_URL/ahupp/python-magic
#sudo pip install git+https://$GITHUB_URL/sviehb/jefferson
sudo python ./setup.py install
popd

echo "[+] Set up database"
sudo service postgresql start
sudo -u postgres createuser firmadyne
sudo -u postgres createdb -O firmadyne firmware
sudo -u postgres psql -d firmware < ./firmadyne/database/schema
sudo -u postgres psql -d firmware < ./firmadyne/database/data
echo "ALTER USER firmadyne PASSWORD 'firmadyne'" | sudo -u postgres psql

echo "[+] Download Firmadyne firmwares"
pushd firmadyne
#./download.sh

# Make sure firmadyne user owns this dir
# sudo chown -R firmadyne:firmadyne $FIRMADYNE_INSTALL_DIR
popd

echo "[+] Modify makeImage.sh in firmadyne"
cp firmadyne_modify/makeImage.sh firmadyne/scripts/makeImage.sh
