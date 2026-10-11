<#
    reset-lab.ps1
    Run on the DC to reset state between test runs:
      - unlock every locked account
      - remove any firewall blocks Wazuh active response placed
    Lets you re-run the attack scripts from a clean slate without a full rebuild.
#>

Write-Host "==> Unlocking all locked-out accounts ..."
Search-ADAccount -LockedOut | ForEach-Object {
    Unlock-ADAccount -Identity $_.SamAccountName
    Write-Host "    unlocked $($_.SamAccountName)"
}

Write-Host "==> Removing Wazuh active-response firewall blocks ..."
Get-NetFirewallRule -DisplayName "WAZUH-AR Block*" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-NetFirewallRule -DisplayName $_.DisplayName
    Write-Host "    removed $($_.DisplayName)"
}

Write-Host "==> Lab reset. Ready for another attack run."
