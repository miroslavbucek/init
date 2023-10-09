#!/bin/bash

# secure ssh
if [ "root" == "$USER" ]; then
  sshfile="/etc/ssh/sshd_config"
  declare -A rules=(
      ["UsePAM"]="no"
      ["PasswordAuthentication"]="no")
  for rule in "${!rules[@]}"; do
  awk -v key="${rule}" -v val="${rules[${rule}]}" \
    '$1==key {foundLine=1; print key " " val} $1!=key{print $0} END{if(foundLine!=1) print key " " val}' \
    $sshfile > sshd_config.tmp && mv sshd_config.tmp $sshfile
  done
fi

systemctl reload ssh
