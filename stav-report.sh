#!/bin/bash
# Denní stavový report pro notifikačního agenta.
#
# Jeden soubor pro všechny stroje. Sám si zjistí, co na daném stroji může
# změřit - na Proxmox nodu vypíše nody a ZFS, na PBS zálohy, na Dockeru
# kontejnery. Stejný soubor, různý výstup.
#
# Instalace (jednou, ručně, jako root):
#   bash <(wget -qO- https://raw.githubusercontent.com/miroslavbucek/init/master/stav-report.sh) install <email>
#
# Zkouška bez odeslání:
#   /usr/local/bin/stav-report.sh --tisk
#
# POZOR: časovač spouští LOKÁLNÍ kopii, ne `wget | bash`. Kdyby cron denně
# stahoval a spouštěl skript z internetu, znamenal by kompromitovaný GitHub
# účet root na celé flotile. Aktualizace se dělá opakovaným `install`.
#
# Do reportu patří HODNOTY, ne hodnocení. Ne `disk_stav=KRITICKY`, ale
# `disk_/=94%`. Prahy jsou práce monitoringu; agent z hodnot dělá trend.
# Zároveň je celý report jen `klic=hodnota`, takže se do něj nedá propašovat
# žádný text - je to bezpečnější kanál než hlášky aplikací.

set -uo pipefail

VERZE=3
URL="https://raw.githubusercontent.com/miroslavbucek/init/master/stav-report.sh"
CIL="/usr/local/bin/stav-report.sh"
CONF="/etc/stav-report.conf"

# ---------------------------------------------------------------- pomocné
p() { printf '%s\n' "$*"; }
mam() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- jádro
jadro() {
    # Krátké jméno: registr odesílatelů i KONTEXT.md znají stroje takhle.
    p "host=$(hostname -s 2>/dev/null || hostname)  ts=$(date -Is)  skript_v=$VERZE"

    local up dny
    up=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
    dny=$((up / 86400))
    local reboot=no
    [ -f /var/run/reboot-required ] && reboot=yes

    local sec=0
    if mam apt-get; then
        sec=$(apt-get -s -o Debug::NoLocking=true upgrade 2>/dev/null \
              | grep -ci '^Inst.*security' || true)
    fi
    p "uptime_d=$dny  reboot_required=$reboot  updates_sec=$sec"

    # Jen skutečné souborové systémy. ZFS subvolumy kontejnerů se vynechávají -
    # na Proxmox nodu jich jsou desítky a kapacita poolu je stejně níž v zfs=.
    # -P dává sloupce: FS bloky použito volno kapacita přípojný_bod.
    # --output s -P kombinovat nejde, proto se parsuje $5 a $6.
    local radek=""
    while read -r pct mnt; do
        radek+="disk_${mnt}=${pct} "
    done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null \
             | tail -n +2 \
             | awk '$6 !~ "^/(dev|run|sys|proc)" && $6 !~ "(sub|base)vol-" && $6 != "/etc/pve" {print $5" "$6}' \
             | head -6)
    [ -n "$radek" ] && p "${radek% }"

    local mt ma st sf mem swap
    mt=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    ma=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    st=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)
    sf=$(awk '/^SwapFree:/{print $2}' /proc/meminfo)
    mem=$(( mt > 0 ? (mt - ma) * 100 / mt : 0 ))
    swap=$(( st > 0 ? (st - sf) * 100 / st : 0 ))
    p "mem=${mem}%  swap=${swap}%  load15=$(awk '{print $3}' /proc/loadavg)"

    local failed=0
    mam systemctl && failed=$(systemctl list-units --failed --no-legend 2>/dev/null | wc -l)
    p "failed_units=$failed  smart=$(smart_stav)"
}

# Nejhorší stav napříč disky, ne výpis pro každý.
smart_stav() {
    mam smartctl || { echo "nezname"; return; }
    local nejhorsi=ok d out
    for d in /dev/sd? /dev/nvme?n1; do
        [ -e "$d" ] || continue
        out=$(smartctl -H "$d" 2>/dev/null) || continue
        if echo "$out" | grep -qiE 'FAILED|failing_now'; then nejhorsi=fail
        elif echo "$out" | grep -qi 'PASSED\|OK'; then :
        else [ "$nejhorsi" = ok ] && nejhorsi=warn
        fi
    done
    echo "$nejhorsi"
}

# ---------------------------------------------------------------- ZFS
zfs_radky() {
    mam zpool || return 0
    local n h c
    while read -r n h c; do
        p "zfs=$n health=$h cap=$c"
    done < <(zpool list -H -o name,health,capacity 2>/dev/null)

    # Stáří posledního scrubu. Nejstarší pool rozhoduje.
    local nej=""
    while read -r datum; do
        [ -z "$datum" ] && continue
        local d=$(( ( $(date +%s) - $(date -d "$datum" +%s 2>/dev/null || echo 0) ) / 86400 ))
        [ -z "$nej" ] || [ "$d" -gt "$nej" ] && nej=$d
    done < <(zpool status 2>/dev/null | grep -oP 'scrub repaired.*on \K.*' )
    [ -n "$nej" ] && p "zfs_scrub_dni=$nej"
}

# ---------------------------------------------------------------- Proxmox VE
pve_radky() {
    mam pvecm || return 0
    local q="neznamo"
    pvecm status 2>/dev/null | grep -q 'Quorate:.*Yes' && q=ok || q=NE
    p "quorum=$q"

    if mam qm; then
        local vb vc
        vb=$(qm list 2>/dev/null | tail -n +2 | grep -c ' running ' || true)
        vc=$(qm list 2>/dev/null | tail -n +2 | wc -l)
        p "vm_bezi=$vb/$vc"
    fi
    if mam pct; then
        local cb cc
        cb=$(pct list 2>/dev/null | tail -n +2 | grep -c ' running ' || true)
        cc=$(pct list 2>/dev/null | tail -n +2 | wc -l)
        p "ct_bezi=$cb/$cc"
    fi
    if mam pvesr; then
        # FailCount je 7. sloupec. Osmý je State s hodnotou OK, a "OK" != 0
        # je v awk pravda - na tom se dá pěkně vyrobit falešný poplach.
        p "repl_selhalo=$(pvesr status 2>/dev/null | tail -n +2 | awk '$7+0 != 0' | wc -l)"
    fi
    mam ha-manager && p "ha_sluzeb=$(ha-manager status 2>/dev/null | grep -c '^service' || true)"
}

# ---------------------------------------------------------------- PBS
# ZÁMĚRNĚ PRÁZDNÉ. Kapacitu datastorů už pokrývají řádky disk_, a
# `proxmox-backup-manager task list` nevrací nic použitelného. Datum poslední
# zálohy a výsledek verify sem patří, ale až se ověří, čím se dají spolehlivě
# získat - funkce, která mlčky nic neprodukuje, je horší než žádná.

# ---------------------------------------------------------------- Docker
docker_radky() {
    mam docker || return 0
    local b c
    b=$(docker ps -q 2>/dev/null | wc -l)
    c=$(docker ps -aq 2>/dev/null | wc -l)
    p "kontejneru=$b/$c"
    # Restart smyčka je jinak neviditelná.
    p "restartuji=$(docker ps --filter status=restarting -q 2>/dev/null | wc -l)"
}

# ---------------------------------------------------------------- Synology
syno_radky() {
    [ -d /volume1 ] || return 0
    local v pct
    for v in /volume[0-9]*; do
        [ -d "$v" ] || continue
        pct=$(df -P "$v" 2>/dev/null | tail -1 | awk '{gsub(/%/,"",$5); print $5}')
        [ -n "$pct" ] && p "$(basename "$v")=${pct}%"
    done
}

# ---------------------------------------------------------------- report
report() {
    jadro
    zfs_radky
    pve_radky
    docker_radky
    syno_radky
}

odesli() {
    local prijemce="$1" telo="$2" host predmet
    host=$(hostname -f 2>/dev/null || hostname)
    predmet="[stav] $host $(date +%F)"

    if mam sendmail; then
        printf 'To: %s\nSubject: %s\nContent-Type: text/plain; charset=utf-8\n\n%s\n' \
            "$prijemce" "$predmet" "$telo" | sendmail -t
    elif mam mail; then
        printf '%s\n' "$telo" | mail -s "$predmet" "$prijemce"
    else
        echo "stav-report: stroj neumí odeslat poštu (chybí sendmail i mail)" >&2
        return 1
    fi
}

# ---------------------------------------------------------------- instalace
instaluj() {
    local prijemce="${1:-}"
    [ -n "$prijemce" ] || { echo "použití: $0 install <email>" >&2; exit 1; }
    [ "$(id -u)" = 0 ] || { echo "instalace vyžaduje root" >&2; exit 1; }

    # Stahuje se JEDNOU, tady. Časovač pak pouští tuhle lokální kopii.
    wget -qO "$CIL" "$URL" || { echo "stažení selhalo" >&2; exit 1; }
    chmod 755 "$CIL"

    printf 'PRIJEMCE=%s\n' "$prijemce" > "$CONF"
    chmod 600 "$CONF"

    if mam systemctl; then
        cat > /etc/systemd/system/stav-report.service <<EOF
[Unit]
Description=Denní stavový report pro notifikačního agenta

[Service]
Type=oneshot
ExecStart=$CIL
EOF
        cat > /etc/systemd/system/stav-report.timer <<'EOF'
[Unit]
Description=Stavový report v 04:45

[Timer]
# Po zálohovacím jobu (~04:05) a před během agenta (06:00).
OnCalendar=*-*-* 04:45:00
# Rozptyl, ať šest strojů nebuší na poštovní server naráz.
RandomizedDelaySec=600
Persistent=true

[Install]
WantedBy=timers.target
EOF
        systemctl daemon-reload
        systemctl enable --now stav-report.timer >/dev/null
        echo "nainstalováno, časovač: $(systemctl list-timers stav-report.timer --no-pager | sed -n 2p)"
    else
        echo "systemd chybí - časovač si nastav ručně, skript je v $CIL" >&2
    fi

    echo "posílám zkušební report na $prijemce"
    odesli "$prijemce" "$(report)" && echo "odesláno" || echo "ODESLÁNÍ SELHALO - sprav poštu na tomhle stroji" >&2
}

# ---------------------------------------------------------------- main
case "${1:-}" in
    install) shift; instaluj "$@" ;;
    --tisk)  report ;;
    *)
        [ -f "$CONF" ] || { echo "chybí $CONF, spusť nejdřív: $0 install <email>" >&2; exit 1; }
        . "$CONF"
        odesli "$PRIJEMCE" "$(report)"
        ;;
esac
