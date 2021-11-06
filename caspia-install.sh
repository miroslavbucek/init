#!/bin/bash
# spuštění
# bash <(wget -qO- https://raw.githubusercontent.com/miroslavbucek/init/master/caspia-install.sh) -u nuc -p <heslo>

# ošetření jména a hesla
while [[ $# -gt 0 ]]
do
  case $1 in
     -u) USER=$2
      shift ;;
     -p) PASS=$2
      shift ;;
    *) echo "bad arguments"
      exit 1 ;;
esac
shift
done


# install docker
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli


# nastavení docker registry
docker login -u $USER -p $PASS registry.caspiatech.cz


# instalace ohmyzsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended


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


# Change default shell
chsh -s $(which zsh)


# install czech
if ! grep -q "@mbb" ~/.zshrc; then
sudo locale-gen cs_CZ.UTF-8
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

zsh

# instalace caspia-app
pip install caspia-app


echo "Odhlas se a znovu přihlas"
