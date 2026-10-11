# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Threshold - Active Directory Brute Force Defense Lab
# Copyright (c) 2026 Primel Jayawardana
#
# Four VMs on an isolated host-only network (10.0.10.0/24):
#   dc01     - Windows Server 2022, Domain Controller for lab.local
#   client01 - Windows 10, domain-joined workstation
#   wazuh    - Ubuntu 22.04, Wazuh SIEM (manager + dashboard)
#   kali     - Kali Linux, attacker box
#
# Bring the whole lab up in order:   vagrant up
# Bring up one box:                   vagrant up dc01
# Tear it all down:                   vagrant destroy -f

Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 600
  config.ssh.insert_key = false

  # ---------------------------------------------------------------
  # Domain Controller
  # ---------------------------------------------------------------
  config.vm.define "dc01" do |dc|
    dc.vm.box = "gusztavvargadr/windows-server-2022-standard"
    dc.vm.hostname = "dc01"
    dc.vm.network "private_network", ip: "10.0.10.10"
    dc.vm.communicator = "winrm"
    dc.winrm.username = "vagrant"
    dc.winrm.password = "vagrant"

    dc.vm.provider "virtualbox" do |vb|
      vb.name   = "lab-dc01"
      vb.memory = 4096
      vb.cpus   = 2
      vb.gui    = false
    end

    # Step 1: promote to DC and reboot
    dc.vm.provision "promote", type: "shell",
      path: "provision/01-install-ad.ps1",
      reboot: true

    # Step 2: build OUs, users, groups, audit policy, lockout GPO
    dc.vm.provision "populate", type: "shell",
      path: "provision/02-populate-ad.ps1"

    # Step 3: install Wazuh agent pointed at the manager
    dc.vm.provision "agent", type: "shell",
      path: "provision/04-install-wazuh-agent.ps1",
      args: ["10.0.10.20", "dc01"]
  end

  # ---------------------------------------------------------------
  # Domain-joined client
  # ---------------------------------------------------------------
  config.vm.define "client01" do |client|
    client.vm.box = "gusztavvargadr/windows-10-enterprise"
    client.vm.hostname = "client01"
    client.vm.network "private_network", ip: "10.0.10.11"
    client.vm.communicator = "winrm"
    client.winrm.username = "vagrant"
    client.winrm.password = "vagrant"

    client.vm.provider "virtualbox" do |vb|
      vb.name   = "lab-client01"
      vb.memory = 2048
      vb.cpus   = 2
      vb.gui    = false
    end

    client.vm.provision "join", type: "shell",
      path: "provision/03-join-domain.ps1",
      args: ["lab.local", "10.0.10.10"]

    client.vm.provision "agent", type: "shell",
      path: "provision/04-install-wazuh-agent.ps1",
      args: ["10.0.10.20", "client01"]
  end

  # ---------------------------------------------------------------
  # Wazuh SIEM
  # ---------------------------------------------------------------
  config.vm.define "wazuh" do |wazuh|
    wazuh.vm.box = "bento/ubuntu-22.04"
    wazuh.vm.hostname = "wazuh"
    wazuh.vm.network "private_network", ip: "10.0.10.20"

    wazuh.vm.provider "virtualbox" do |vb|
      vb.name   = "lab-wazuh"
      vb.memory = 6144
      vb.cpus   = 2
      vb.gui    = false
    end

    wazuh.vm.provision "install", type: "shell",
      path: "provision/05-install-wazuh-manager.sh"

    # Drop in the custom brute force rules and active response config
    wazuh.vm.provision "rules", type: "shell",
      path: "provision/06-configure-wazuh.sh"
  end

  # ---------------------------------------------------------------
  # Kali attacker
  # ---------------------------------------------------------------
  config.vm.define "kali" do |kali|
    kali.vm.box = "kalilinux/rolling"
    kali.vm.hostname = "kali"
    kali.vm.network "private_network", ip: "10.0.10.30"

    kali.vm.provider "virtualbox" do |vb|
      vb.name   = "lab-kali"
      vb.memory = 2048
      vb.cpus   = 2
      vb.gui    = false
    end

    kali.vm.provision "tools", type: "shell",
      path: "provision/07-setup-kali.sh"
  end
end
