# Threshold

An Active Directory brute force defense lab. A small, self-contained lab that builds a Windows Active Directory domain, attacks it with password spraying and brute force, and catches and blocks the attack with a Wazuh SIEM. Everything runs on your own machine with Vagrant and VirtualBox. No cloud account, no cost.

The point of the lab is the defense side: an account lockout policy, logon auditing, custom SIEM rules, and an automatic firewall block that kicks in when an attacker keeps spraying.

## What gets built

Four virtual machines on one isolated network (`10.0.10.0/24`):

| VM | Address | Role |
|----|---------|------|
| `dc01` | 10.0.10.10 | Windows Server 2022, domain controller for `lab.local` |
| `client01` | 10.0.10.11 | Windows 10, joined to the domain |
| `wazuh` | 10.0.10.20 | Ubuntu, runs the Wazuh SIEM and dashboard |
| `kali` | 10.0.10.30 | Kali Linux, the attacker box |

The network is host-only, so none of this touches the internet or any real network.

## What you need

- VirtualBox
- Vagrant
- About 14 GB of free RAM for all four VMs at once (you can run fewer, see below)
- Roughly 40 GB of free disk

## Setup

```bash
git clone https://github.com/PrimelPJ/threshold.git
cd threshold
vagrant up
```

The first run downloads the VM images and provisions everything, so it takes a while. Order matters, so if you bring boxes up one at a time, start with `wazuh`, then `dc01`, then `client01`, then `kali`.

Tight on memory? Bring up just `wazuh`, `dc01`, and `kali`. The client is only there to make the domain feel real; the attack and defense work without it.

## How the defense works

There are two layers.

**1. Account lockout policy (on the DC).** After 5 wrong passwords in 15 minutes, the account locks for 15 minutes. This alone turns an unlimited guessing attack into a slow crawl, and every lockout writes a `4740` event that the SIEM watches.

**2. Wazuh SIEM (detection and response).** The Windows agents on `dc01` and `client01` ship their Security logs to the Wazuh manager. Custom rules look for the patterns:

| Rule | What it catches | Level |
|------|-----------------|-------|
| 100100 | A single failed logon (`4625`) | 3 |
| 100110 | 8+ failures against one account in 2 min (brute force) | 10 |
| 100120 | 10+ failures from one IP in 2 min (password spray) | 12 |
| 100130 | An account got locked out (`4740`) | 10 |
| 100140 | Sustained spray from one IP, triggers the block | 13 |

When rule 100140 fires, Wazuh active response runs a script on the DC that adds a Windows Firewall rule blocking the attacker's IP for 10 minutes. The attack stops itself.

## Running the attack

SSH into Kali and run the scripts:

```bash
vagrant ssh kali
cd attack

# Password spray: one password across all users, then the next.
# Stays under the lockout limit but trips the spray rules.
./01-spray.sh

# Brute force one account hard. This locks the account on purpose.
./02-bruteforce-single.sh jsmith
```

The spray uses weak passwords that match a couple of the lab accounts, so you will see a real hit land as well as the detections fire.

## Watching the defense

Open the Wazuh dashboard at `https://10.0.10.20` (self-signed cert, so you have to accept the warning). Get the admin password with:

```bash
vagrant ssh wazuh -c "sudo cat /root/wazuh-passwords.txt"
```

Under Security events, filter on rule IDs 100110 through 100140 to see the attack as the SIEM sees it.

On the DC you can check the defenses directly:

```powershell
# shows lockout policy, locked accounts, recent failed logons, and firewall blocks
C:\vagrant\scripts\verify-defenses.ps1
```

## Resetting between runs

After an attack run, accounts may be locked and the attacker IP may be firewalled. Clear both on the DC:

```powershell
C:\vagrant\scripts\reset-lab.ps1
```

Then you can spray again from a clean state.

## Tearing it down

```bash
vagrant destroy -f
```

## Lab accounts

These are fake accounts with deliberately weak passwords so the attack has something to find. They exist only inside the isolated network.

| User | Password | Note |
|------|----------|------|
| jsmith | Summer2026! | staff |
| mgarcia | P@ssw0rd123 | staff, Finance |
| dlee | Welcome1! | staff, Helpdesk |
| achen | Calgary2026 | staff, Helpdesk |
| rpatel | Autumn#2026 | staff |
| svc_backup | B@ckupSvc!99 | service account |

## Layout

```
.
├── Vagrantfile                 # defines the four VMs and their provisioning order
├── provision/                  # scripts Vagrant runs to build each box
│   ├── 01-install-ad.ps1       #   promote dc01 to a domain controller
│   ├── 02-populate-ad.ps1      #   users, groups, lockout policy, audit policy
│   ├── 03-join-domain.ps1      #   join client01 to the domain
│   ├── 04-install-wazuh-agent.ps1
│   ├── 05-install-wazuh-manager.sh
│   ├── 06-configure-wazuh.sh   #   install custom rules + active response
│   └── 07-setup-kali.sh
├── wazuh/
│   ├── rules/local_rules.xml   # the brute force / spray detection rules
│   └── active-response/block-ip.ps1   # firewall block script run on the DC
├── scripts/
│   ├── attack/                 # spray and brute force scripts + wordlists
│   ├── verify-defenses.ps1
│   └── reset-lab.ps1
└── docs/
    └── walkthrough.md          # step-by-step run with what to expect
```

## A note on scope

This lab is for learning blue-team defense on a network you own and control. The attack scripts only work against the lab's own VMs on the isolated host-only network. Do not point them at anything else.

## License

MIT, see [LICENSE](LICENSE). Copyright (c) 2026 Primel Jayawardana.
