<#
    block-ip.ps1
    Wazuh active-response script for Windows.
    When rule 100140 fires, the manager tells the agent on the DC to run this
    with the offending IP. It adds (or removes, on timeout) a Windows Firewall
    rule that drops all inbound traffic from that IP.

    Wazuh passes a JSON blob on stdin containing command ("add"/"delete") and
    the parameters.alert.data.srcip extracted from the triggering event.

    Install path on the agent:
      C:\Program Files (x86)\ossec-agent\active-response\bin\block-ip.ps1
#>

$ErrorActionPreference = "Stop"
$LogFile = "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"

function Write-Log($msg) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "$ts block-ip.ps1: $msg"
}

# Read the JSON that Wazuh pipes in.
$raw = [Console]::In.ReadToEnd()
try {
    $input = $raw | ConvertFrom-Json
} catch {
    Write-Log "could not parse stdin: $raw"
    exit 1
}

$command = $input.command
$srcip   = $input.parameters.alert.data.srcip
$ruleName = "WAZUH-AR Block $srcip"

if (-not $srcip -or $srcip -eq "0.0.0.0") {
    Write-Log "no usable srcip in alert, nothing to do"
    exit 0
}

switch ($command) {
    "add" {
        if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $ruleName `
                -Direction Inbound -Action Block `
                -RemoteAddress $srcip -Profile Any | Out-Null
            Write-Log "BLOCKED $srcip (brute force source)"
        } else {
            Write-Log "$srcip already blocked"
        }
    }
    "delete" {
        if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName $ruleName
            Write-Log "UNBLOCKED $srcip (active response timeout)"
        }
    }
    default {
        Write-Log "unknown command '$command'"
    }
}
exit 0
