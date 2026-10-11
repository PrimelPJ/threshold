<#
    01-install-ad.ps1
    Installs the AD DS role and promotes dc01 into a new forest, lab.local.
    Runs once, then Vagrant reboots the box.
#>

$ErrorActionPreference = "Stop"

$DomainName   = "lab.local"
$NetbiosName  = "LAB"
# Lab-only DSRM password. This is a throwaway isolated environment.
$SafeModePass = ConvertTo-SecureString "L@bRecovery2026!" -AsPlainText -Force

Write-Host "==> Setting a static DNS pointer to self (loopback) ..."
# The DC resolves itself; clients get pointed at 10.0.10.10 when they join.
$iface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
         Sort-Object ifIndex | Select-Object -First 1

Write-Host "==> Installing AD DS and DNS roles ..."
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

Write-Host "==> Promoting to domain controller for $DomainName ..."
Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -SafeModeAdministratorPassword $SafeModePass `
    -InstallDns `
    -DomainMode "WinThreshold" `
    -ForestMode "WinThreshold" `
    -NoRebootOnCompletion `
    -Force

Write-Host "==> Promotion staged. Vagrant will reboot to finish."
