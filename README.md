# Debian and Ubuntu init

spustit nejdřív jako root a potom jako běžný uživatel

```bash <(wget -qO- https://raw.githubusercontent.com/miroslavbucek/init/master/basic.sh)```

```bash <(wget -qO- bit.ly/mbbinit)```

update sterého nepodporovaného ubuntu

```bash <(wget -qO- bit.ly/mbbubuold)```

https://raw.githubusercontent.com/miroslavbucek/init/master/ubuntu-old-upgrade.sh

instalace dockeru a docker compose pluginu

```bash <(wget -qO- https://raw.githubusercontent.com/miroslavbucek/init/master/install-docker.sh)```

denní stavový report pro notifikačního agenta (nainstaluj jednou jako root)

```bash <(wget -qO- https://raw.githubusercontent.com/miroslavbucek/init/master/stav-report.sh) install <email>```

založí systemd timer na 04:45, pošle zkušební report a dál pouští lokální kopii
(časovač schválně nestahuje z internetu). zkouška bez odeslání:
`/usr/local/bin/stav-report.sh --tisk`
