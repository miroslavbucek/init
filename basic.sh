#!/bin/bash

# update
apt-get update

# install basic packages
apt-get -y install vim zsh git mc wget htop avahi-daemon

# timezone Prague
echo "Europe/Prague" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# security updates
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
apt-get -y install unattended-upgrades

# install oh my zsh
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

# install czech
locale-gen cs_CZ.UTF-8
echo '
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# promt s user + hostname
PROMPT="%n@%m%{$reset_color%} ${PROMPT}"
# enable completion
autoload -Uz compinit && compinit' >> ~/.zshrc
