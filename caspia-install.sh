#!/bin/sh

# ošetření jména a hesla
USER="jmeno"
PASS="heslo"

function usage()
{
    echo "if this was a real script you would see something useful here"
    echo ""
    echo "./simple_args_parsing.sh"
    echo "\t-h --help"
    echo "\t--user=$USER"
    echo "\t--pass=$PASS"
    echo ""
}

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        --user)
            USER=$VALUE
            ;;
        --pass)
            PASS=$VALUE
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done


# instalace ohmyzsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"


# instalace pyenv
curl https://pyenv.run | bash

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
cat <<"EOF" >> $HOME/.config/pip/pip.conf
[global]
index-url = https://$USER:$PASS@pypi.caspiatech.cz/simple
extra-index-url = https://pypi.python.org/simple
EOF

EXPORT PIP_INDEX_URL=https://$USER:$PASS@pypi.caspiatech.cz/simple
EXPORT PIP_EXTRA_INDEX_URL=https://pypi.python.org/simple


# instalace caspia-app
pip install caspia-app
