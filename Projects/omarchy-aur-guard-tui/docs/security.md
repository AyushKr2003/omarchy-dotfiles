# Security Engine

## Overview

The security engine (`scanner.py`) analyzes AUR packages through three layers:
1. **Reputation scoring** - AUR metadata analysis
2. **Pattern matching** - Regex-based code analysis
3. **Change detection** - PKGBUILD diff tracking

## Scan Pipeline

```
full_scan(pkgname)
  │
  ├─► aur_info(pkgname)          Fetch AUR metadata via RPC API
  │     └─► https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=<pkg>
  │
  ├─► score_pkg(info)            Calculate reputation score (0-100)
  │
  ├─► fetch_pkgbuild(pkgname)    Fetch PKGBUILD from cgit
  │     └─► https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=<pkg>
  │
  ├─► analyze(pb, "PKGBUILD")    Regex pattern matching
  │
  ├─► fetch_install(pkgname)     Fetch .install file (if exists)
  │
  ├─► analyze(inst, ".install")  Regex pattern matching
  │
  ├─► Cache comparison           Detect PKGBUILD changes
  │
  └─► verdict(score, findings)   Combine into final verdict
```

## Reputation Scoring

`score_pkg(info)` returns a score 0-100 with reasons:

| Condition | Points | Reason |
|-----------|--------|--------|
| Known malicious maintainer | +50 | "Maintainer is a known malicious account" |
| Orphaned (no maintainer) | +25 | "Package is ORPHANED" |
| < 7 days old | +20 | "Very new -- submitted N days ago" |
| < 30 days old | +10 | "Recently submitted -- N days ago" |
| Old package updated recently | +15 | "Old package updated N days ago" |
| Zero votes on old package | +10 | "Zero votes on old package" |
| Few votes on old package | +5 | "Only N votes after N days" |
| Flagged out-of-date | +5 | "Flagged out-of-date" |

Known malicious accounts:
- `xeactor`
- `custodiatovar`
- `veramagalhaes`
- `franziskaweber`
- `tobiaswesterburg`
- `ellenmyklebust`

## Pattern Matching Rules

30+ regex patterns detecting malicious code in PKGBUILD files:

### CRITICAL Severity
| Pattern | Description |
|---------|-------------|
| `curl ... \| bash/sh/zsh` | Remote exec: curl piped to shell |
| `wget -O - \| bash/sh` | Remote exec: wget piped to shell |
| `npm install` | Atomic Arch 2026 attack vector |
| `bun install` | Atomic Arch Wave 2 vector |
| Paste site downloads | xeactor 2018 attack pattern |

### HIGH Severity
| Pattern | Description |
|---------|-------------|
| `pip install` | Cross-ecosystem injection |
| `cargo install` | Rust package install in PKGBUILD |
| `base64 --decode` | Obfuscation via base64 |
| `eval` of non-literal | Code obfuscation |
| Long hex escapes | Encoded payload |
| `cd /tmp &&` | Execution from /tmp |
| Running binary from /tmp | Temp directory execution |
| `chmod +x /tmp/` | Making /tmp binary executable |
| `crontab -` | Crontab modification (persistence) |
| `.ssh/` access | SSH directory access |
| Browser profile access | Chrome/Firefox/Edge profile access |
| Secret env vars | GitHub/NPM/AWS token references |
| ngrok tunnels | C2 exfiltration |
| eBPF references | Rootkit indicator |

### MEDIUM Severity
| Pattern | Description |
|---------|-------------|
| `systemctl enable/start` | Enabling systemd service |
| Shell RC writes | .bashrc/.profile/.zshrc modification |
| Hardcoded IP addresses | Network indicators |
| Kernel module loading | insmod/modprobe |

### Known Malicious Packages
- `atomic-lockfile`
- `lockfile-js`
- `js-digest`

## Verdict Calculation

```python
verdict(score, findings):
    total = score + (critical_count * 30) + (high_count * 15)
    
    if total >= 75 or critical_count > 0:  → CRITICAL
    if total >= 50 or high_count > 0:      → HIGH
    if total >= 25 or any findings:         → MEDIUM
    otherwise:                              → CLEAN
```

## Verdict Levels

| Verdict | Meaning |
|---------|---------|
| `CRITICAL` | High risk. Do not install without manual review. |
| `HIGH` | Significant concerns. Review findings carefully. |
| `MEDIUM` | Some flags. Check details before installing. |
| `CLEAN` | No suspicious patterns detected. |
| `UNKNOWN` | Scan not yet completed. |

## Caching

- Cache directory: `~/.cache/aur-guard/`
- Per-package cache: `{pkgname}.json` with SHA256 hash + full PKGBUILD content
- Change detection: Compare current hash with cached hash
- Diff tracking: Show new/changed lines when PKGBUILD changes

## AUR API

- **Info endpoint**: `https://aur.archlinux.org/rpc/?v=5&type=info&arg[]={pkg}`
- **PKGBUILD**: `https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg}`
- **Install file**: `https://aur.archlinux.org/cgit/aur.git/plain/{pkg}.install?h={pkg}`
- **User-Agent**: `aur-guard/2.0`
- **Timeout**: 10 seconds (8 for install files)
