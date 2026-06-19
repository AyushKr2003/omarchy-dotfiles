# aur-guard v3.0

<p align="center">
  <b>AUR Security Scanner TUI for Arch Linux</b><br>
  <sub>Comprehensive static analysis of AUR packages before installation</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/python-3.10+-blue.svg?style=flat-square">
  <img src="https://img.shields.io/badge/textual-0.50+-blue.svg?style=flat-square">
  <img src="https://img.shields.io/badge/license-MIT-green.svg?style=flat-square">
</p>

---

## Features

### Security Scanning Engine
- **40+ security rules** across 10 attack categories:
  - Remote code execution (curl | sh, eval, etc.)
  - Package manager abuse (npm, pip, cargo, go, gem, composer install)
  - Obfuscation (base64, hex escapes, inline python/perl)
  - Persistence (crontab, shell RC modification, systemd)
  - Privilege escalation (sudo, setcap, chmod +s, chown root)
  - Credential theft (.ssh, browser profiles, password stores, env vars)
  - Network exfiltration (pastebin, ngrok, webhooks, netcat)
  - Kernel/eBPF manipulation (insmod, bpftool, /dev/mem)
  - Supply chain (git submodules, docker, LD_PRELOAD)
  - Anomaly detection (excessive length, missing checksums, new accounts)

- **Source URL Analysis**: Detects HTTP vs HTTPS, hardcoded IPs, localhost references, suspicious domains
- **Checksum Verification**: Flags packages without integrity validation
- **Dependency Analysis**: Identifies AUR vs official repository dependencies
- **Maintainer Reputation**: Scans known malicious accounts, orphan detection, account age analysis
- **Change Detection**: Caches PKGBUILD hashes and warns when packages change between scans
- **Compromise Checks**: Detects already-installed risk-listed AUR packages, pacman log hits,
  suspicious systemd persistence, eBPF traces, `/etc/ld.so.preload`, hidden processes,
  and malicious npm/bun cache residue
- **Threat Lists**: Loads local copies of `aur-malware-check/package_list.txt` and
  `malicious_npm_packages.txt` when this dotfiles workspace is present, with
  `AUR_GUARD_PACKAGE_LIST` / `AUR_GUARD_MALICIOUS_NPM_LIST` overrides
- **Infected Package Flagging**: Any package added, scanned, or batch-scanned
  from the TUI is marked CRITICAL when its exact name appears in the infected
  package list, even if AUR metadata is unavailable

### Report Generation
- **JSON**: Machine-readable full data export
- **HTML**: Interactive color-coded report with severity badges, score bars, findings tables
- **Markdown**: GitHub-compatible reports for issues/documentation
- **Text**: Terminal-friendly plain text output
- **Scan History**: Persistent log of all scans for trend analysis

### TUI Interface
- **Vim keybindings**: j/k navigation, g/G for top/bottom, / for search
- **JetBrainsMono Nerd Font**: Full icon support for severity indicators
- **Omarchy Theme Integration**: Reads colors from `~/.local/state/omarchy/current/theme/`
- **Tabbed Results**: Overview | Findings | PKGBUILD (with line highlighting) | Changes
- **Batch Scanning**: Scan all installed AUR packages with progress overlay
- **Terminal Size Guard**: Warns when terminal is too small

---

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Launch TUI
python run.py

# Scan specific packages
python run.py firefox-nightly visual-studio-code-bin

# Scan all installed AUR packages
python run.py -i

# Preload packages + scan installed
python run.py firefox-nightly -i
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate package list |
| `g` / `G` | Jump to top / bottom |
| `/` | Filter/search packages |
| `a` | Add package (focuses input) |
| `r` | Rescan current package |
| `S` | Scan all installed AUR packages |
| `C` | Run local compromise / IoC check |
| `d` | Remove package from list |
| `e` | Export JSON report |
| `E` | Export HTML report |
| `Ctrl+H` | Toggle help overlay |
| `Esc` | Dismiss overlays / unfocus |
| `q` / `Ctrl+C` | Quit |

---

## Scoring System

Packages are scored 0-100 based on reputation and code analysis:

| Factor | Points | Condition |
|--------|--------|-----------|
| Known malicious maintainer | +50 | Maintainer in threat intel DB |
| Orphaned package | +25 | No active maintainer |
| New maintainer | +15 | Account < 30 days old |
| Package age < 7 days | +20 | Brand new package |
| Package age < 30 days | +10 | Recently submitted |
| Sudden update | +15 | Old pkg updated recently |
| Zero votes (old) | +10 | No community trust |
| Low votes | +5 | < 5 votes after 1 year |
| Out-of-date | +5 | Flagged stale |
| **CRITICAL finding** | **+30** | Any critical rule match |
| **HIGH finding** | **+15** | Any high rule match |

### Verdict Thresholds

| Total Score | Verdict | Color |
|-------------|---------|-------|
| >= 75 or any CRITICAL | CRITICAL | Red |
| >= 50 or any HIGH | HIGH | Orange |
| >= 25 or any finding | MEDIUM | Yellow |
| < 25, clean | CLEAN | Green |

---

## Architecture

```
aur_guard/
  __init__.py      # Package exports, lazy imports
  __main__.py      # CLI entry point, argument parsing
  app.py           # Main Textual TUI application
  scanner.py       # Security engine (rules, scoring, AUR API)
  views.py         # TUI views (Welcome, Loading, Scan results)
  widgets.py       # Custom widgets (PkgItem sidebar row)
  css.py           # Textual CSS styles
  theme.py         # Omarchy theme loader
  icons.py         # Nerd Font icon constants
run.py             # Simple launcher script
```

---

## Requirements

- Python 3.10+
- Textual 0.50+
- JetBrainsMono Nerd Font (for icons)
- Arch Linux with `pacman` (for `-i` flag and dependency analysis)
- Omarchy theme files (optional, falls back to Tokyo Night)

---

## Security Note

aur-guard performs **static analysis only** — it does not execute PKGBUILDs or install packages. It cannot detect all forms of malicious code (e.g., obfuscated payloads that evade regex patterns, runtime-only behavior). Always review PKGBUILDs manually for packages with MEDIUM+ verdicts.

---

## License

MIT
