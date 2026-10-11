<#
    04-install-wazuh-agent.ps1
    Installs the Wazuh agent on a Windows box and registers it with the manager.
    Args: <manager-ip> <agent-name>
#>

param(
    [string]$ManagerIp = "10.0.10.20",
    [string]$AgentName = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"
$version = "4.9.0-1"
$msi     = "$env:TEMP\wazuh-agent.msi"
$url     = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$version.msi"

if (Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue) {
    Write-Host "==> Wazuh agent already installed."
    return
}

Write-Host "==> Downloading Wazuh agent $version ..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing

Write-Host "==> Installing and registering with manager $ManagerIp as '$AgentName' ..."
Start-Process msiexec.exe -ArgumentList @(
    "/i `"$msi`"", "/q",
    "WAZUH_MANAGER=$ManagerIp",
    "WAZUH_AGENT_NAME=$AgentName",
    "WAZUH_REGISTRATION_SERVER=$ManagerIp"
) -Wait

Write-Host "==> Starting the agent service ..."
Start-Service WazuhSvc
Set-Service  WazuhSvc -StartupType Automatic

Write-Host "==> Agent up. It will start shipping Security log events to Wazuh."
