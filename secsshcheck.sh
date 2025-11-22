#!/bin/sh

[ "$USER" = root ] || { echo "Spusť jako root"; exit 1; }

ok=1
for k in usepam passwordauthentication; do
  v=$(sshd -T 2>/dev/null | awk -v k="$k" '$1==k{print $2}')
  if [ "$v" = "no" ]; then
    echo "🟢 [OK]   $k=$v"
  else
    echo "🔴 [FAIL] $k=${v:-není} (oček:no)"
    ok=0
  fi
done

[ "$ok" -eq 1 ] && echo "🟢 SSH OK (jen klíče)" || echo "🔴 SSH NENÍ OK"
exit "$ok"
