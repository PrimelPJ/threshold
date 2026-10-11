<#
    03-join-domain.ps1
    Points client01 at the DC for DNS and joins it to lab.local.
    Args: <domain> <dc-ip>
#>

param(
    [string]$DomainName = "lab.local",
    [string]$DcIp       = "10.0.10.10"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Pointing DNS at the domain controller ($DcIp) ..."
$iface = Get-NetAdapter | Where-Object {
    $_.Status -eq "Up" -and $_.Name -like "*2*"  # the host-only adapter
} | Select-Object -First 1
if (-not $iface) {
    $iface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
}
Set-DnsClientServerAddress -InterfaceIndex $iface.ifIndex -ServerAddresses $DcIp

if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "==> Already domain-joined. Nothing to do."
    return
}

Write-Host "==> Joining $DomainName ..."
$user = "LAB\Administrator"
$pass = ConvertTo-SecureString "vagrant" -AsPlainText -Force  # built-in box admin pw
$cred = New-Object System.Management.Automation.PSCredential($user, $pass)

# Retry: the DC may still be finishing its first boot.
for ($i = 1; $i -le 10; $i++) {
    try {
        Add-Computer -DomainName $DomainName -Credential $cred -Force -ErrorAction Stop
        Write-Host "==> Joined. Rebooting."
        Restart-Computer -Force
        return
    } catch {
        Write-Host "    attempt $i failed, waiting 30s ... ($($_.Exception.Message))"
        Start-Sleep -Seconds 30
    }
}
throw "Could not join the domain after 10 attempts."
