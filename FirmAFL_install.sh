#!/bin/bash
set -e
set -x

GITHUB_URL=github.com
USER_MODE=true
SYSTEM_MODE=true

# ===========================Install FirmAFL===================================
# Install dependencies
sudo apt-get update
sudo apt-get install -y python python-pip qemu
# Clone FirmAFL_2020
git clone https://$GITHUB_URL/zyw-200/FirmAFL_2020.git
# Move in FirmAFL dir
FIRMAFL_INSTALL_DIR=$(pwd)/FirmAFL_2020
pushd $FIRMAFL_INSTALL_DIR


# =============================Install User Mode===============================
if $USER_MODE
then
    # Move in user mode dir
    pushd user_mode
    # Install dependencies
    sudo apt-get install -y pkg-config libglib2.0-dev autoconf automake libtool
    # Compile
    ./configure --target-list=mipsel-linux-user,mips-linux-user,arm-linux-user --static --disable-werror
    make
    # Move out user mode dir
    popd
fi
# =============================User Mode Installed=============================


# =============================Install System Mode=============================
if $SYSTEM_MODE
then
    # Move in system mode dir
    pushd qemu_mode
    pushd DECAF_qemu_2.10
    # Modify config file
    cp zyw_config1.h zyw_config1.h.orig
    sed -i '1d' zyw_config1.h
    # Install dependencies
    sudo apt-get install -y binutils-dev libboost-dev
    # Compile
    ./configure --target-list=mipsel-softmmu,mips-softmmu,arm-softmmu --disable-werror
    make
    # Move out system mode dir
    popd
    popd
fi
# =============================System Mode Installed===========================


# =============================Install binwalk=================================
# Clone binwalk
git clone https://$GITHUB_URL/ReFirmLabs/binwalk.git
# Move in binwalk dir
pushd binwalk
# Modify the version of python in scripts
cp deps.sh deps.sh.orig
sed -i "s#python3#python#g" deps.sh
sed -i "s#python3#python#g" setup.py
# Install dependencies
sudo ./deps.sh --yes
sudo apt-get install python-lzma
sudo -H pip install git+https://$GITHUB_URL/ahupp/python-magic
sudo -H pip install git+https://$GITHUB_URL/sviehb/jefferson
# Install
sudo python ./setup.py install
# Move out binwalk dir
popd
# =============================binwalk Installed===============================


# ============================Install Firmadyne================================
# Clone firmadyne
git clone --recursive https://$GITHUB_URL/firmadyne/firmadyne.git
# Install dependencies
sudo apt-get install -y python-pip busybox-static fakeroot git dmsetup kpartx netcat-openbsd nmap python-psycopg2 snmp uml-utilities util-linux vlan postgresql wget qemu-system-arm qemu-system-mips qemu-system-x86 qemu-utils vim unzip
# Move in firmadyne dir
FIRMADYNE_INSTALL_DIR=$(pwd)/firmadyne
pushd firmadyne
# Move datasheet into firmadyne
sudo cp ../firmadyne_modify/data ./database/
# Set up database
sudo service postgresql start
sudo -u postgres createuser firmadyne
sudo -u postgres createdb -O firmadyne firmware
sudo -u postgres psql -d firmware < ./database/data
echo "ALTER USER firmadyne PASSWORD 'firmadyne'" | sudo -u postgres psql
# Download Firmadyne firmwares
./download.sh
# Modify firmadyne path in config file
mv firmadyne.config firmadyne.config.orig
echo -e '#!/bin/sh' "\nFIRMWARE_DIR=$FIRMADYNE_INSTALL_DIR/" > firmadyne.config
sed -i '1d' firmadyne.config.orig
cat firmadyne.config.orig >> firmadyne.config
# Move out firmadyne dir
popd
# ============================Firmadyne Installed==============================


# Modify scripts in firmadyne
sudo cp firmadyne_modify/makeImage.sh firmadyne/scripts/makeImage.sh
sudo cp firmadyne_modify/makeNetwork.py firmadyne/scripts/makeNetwork.py
popd
# ===========================FirmAFL Installed=================================
