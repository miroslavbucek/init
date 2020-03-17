#!/bin/bash

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


# instalace ohmyzsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended


# instalace pyenv
curl https://pyenv.run | bash

#cat <<"EOF" >> $HOME/.bashrc
cat <<"EOF" >> $HOME/.zshrc

export PATH="/home/caspia/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

export PATH="/home/caspia/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"


# instalace python 3.7
pyenv install 3.7.4
pyenv global 3.7.4
pyenv rehash
pip install --upgrade pip


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
caspia-app install-completion


# Change default shell
chsh -s $(which zsh)


echo "Odhlas se a znovu přihlas"
