#!/usr/bin/env bash
# ssh-welcome.sh — clean colorful summary (ASCII bars)

set -u
export LC_ALL=C

# jen interaktivní SSH
[ -n "${SSH_CONNECTION:-}" ] || exit 0
[ -t 1 ] || exit 0

# barvy (nenápadné)
RST=$'\033[0m'; B=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; CYN=$'\033[36m'

ROLE="${ROLE:-$(cat /etc/server-role 2>/dev/null || true)}"
PRETTY_OS="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Debian}")"
KERN="$(uname -r)"
UPTIME_HUMAN="$(uptime -p 2>/dev/null || echo "-")"
LOAD="$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo "- - -")"

# CPU usage snapshot
CPU_IDLE1="$(awk '/^cpu /{print $5}' /proc/stat 2>/dev/null || echo 0)"
CPU_TOTAL1="$(awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print t}' /proc/stat 2>/dev/null || echo 0)"
sleep 0.12
CPU_IDLE2="$(awk '/^cpu /{print $5}' /proc/stat 2>/dev/null || echo 0)"
CPU_TOTAL2="$(awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print t}' /proc/stat 2>/dev/null || echo 0)"
DT=$((CPU_TOTAL2-CPU_TOTAL1)); DI=$((CPU_IDLE2-CPU_IDLE1))
CPU_USE_PCT=0; [ "$DT" -gt 0 ] && CPU_USE_PCT=$(( ((DT-DI)*100) / DT ))

# RAM / Swap
MEM_TOTAL_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_AVAIL_KB="$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
MEM_USED_PCT=0; [ "$MEM_TOTAL_KB" -gt 0 ] && MEM_USED_PCT=$(( (MEM_USED_KB*100) / MEM_TOTAL_KB ))

SWAP_TOTAL_KB="$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
SWAP_FREE_KB="$(awk '/SwapFree/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
SWAP_USED_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
SWAP_USED_PCT=0; [ "$SWAP_TOTAL_KB" -gt 0 ] && SWAP_USED_PCT=$(( (SWAP_USED_KB*100) / SWAP_TOTAL_KB ))

# Updates + reboot
UPDATES="n/a"
command -v apt-get >/dev/null 2>&1 && UPDATES="$(apt-get -s upgrade 2>/dev/null | awk '/^Inst /{c++} END{print c+0}')"
REBOOT="no"; [ -f /var/run/reboot-required ] && REBOOT="YES"

# Btrfs device errors
BTRFS_ERRS="n/a"
if command -v btrfs >/dev/null 2>&1 && findmnt -t btrfs -n >/dev/null 2>&1; then
  out="$(btrfs device stats / 2>/dev/null || true)"
  if [ -n "$out" ]; then
    bad="$(echo "$out" | awk -F'[:, ]+' '
      /write_errs|read_errs|flush_errs|corruption_errs|generation_errs/ {
        for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/) v=$i
        if(v+0!=0) {print; exit}
      }')"
    [ -n "$bad" ] && BTRFS_ERRS="ERRORS" || BTRFS_ERRS="OK"
  else
    BTRFS_ERRS="OK"
  fi
fi

# Security (ssh failed)
HOURS="${FAIL_HOURS:-6}"
FAILED_CNT="n/a"; LAST_FAILED="n/a"
if command -v journalctl >/dev/null 2>&1; then
  FAILED_CNT="$(journalctl -u ssh --since "${HOURS} hours ago" --no-pager 2>/dev/null \
    | grep -E 'Failed password|Invalid user|authentication failure' | wc -l | tr -d ' ')" || true
  LAST_FAILED="$(journalctl -u ssh --no-pager -n 300 2>/dev/null \
    | grep -E 'Failed password|Invalid user|authentication failure' | tail -n 1 || true)"
  [ -n "$LAST_FAILED" ] || LAST_FAILED="(none in last 300 ssh logs)"
fi

cols() { tput cols 2>/dev/null || echo 80; }
W="$(cols)"
BW=$((W - 18)); [ "$BW" -lt 12 ] && BW=12; [ "$BW" -gt 36 ] && BW=36

bar() {
  # ASCII bar: '=' + '.'
  local p="$1" w="$2"
  [ "$p" -lt 0 ] && p=0
  [ "$p" -gt 100 ] && p=100
  local filled=$(( (p*w)/100 ))
  local empty=$(( w-filled ))

  local col="$GRN"
  [ "$p" -ge 85 ] && col="$RED"
  [ "$p" -ge 70 ] && [ "$p" -lt 85 ] && col="$YEL"

  printf "%b" "$col"
  printf "%*s" "$filled" "" | tr ' ' '='
  printf "%b" "$DIM"
  printf "%*s" "$empty" "" | tr ' ' '.'
  printf "%b" "$RST"
}

status_col() {
  local kind="$1" val="$2"
  case "$kind" in
    btrfs) [ "$val" = "OK" ] && echo "$GRN" || ([ "$val" = "ERRORS" ] && echo "$RED" || echo "$DIM");;
    reboot) [ "$val" = "YES" ] && echo "$YEL" || echo "$GRN";;
    updates) [ "$val" = "n/a" ] && echo "$DIM" || ([ "$val" -eq 0 ] 2>/dev/null && echo "$GRN" || echo "$YEL");;
    *) echo "$DIM";;
  esac
}

# ----- OUTPUT (bez prázdného 1. řádku, bez hostname) -----
printf "%bOS%b: %s  %bKernel%b: %s  %bRole%b: %s\n" \
  "$DIM" "$RST" "$PRETTY_OS" "$DIM" "$RST" "$KERN" "$DIM" "$RST" "${ROLE:-"-"}"
printf "%bUptime%b: %s  %bLoad%b: %s\n" "$DIM" "$RST" "$UPTIME_HUMAN" "$DIM" "$RST" "$LOAD"
echo

printf "%bCPU%b  %3s%% %s\n" "$DIM" "$RST" "$CPU_USE_PCT" "$(bar "$CPU_USE_PCT" "$BW")"
printf "%bRAM%b  %3s%% %s  %b%sMiB/%sMiB%b\n" "$DIM" "$RST" "$MEM_USED_PCT" "$(bar "$MEM_USED_PCT" "$BW")" \
  "$DIM" "$((MEM_USED_KB/1024))" "$((MEM_TOTAL_KB/1024))" "$RST"

if [ "$SWAP_TOTAL_KB" -gt 0 ]; then
  printf "%bSWAP%b %3s%% %s  %b%sMiB/%sMiB%b\n" "$DIM" "$RST" "$SWAP_USED_PCT" "$(bar "$SWAP_USED_PCT" "$BW")" \
    "$DIM" "$((SWAP_USED_KB/1024))" "$((SWAP_TOTAL_KB/1024))" "$RST"
else
  printf "%bSWAP%b disabled\n" "$DIM" "$RST"
fi

echo
printf "%bDisks%b (warn: free<=15%% / <=10%%)\n" "$DIM" "$RST"

show_df() {
  local mp="$1" fs size used avail usep free_pct markcol mark
  read -r fs size used avail usep _ < <(df -P -h "$mp" 2>/dev/null | awk 'NR==2{print $1,$2,$3,$4,$5,$6}') || return 0
  free_pct="$(df -P "$mp" 2>/dev/null | awk 'NR==2{gsub("%","",$5); print 100-$5}')" || return 0
  markcol="$GRN"; mark="OK"
  [ "$free_pct" -le 15 ] && markcol="$YEL" && mark="LOW"
  [ "$free_pct" -le 10 ] && markcol="$RED" && mark="CRIT"
  printf "  %-10s %b%-4s%b  free:%-6s used:%-6s size:%-6s use:%-5s  %b%s%b\n" \
    "$mp" "$markcol" "$mark" "$RST" "$avail" "$used" "$size" "$usep" "$DIM" "$fs" "$RST"
}

for mp in / /var /home /nas; do
  mountpoint -q "$mp" 2>/dev/null && show_df "$mp"
done
for mp in /mnt/* /nas/*; do
  [ -e "$mp" ] || continue
  mountpoint -q "$mp" 2>/dev/null && show_df "$mp"
done

echo
printf "%bBtrfs%b: %b%s%b  %bUpdates%b: %b%s%b  %bReboot%b: %b%s%b\n" \
  "$DIM" "$RST" "$(status_col btrfs "$BTRFS_ERRS")" "$BTRFS_ERRS" "$RST" \
  "$DIM" "$RST" "$(status_col updates "$UPDATES")" "$UPDATES" "$RST" \
  "$DIM" "$RST" "$(status_col reboot "$REBOOT")" "$REBOOT" "$RST"

printf "%bSecurity%b: failed ssh last %sh: %b%s%b\n" "$DIM" "$RST" "$HOURS" "$CYN" "$FAILED_CNT" "$RST"
printf "  %b%s%b\n" "$DIM" "$LAST_FAILED" "$RST"
