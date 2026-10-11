# Walkthrough: attack and defense, start to finish

This runs the whole lab once and tells you what to expect at each step. Give yourself an hour the first time, mostly waiting on downloads.

## 1. Build the lab

```bash
vagrant up
```

Watch for these in the output:

- `dc01` installs AD, reboots, then creates users and the lockout policy.
- `wazuh` runs the all-in-one installer (slow) and loads the custom rules.
- Each Windows box installs the Wazuh agent and registers with the manager.

When it finishes, confirm the agents are connected. On the Wazuh dashboard (`https://10.0.10.20`), go to Agents. You should see `dc01` and `client01` as Active.

## 2. Confirm the defenses are in place

From the DC console (or `vagrant winrm dc01 -c "..."`):

```powershell
C:\vagrant\scripts\verify-defenses.ps1
```

You want to see a lockout threshold of 5 and audit policy enabled for Logon and Account Lockout. No locked accounts and no firewall blocks yet.

## 3. Run a password spray

```bash
vagrant ssh kali
cd attack
./01-spray.sh
```

What happens: the script tries one password against every user, waits, then tries the next password. Because it only sends one guess per account per round, it stays under the 5-attempt lockout. One password (`Summer2026!`) is `jsmith`'s real password, so you will see a `[+]` success line for that pair.

Meanwhile on the SIEM:

- Each failed logon is rule 100100.
- Once 10 failures from `10.0.10.30` stack up inside 2 minutes, rule 100120 (password spray) fires at level 12.
- Keep the spray going and rule 100140 fires at level 13, which triggers the block.

## 4. Watch the block land

After 100140 fires, the DC gets told to firewall the attacker. Back on the DC:

```powershell
C:\vagrant\scripts\verify-defenses.ps1
```

Under the firewall section you should now see `WAZUH-AR Block 10.0.10.30`. From Kali, the spray will start timing out because the DC is dropping its traffic. The block lifts itself after 10 minutes.

You can also read the active-response log on the DC:

```
C:\Program Files (x86)\ossec-agent\active-response\active-responses.log
```

Look for a `BLOCKED 10.0.10.30` line.

## 5. See the lockout policy defend a single account

```bash
./02-bruteforce-single.sh jsmith
```

This throws many passwords at one account fast, crossing the 5-attempt threshold. The account locks, which:

- writes a `4740` event,
- fires rule 100130 in Wazuh,
- stops any further guessing because the account is locked for 15 minutes.

Confirm on the DC:

```powershell
Get-ADUser jsmith -Properties LockedOut | Select Name, LockedOut
```

## 6. Reset and try again

```powershell
C:\vagrant\scripts\reset-lab.ps1
```

This unlocks accounts and removes the firewall blocks so you can run the attacks again from a clean state.

## What to take away

- The lockout policy is cheap and stops brute force against one account cold, but a careful spray stays under it.
- Catching the spray needs log analysis across accounts, which is the SIEM's job.
- Active response closes the loop: detection becomes an automatic block without a human in the middle.

## Troubleshooting

**Agents show Disconnected.** The manager may still have been starting when the agent registered. On the Windows box: `Restart-Service WazuhSvc`.

**No events in the dashboard.** Check the DC is actually auditing: `auditpol /get /subcategory:"Logon"`. Both success and failure should be enabled. The `02-populate-ad.ps1` script sets this, so a failure here usually means that step did not finish.

**Rules not firing but events are arriving.** Confirm the custom rules loaded: on the wazuh VM, `sudo /var/ossec/bin/wazuh-logtest` and paste a sample `4625` event, or check `/var/ossec/logs/ossec.log` for rule-load errors after the restart in `06-configure-wazuh.sh`.

**The spray never trips 100140.** The timeframe windows are 2 minutes. If your VMs are slow, the failures may spread out too far. Lower the `sleep` in `01-spray.sh` or raise the `timeframe` values in `local_rules.xml`.
