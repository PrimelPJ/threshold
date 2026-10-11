<#
    verify-defenses.ps1
    Run on the DC (vagrant ssh is winrm, so use the console or:
      vagrant winrm dc01 -c "powershell -File C:\vagrant\scripts\verify-defenses.ps1")
    Shows the current state of the brute force defenses and recent attack events.
#>

Write-Host "=== Account lockout policy ===" -ForegroundColor Cyan
Get-ADDefaultDomainPasswordPolicy |
    Select-Object LockoutThreshold, LockoutDuration, LockoutObservationWindow,
                  ComplexityEnabled, MinPasswordLength | Format-List

Write-Host "=== Currently locked-out accounts ===" -ForegroundColor Cyan
$locked = Search-ADAccount -LockedOut
if ($locked) { $locked | Select-Object Name, SamAccountName | Format-Table -AutoSize }
else { Write-Host "  none" }

Write-Host "=== Audit policy (logon / lockout) ===" -ForegroundColor Cyan
auditpol /get /subcategory:"Logon","Account Lockout"

Write-Host "=== Last 15 failed logons (4625) ===" -ForegroundColor Cyan
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents 15 -ErrorAction SilentlyContinue |
    ForEach-Object {
        $x = [xml]$_.ToXml()
        $user = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' })."#text"
        $ip   = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' })."#text"
        "{0}  user={1,-14} src={2}" -f $_.TimeCreated, $user, $ip
    }

Write-Host "`n=== Firewall blocks placed by Wazuh active response ===" -ForegroundColor Cyan
$fw = Get-NetFirewallRule -DisplayName "WAZUH-AR Block*" -ErrorAction SilentlyContinue
if ($fw) { $fw | Select-Object DisplayName, Enabled, Action | Format-Table -AutoSize }
else { Write-Host "  none yet" }
