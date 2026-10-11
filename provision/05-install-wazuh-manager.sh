#!/usr/bin/env bash
#
# 05-install-wazuh-manager.sh
# Installs the all-in-one Wazuh stack (manager, indexer, dashboard) on the
# wazuh VM using the official quickstart installer.
#
set -euo pipefail

if systemctl is-active --quiet wazuh-manager 2>/dev/null; then
    echo "==> Wazuh manager already installed."
    exit 0
fi

echo "==> Installing prerequisites ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl gnupg apt-transport-https

echo "==> Running the Wazuh all-in-one installer (this takes a while) ..."
cd /root
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
bash wazuh-install.sh -a -i

echo "==> Saving dashboard credentials to /root/wazuh-passwords.txt ..."
# The installer writes wazuh-install-files.tar; pull the admin password out.
if [ -f /root/wazuh-install-files.tar ]; then
    tar -xf /root/wazuh-install-files.tar -C /root wazuh-install-files/wazuh-passwords.txt 2>/dev/null || true
    cp /root/wazuh-install-files/wazuh-passwords.txt /root/wazuh-passwords.txt 2>/dev/null || true
fi

echo "==> Wazuh manager is up."
echo "    Dashboard:  https://10.0.10.20"
echo "    User:       admin"
echo "    Password:   see /root/wazuh-passwords.txt  (vagrant ssh wazuh -c 'sudo cat /root/wazuh-passwords.txt')"
