# MITRE ATT&CK Mapping

Detection rules and their corresponding MITRE ATT&CK techniques.

| Rule | Technique | Tactic | Description |
|------|-----------|--------|-------------|
| Brute Force (4625) | T1110.001 | Credential Access | Password guessing against single account |
| Password Spray (4625) | T1110.003 | Credential Access | Single password across many accounts |
| Account Lockout (4740) | T1110 | Credential Access | Lockout from repeated failures |
| Kerberoasting (4769) | T1558.003 | Credential Access | TGS request for service account SPNs |
| Lateral Movement (4624) | T1550.002 | Lateral Movement | Pass-the-hash NTLM authentication |
| Active Response Block | - | Response | Automated IP block via active response |

## Coverage gaps

- **T1087** Account Discovery — not yet detected
- **T1003** OS Credential Dumping — requires Sysmon integration
- **T1059** Command and Scripting Interpreter — requires PowerShell logging
