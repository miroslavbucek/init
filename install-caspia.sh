#!/bin/bash

# install python3
apt-get install python3.9 python3-pip

# install docker
apt-get install \\n    apt-transport-https \\n    ca-certificates \\n    curl \\n    gnupg \\n    lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \\n  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \\n  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli

# nastavení docker registry
docker login -u $USER -p $PASS registry.caspiatech.cz


# instalace caspia pip repository
mkdir -p $HOME/.config/pip/
cat <<EOF >> $HOME/.config/pip/pip.conf
[global]
index-url = https://$USER:$PASS@pypi.caspiatech.cz/simple
extra-index-url = https://pypi.python.org/simple
EOF

export PIP_INDEX_URL=https://$USER:$PASS@pypi.caspiatech.cz/simple
export PIP_EXTRA_INDEX_URL=https://pypi.python.org/simple


# instalace caspia-app
pip install caspia-app

git clone http://repo.caspiatech.cz/configuration/simple-mock
mkdir simple-mock-storage
cd simple-mock
caspia-app create --mock
caspia-app start
