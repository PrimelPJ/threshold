#!/usr/bin/env bash
#
# 07-setup-kali.sh
# Prepares the Kali attacker box: makes sure the spray tooling is present
# and drops the lab's attack scripts + wordlists into the vagrant user's home.
#
set -euo pipefail

echo "==> Ensuring attack tooling is installed ..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq || true
# crackmapexec/netexec is the workhorse for SMB password spraying.
apt-get install -y netexec crackmapexec python3-impacket 2>/dev/null || \
    apt-get install -y crackmapexec python3-impacket 2>/dev/null || true

echo "==> Copying attack scripts into /home/vagrant/attack ..."
mkdir -p /home/vagrant/attack
cp /vagrant/scripts/attack/* /home/vagrant/attack/ 2>/dev/null || true
chown -R vagrant:vagrant /home/vagrant/attack
chmod +x /home/vagrant/attack/*.sh 2>/dev/null || true

echo "==> Kali ready. SSH in and run the attack scripts:"
echo "      vagrant ssh kali"
echo "      cd attack && ./01-spray.sh"
