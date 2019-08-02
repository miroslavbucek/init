#!/bin/bash

curl https://pyenv.run | bash

cat <<"EOF" >> $HOME/.bashrc

export PATH="/home/caspia/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

export PATH="/home/caspia/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

pyenv install 3.7.4
pyenv global 3.7.4
pyenv rehash
