#!/bin/bash

sudo sed -i -re 's/([a-z]{2}\.)?archive.ubuntu.com|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list
sudo apt update
sudo apt upgrade

# potom restart a potom
# sudo do-release-upgrade
