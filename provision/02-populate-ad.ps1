<#
    02-populate-ad.ps1
    Builds the lab directory after promotion:
      - OUs for staff and service accounts
      - a handful of users with weak, guessable passwords (on purpose, lab only)
      - a few groups
      - an account lockout policy (the first line of brute force defense)
      - audit policy so failed logons (4625) and lockouts (4740) are logged
    Idempotent: safe to re-run.
#>

$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

$Domain   = "lab.local"
$BaseDN   = "DC=lab,DC=local"

# ----------------------------------------------------------------------
# Organizational Units
# ----------------------------------------------------------------------
function Ensure-OU($name, $path) {
    $dn = "OU=$name,$path"
    if (-not (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$dn'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false
        Write-Host "    created OU $dn"
    }
}

Write-Host "==> Creating OUs ..."
Ensure-OU "Lab"      $BaseDN
Ensure-OU "Staff"    "OU=Lab,$BaseDN"
Ensure-OU "Services" "OU=Lab,$BaseDN"

$StaffOU   = "OU=Staff,OU=Lab,$BaseDN"
$SvcOU      = "OU=Services,OU=Lab,$BaseDN"

# ----------------------------------------------------------------------
# Users. Weak passwords are deliberate so the spray tool finds one.
# Everything here is fake and lives only on the isolated network.
# ----------------------------------------------------------------------
$users = @(
    @{ Sam="jsmith";   Name="John Smith";      Pass="Summer2026!";   OU=$StaffOU },
    @{ Sam="mgarcia";  Name="Maria Garcia";    Pass="P@ssw0rd123";   OU=$StaffOU },
    @{ Sam="dlee";     Name="David Lee";       Pass="Welcome1!";     OU=$StaffOU },
    @{ Sam="achen";    Name="Amy Chen";        Pass="Calgary2026";   OU=$StaffOU },
    @{ Sam="rpatel";   Name="Rohan Patel";     Pass="Autumn#2026";   OU=$StaffOU },
    @{ Sam="svc_backup"; Name="Backup Service"; Pass="B@ckupSvc!99";  OU=$SvcOU }
)

Write-Host "==> Creating users ..."
foreach ($u in $users) {
    $secure = ConvertTo-SecureString $u.Pass -AsPlainText -Force
    if (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue) {
        Set-ADAccountPassword -Identity $u.Sam -NewPassword $secure -Reset
    } else {
        New-ADUser `
            -SamAccountName $u.Sam `
            -UserPrincipalName "$($u.Sam)@$Domain" `
            -Name $u.Name `
            -DisplayName $u.Name `
            -AccountPassword $secure `
            -Path $u.OU `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -ChangePasswordAtLogon $false
        Write-Host "    created user $($u.Sam)"
    }
}

# ----------------------------------------------------------------------
# Groups
# ----------------------------------------------------------------------
Write-Host "==> Creating groups ..."
foreach ($g in @("Helpdesk","Finance")) {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $g -GroupScope Global -Path "OU=Lab,$BaseDN"
    }
}
Add-ADGroupMember -Identity "Helpdesk" -Members "dlee","achen" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Finance"  -Members "mgarcia"       -ErrorAction SilentlyContinue

# ----------------------------------------------------------------------
# DEFENSE 1: Account lockout policy
# After 5 bad passwords in 15 minutes, lock for 15 minutes.
# This is what turns an unlimited brute force into a slow, noisy crawl
# and generates the 4740 lockout events the SIEM keys on.
# ----------------------------------------------------------------------
Write-Host "==> Applying account lockout policy to the default domain policy ..."
Set-ADDefaultDomainPasswordPolicy -Identity $Domain `
    -LockoutThreshold 5 `
    -LockoutDuration (New-TimeSpan -Minutes 15) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 15) `
    -ComplexityEnabled $true `
    -MinPasswordLength 8

# ----------------------------------------------------------------------
# DEFENSE 2: Audit policy
# Make sure failed logons and lockouts are actually written to the
# Security log, so the Wazuh agent can ship them.
# ----------------------------------------------------------------------
Write-Host "==> Enabling audit policy for logon and account lockout events ..."
auditpol /set /subcategory:"Logon"            /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Account Lockout"  /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Kerberos Authentication Service" /success:enable /failure:enable | Out-Null

Write-Host "==> Directory populated. Lab is ready for the attack and detection phase."
