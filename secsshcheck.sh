#!/bin/bash

# secure ssh check
if [ "$USER" != "root" ]; then
  echo "Spusť jako root."
  exit 1
fi

declare -A rules=(
  [usepam]="no"
  [passwordauthentication]="no"
)

ok=1

for key in "${!rules[@]}"; do
  want="${rules[$key]}"
  cur=$(sshd -T 2>/dev/null | awk -v k="$key" '$1==k {print $2}')

  if [ "$cur" = "$want" ]; then
    echo "[OK]   $key = $cur"
  else
    echo "[FAIL] $key = $cur (očekáváno: $want)"
    ok=0
  fi
done

if [ "$ok" -eq 1 ]; then
  echo "SSH je nastavené podle požadavků (jen klíče)."
  exit 0
else
  echo "SSH NENÍ nastavené správně."
  exit 1
fi
