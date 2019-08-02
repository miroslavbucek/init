#!/bin/bash

# update
apt-get update

# packages
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev

# python compilation
wget https://www.python.org/ftp/python/3.6.3/Python-3.6.3.tgz
tar xvf Python-3.6.3.tgz
cd Python-3.6.3
./configure --enable-optimizations --enable-shared
make -j8
sudo make altinstall
python3.6

# setup as default
sudo update-alternatives --set python /usr/bin/python3.6
