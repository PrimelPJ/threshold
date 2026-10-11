#!/usr/bin/env bash
#
# 06-configure-wazuh.sh
# Installs the custom brute force rules and wires up the active-response
# command that blocks a spraying IP on the DC. Runs on the wazuh VM.
#
set -euo pipefail

RULES_SRC="/vagrant/wazuh/rules/local_rules.xml"
RULES_DST="/var/ossec/etc/rules/local_rules.xml"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

echo "==> Installing custom brute force rules ..."
cp "$RULES_SRC" "$RULES_DST"
chown wazuh:wazuh "$RULES_DST"
chmod 660 "$RULES_DST"

# ---------------------------------------------------------------------------
# Register the active-response command + trigger, if not already present.
# The command name 'block-bruteforce-ip' maps to the PowerShell script that
# the Windows agent runs. Triggered by rule 100140 (sustained spray).
# ---------------------------------------------------------------------------
if ! grep -q "block-bruteforce-ip" "$OSSEC_CONF"; then
    echo "==> Adding active-response block to ossec.conf ..."
    # Insert before the closing </ossec_config> tag.
    AR_BLOCK=$(cat <<'XML'

  <!-- Active response: block a brute force source IP on the affected Windows host -->
  <command>
    <name>block-bruteforce-ip</name>
    <executable>block-ip.ps1</executable>
    <timeout_allowed>yes</timeout_allowed>
  </command>

  <active-response>
    <command>block-bruteforce-ip</command>
    <location>local</location>
    <rules_id>100140</rules_id>
    <timeout>600</timeout>
  </active-response>

XML
)
    # Write everything up to the last </ossec_config>, then the block, then the tag.
    python3 - "$OSSEC_CONF" <<PYEOF
import sys
path = sys.argv[1]
block = """$AR_BLOCK"""
with open(path) as f:
    content = f.read()
marker = "</ossec_config>"
idx = content.rfind(marker)
content = content[:idx] + block + "\n" + content[idx:]
with open(path, "w") as f:
    f.write(content)
PYEOF
else
    echo "==> Active response already configured."
fi

echo "==> Restarting the Wazuh manager to load rules and active response ..."
systemctl restart wazuh-manager

echo "==> Done. Rules 100100-100140 live; AR 'block-bruteforce-ip' armed on rule 100140."
