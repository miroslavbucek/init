#!/bin/bash
apt-get update

# install basic packages
apt-get -y install vim zsh git mc wget htop avahi-daemon rsync

# add ssh key
authorizedkeys=~/.ssh/authorized_keys
sshkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILl4iWGpgvCKPKiJtE0gJ6IIw1ro+20v/o+r4zi96J+u miroslavbucek@gmail.com"
mkdir -p ~/.ssh/
touch $authorizedkeys
grep -qxF "$sshkey" $authorizedkeys || echo "$sshkey" >> $authorizedkeys

# secure ssh
if [ "root" == "$USER" ]; then
  sshfile="/etc/ssh/sshd_config"
  declare -A rules=(
      ["UsePAM"]="no"
      ["PasswordAuthentication"]="no"
  )
  for rule in "${!rules[@]}"; do
  awk -v key="${rule}" -v val="${rules[${rule}]}" \
    '$1==key {foundLine=1; print key " " val} $1!=key{print $0} END{if(foundLine!=1) print key " " val}' \
    $sshfile > sshd_config.tmp && mv sshd_config.tmp $sshfile
  done
fi

# timezone Prague
echo "Europe/Prague" > /etc/timezone 
dpkg-reconfigure -f noninteractive tzdata

# security updates
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
apt-get -y install unattended-upgrades

# install oh my zsh
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

# install czech
if ! grep -q "@mbb" ~/.zshrc; then
locale-gen cs_CZ.UTF-8
echo '# @mbb
# cestina
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# promt s user + hostname
PROMPT="%n@%m%{$reset_color%} ${PROMPT}"

# enable completion
autoload -Uz compinit && compinit' >> ~/.zshrc
fi
