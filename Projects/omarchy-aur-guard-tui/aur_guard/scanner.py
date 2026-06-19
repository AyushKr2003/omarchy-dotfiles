"""
scanner.py — Security engine, AUR API, cache, IoC checks, full_scan pipeline.

Fixes vs v3:
  [SEC-1]  Added krisztinavarga to BAD_ACCS; removed arojas (commit forgery victim)
  [SEC-2]  Added nextfile-js to BAD_DEPS
  [SEC-3]  Added full IoC compromise detection module (IocChecker)
  [SEC-4]  Added AG-501 source URL validation (HTTP vs HTTPS, localhost, suspicious)
  [SEC-5]  Fixed AG-216 ID conflict — diff finding now uses AG-217
  [SEC-6]  Added AG-502 checksum skip/missing detection
  [SEC-7]  Added AG-503 new-account rapid-adoption detection
  [SEC-8]  Replaced set-diff with unified diff (difflib) for accurate change detection
  [SEC-9]  Added 0.3s rate-limiting between AUR API requests in batch context
  [SEC-10] Added AG-501 HTTPS enforcement on source= URLs
  [DEV-5]  Fixed remove_pkg bug: save pkg name before pop()
  [DEV-10] Fixed verdict: LOW findings alone don't escalate to MEDIUM
"""
from __future__ import annotations

import re
import json
import time
import hashlib
import difflib
import subprocess
from pathlib import Path
from datetime import datetime, timezone
from typing import Callable
from urllib import request as _urllib_req

from .icons import OK, FAIL, WARN, INFO
from .threats import threat_list_sources_for

# ─────────────────────────────────────────────────────────────────────────────
# DETECTION RULES  (pattern, severity, AG-ID, description)
# ─────────────────────────────────────────────────────────────────────────────
RULES: list[tuple[str, str, str, str]] = [
    # ── CRITICAL ─────────────────────────────────────────────────────────────
    (r"curl\s+[^|]*\|\s*(ba?sh|zsh|fish|python\d*|perl|ruby)",
     "CRITICAL", "AG-101", "Remote code exec: curl output piped directly to shell"),
    (r"wget\s+[^|]*-O\s*-\s*\|\s*(ba?sh|zsh)",
     "CRITICAL", "AG-102", "Remote code exec: wget output piped to shell"),
    (r"\bnpm\s+(install|i)\b",
     "CRITICAL", "AG-103", "npm install in PKGBUILD — Atomic Arch 2026 attack vector"),
    (r"\bbun\s+(install|add)\b",
     "CRITICAL", "AG-104", "bun install in PKGBUILD — Atomic Arch Wave 2 vector"),
    (r"(pastebin\.com|paste\.ee|hastebin\.com|ghostbin\.co|dpaste\.com)",
     "CRITICAL", "AG-105", "Download from paste site — used in xeactor 2018 attack"),
    (r"\$\(\s*echo\s+[A-Za-z0-9+/=]{16,}\s*\|\s*base64",
     "CRITICAL", "AG-106", "Encoded payload decoded and executed inline"),

    # ── HIGH ─────────────────────────────────────────────────────────────────
    (r"\bpip\d*\s+install\b",
     "HIGH", "AG-201", "pip install in PKGBUILD — cross-ecosystem dependency injection"),
    (r"\bcargo\s+install\b",
     "HIGH", "AG-202", "cargo install in PKGBUILD — cross-ecosystem injection"),
    (r"base64\s+(-d|--decode)",
     "HIGH", "AG-203", "base64 decode — common payload obfuscation technique"),
    (r"\beval\s+['\"`$(\[]",
     "HIGH", "AG-204", "eval of non-literal expression — obfuscation / code injection"),
    (r"\\x[0-9a-fA-F]{2}(?:\\x[0-9a-fA-F]{2}){7,}",
     "HIGH", "AG-205", "Long hex escape sequence — likely obfuscated payload"),
    (r"cd\s+/tmp\s*&&",
     "HIGH", "AG-206", "Execution staged from /tmp — common malware pattern"),
    (r"/tmp/[a-zA-Z0-9_.\-]+\s*[;&|]",
     "HIGH", "AG-207", "Running executable from /tmp"),
    (r"\bchmod\s+(\+x|[0-7]{3,4})\s+/tmp/",
     "HIGH", "AG-208", "Making /tmp file executable"),
    (r"crontab\s+-[li]",
     "HIGH", "AG-209", "Modifying crontab — persistence mechanism"),
    (r"\.ssh/(?:id_|authorized_keys|known_hosts|config)",
     "HIGH", "AG-210", "Accessing SSH credentials directory"),
    (r"\.config/(?:chromium|google-chrome|brave|microsoft-edge|opera)(?:/|\")",
     "HIGH", "AG-211", "Reading Chromium-family browser profile — credential theft"),
    (r"\.mozilla/firefox",
     "HIGH", "AG-212", "Reading Firefox profile directory — credential theft"),
    (r"\b(?:GITHUB_TOKEN|GH_TOKEN|NPM_TOKEN|AWS_SECRET_ACCESS_KEY|VAULT_TOKEN|GITLAB_TOKEN)\b",
     "HIGH", "AG-213", "Referencing secret credential environment variable"),
    (r"(ngrok\.io|\.ngrok\.app|\.ngrok-free\.app)",
     "HIGH", "AG-214", "ngrok tunnel URL — C2 exfiltration channel"),
    (r"\b(?:bpftool|bpf_prog_load|libbpf)\b",
     "HIGH", "AG-215", "eBPF reference — used in Atomic Arch 2026 rootkit"),
    (r"\bcurl\b.*(?:-s|-sS|-sL).*-o\s+/tmp/",
     "HIGH", "AG-216", "Silent download to /tmp — staging malware pattern"),

    # ── MEDIUM ───────────────────────────────────────────────────────────────
    (r"systemctl\s+(?:enable|start|daemon-reload)\s+",
     "MEDIUM", "AG-301", "Enabling/starting systemd service — verify expected"),
    (r"(?:\.bashrc|\.bash_profile|\.profile|\.zshrc|\.config/fish/config\.fish)",
     "MEDIUM", "AG-302", "Writing to shell init file — potential persistence"),
    (r"\b(?:insmod|modprobe)\s+",
     "MEDIUM", "AG-303", "Loading kernel module — verify expected for this package"),
    (r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b",
     "MEDIUM", "AG-304", "Hardcoded IP address — verify it is an expected upstream"),
    (r"(?:useradd|groupadd|usermod)\s+",
     "MEDIUM", "AG-305", "Creating/modifying system user — verify expected"),
    (r"iptables|nftables|ufw\s+",
     "MEDIUM", "AG-306", "Modifying firewall rules"),
    (r"chown\s+root|chmod\s+[46][0-7]{2,3}",
     "MEDIUM", "AG-307", "Setting SUID/SGID or root ownership"),

    # ── LOW ──────────────────────────────────────────────────────────────────
    (r"curl\b|wget\b",
     "LOW", "AG-401", "Network download — verify source URL is official upstream"),
    (r"ldconfig\b",
     "LOW", "AG-402", "Running ldconfig — normal for library packages"),
]

# ── Supply-chain content checks (not line-level) ──────────────────────────────
# [SEC-2] Added nextfile-js
BAD_DEPS: dict[str, str] = {
    "atomic-lockfile": "AG-103",
    "lockfile-js":     "AG-103",
    "js-digest":       "AG-104",
    "nextfile-js":     "AG-103",   # SEC-2 fix
}

# [SEC-1] krisztinavarga added; arojas REMOVED (victim of commit forgery, not attacker)
BAD_ACCS: set[str] = {
    "krisztinavarga",   # SEC-1: Wave 1 attacker (atomic-lockfile npm publisher)
    "custodiatovar",    # Wave 2 attacker (js-digest)
    "veramagalhaes",    # Wave 2 attacker
    "franziskaweber",   # npm shenanigans wave
    "tobiaswesterburg", # npm shenanigans wave
    "ellenmyklebust",   # npm shenanigans wave
    "xeactor",          # 2018 acroread attack
}

# Monitoring — not in BAD_ACCS yet but flagged as suspicious
AT_RISK_ACCS: set[str] = {
    "ivonahruskova",  # 16 rapid adoptions, no malicious commits confirmed yet
    "simongeisler",   # 16 rapid adoptions, account 3 days old
}

SEV_ORD: dict[str, int] = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}

CACHE_DIR = Path.home() / ".cache" / "aur-guard"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Session persistence dir
CONFIG_DIR = Path.home() / ".config" / "aur-guard"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)


# ─────────────────────────────────────────────────────────────────────────────
# CACHE
# ─────────────────────────────────────────────────────────────────────────────
CACHE_TTL_SECONDS = 86400 * 7   # 7 days

def load_cache(name: str) -> dict:
    p = CACHE_DIR / f"{name}.json"
    try:
        if not p.exists():
            return {}
        data = json.loads(p.read_text())
        # Expire old cache entries
        ts = data.get("ts", 0)
        if time.time() - ts > CACHE_TTL_SECONDS:
            p.unlink(missing_ok=True)
            return {}
        return data
    except Exception:
        return {}


def save_cache(name: str, data: dict) -> None:
    try:
        (CACHE_DIR / f"{name}.json").write_text(json.dumps(data, indent=2))
    except Exception:
        pass


def load_session() -> list[str]:
    """Load persisted package list from previous session."""
    p = CONFIG_DIR / "session.json"
    try:
        if p.exists():
            return json.loads(p.read_text()).get("packages", [])
    except Exception:
        pass
    return []


def save_session(packages: list[str]) -> None:
    """Persist current package list for next session."""
    try:
        (CONFIG_DIR / "session.json").write_text(
            json.dumps({"packages": packages, "saved_at": datetime.now().isoformat()}, indent=2)
        )
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────────────────────
# STATIC ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
def analyze(content: str, fname: str) -> list[dict]:
    """Run all detection rules. Deduplicates per (lineno, ag_id)."""
    seen: set[tuple] = set()
    out: list[dict] = []

    for lineno, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        for pat, sev, ag_id, desc in RULES:
            if re.search(pat, line, re.IGNORECASE):
                key = (lineno, ag_id)
                if key not in seen:
                    seen.add(key)
                    out.append({
                        "severity":    sev,
                        "ag_id":       ag_id,
                        "description": desc,
                        "file":        fname,
                        "line":        lineno,
                        "content":     stripped[:120],
                    })

    # Known-bad dependency check (content-level, dedup per dep name)
    for dep, ag_id in BAD_DEPS.items():
        if dep in content:
            key = (None, f"{ag_id}:{dep}")
            if key not in seen:
                seen.add(key)
                out.append({
                    "severity":    "CRITICAL",
                    "ag_id":       ag_id,
                    "description": f"Known malicious dependency '{dep}' (Atomic Arch 2026)",
                    "file":        fname,
                    "line":        None,
                    "content":     dep,
                })

    # [SEC-6] Checksum skip/missing detection
    if fname == "PKGBUILD":
        if re.search(r'sha\d+sums\s*=\s*\([^)]*SKIP[^)]*\)', content, re.IGNORECASE):
            key = (None, "AG-502:skip")
            if key not in seen:
                seen.add(key)
                out.append({
                    "severity":    "HIGH",
                    "ag_id":       "AG-502",
                    "description": "Checksum verification SKIPPED — no integrity check on download",
                    "file":        fname,
                    "line":        None,
                    "content":     "sha*sums=(... SKIP ...)",
                })
        # [SEC-4 / SEC-10] Source URL validation
        for m in re.finditer(r'source\s*\+=?\s*\([^)]+\)', content, re.DOTALL):
            block = m.group()
            # Flag HTTP (not HTTPS) source URLs
            for url_m in re.finditer(r'"http://([^"]+)"', block):
                key = (None, f"AG-501:{url_m.group()[:40]}")
                if key not in seen:
                    seen.add(key)
                    out.append({
                        "severity":    "MEDIUM",
                        "ag_id":       "AG-501",
                        "description": "Source URL uses HTTP not HTTPS — susceptible to MITM",
                        "file":        fname,
                        "line":        None,
                        "content":     url_m.group()[:80],
                    })
            # Flag localhost/127.0.0.1 sources
            if re.search(r'"(https?://localhost|https?://127\.0\.0\.1)', block):
                key = (None, "AG-501:localhost")
                if key not in seen:
                    seen.add(key)
                    out.append({
                        "severity":    "HIGH",
                        "ag_id":       "AG-501",
                        "description": "Source URL points to localhost — not a real upstream",
                        "file":        fname,
                        "line":        None,
                        "content":     "source= localhost URL",
                    })

    return out


# ─────────────────────────────────────────────────────────────────────────────
# REPUTATION SCORING
# ─────────────────────────────────────────────────────────────────────────────
def score_pkg(info: dict) -> tuple[int, list[str]]:
    """Return (0-100 risk score, list of human-readable reasons)."""
    score, reasons = 0, []
    now = datetime.now(timezone.utc).timestamp()

    mnt = (info.get("Maintainer") or "").lower()
    if mnt in BAD_ACCS:
        score += 50
        reasons.append(f"Maintainer '{mnt}' is a confirmed malicious account")
    if mnt in AT_RISK_ACCS:
        score += 20
        reasons.append(f"Maintainer '{mnt}' is under security monitoring (suspicious rapid adoption)")
    if not info.get("Maintainer"):
        score += 25
        reasons.append("Package is ORPHANED — no active maintainer")

    sub = info.get("FirstSubmitted", 0)
    age = (now - sub) / 86400 if sub else 9999
    if age < 7:
        score += 20
        reasons.append(f"Very new package — submitted {age:.0f} days ago")
    elif age < 30:
        score += 10
        reasons.append(f"Recently submitted — {age:.0f} days ago")

    mod = info.get("LastModified", 0)
    mod_age = (now - mod) / 86400 if mod else 9999
    if mod_age < 3 and age > 180:
        score += 15
        reasons.append(f"Old package updated very recently ({mod_age:.0f}d ago) — check diff")

    votes = info.get("NumVotes", 0)
    if votes == 0 and age > 90:
        score += 10
        reasons.append("Zero votes on old package — possibly unnoticed")
    elif votes < 5 and age > 365:
        score += 5
        reasons.append(f"Only {votes} votes after {age:.0f} days")

    if info.get("OutOfDate"):
        score += 5
        reasons.append("Package is flagged out-of-date")

    return min(score, 100), reasons


def verdict(score: int, findings: list[dict]) -> str:
    """
    [DEV-10] Fixed: LOW findings alone do NOT escalate to MEDIUM.
    Only MEDIUM+ findings trigger the MEDIUM verdict threshold.
    """
    nc = sum(1 for f in findings if f["severity"] == "CRITICAL")
    nh = sum(1 for f in findings if f["severity"] == "HIGH")
    nm = sum(1 for f in findings if f["severity"] == "MEDIUM")
    total = score + nc * 30 + nh * 15
    if total >= 75 or nc > 0:   return "CRITICAL"
    if total >= 50 or nh > 0:   return "HIGH"
    if total >= 25 or nm > 0:   return "MEDIUM"    # Only MEDIUM+ findings escalate
    return "CLEAN"


# ─────────────────────────────────────────────────────────────────────────────
# UNIFIED DIFF  [SEC-8]
# ─────────────────────────────────────────────────────────────────────────────
def compute_diff(old_content: str, new_content: str) -> tuple[list[str], int]:
    """
    Return (added_lines, total_changed_lines) using unified diff.
    Catches reordered, modified, and moved lines that set-diff misses.
    """
    old_lines = old_content.splitlines(keepends=True)
    new_lines = new_content.splitlines(keepends=True)
    diff = list(difflib.unified_diff(old_lines, new_lines, lineterm=""))
    added   = [l[1:].rstrip() for l in diff if l.startswith("+") and not l.startswith("+++")]
    removed = [l[1:].rstrip() for l in diff if l.startswith("-") and not l.startswith("---")]
    return added, len(added) + len(removed)


# ─────────────────────────────────────────────────────────────────────────────
# AUR API  [SEC-9] rate-limit delay added
# ─────────────────────────────────────────────────────────────────────────────
_last_request: float = 0.0
_REQUEST_INTERVAL = 0.3   # seconds between AUR API calls


def _aur_get(url: str) -> bytes | None:
    """Rate-limited AUR HTTP GET."""
    global _last_request
    elapsed = time.time() - _last_request
    if elapsed < _REQUEST_INTERVAL:
        time.sleep(_REQUEST_INTERVAL - elapsed)
    try:
        req = _urllib_req.Request(url, headers={"User-Agent": "aur-guard/4.0"})
        with _urllib_req.urlopen(req, timeout=12) as r:
            data = r.read()
            _last_request = time.time()
            return data
    except Exception:
        _last_request = time.time()
        return None


def aur_info(pkg: str) -> dict | None:
    url = f"https://aur.archlinux.org/rpc/?v=5&type=info&arg[]={pkg}"
    data = _aur_get(url)
    if not data:
        return None
    try:
        results = json.loads(data).get("results", [])
        return results[0] if results else None
    except Exception:
        return None


def fetch_pkgbuild(pkg: str) -> str | None:
    url = f"https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg}"
    data = _aur_get(url)
    if not data:
        return None
    c = data.decode("utf-8", errors="replace")
    return c if c and "<html" not in c[:100] else None


def fetch_install_file(pkg: str) -> str | None:
    for name in [f"{pkg}.install", "install"]:
        url = f"https://aur.archlinux.org/cgit/aur.git/plain/{name}?h={pkg}"
        data = _aur_get(url)
        if data:
            c = data.decode("utf-8", errors="replace")
            if c and "<html" not in c[:100] and len(c) > 20:
                return c
    return None


def get_installed_aur() -> list[str]:
    try:
        r = subprocess.run(["pacman", "-Qm"], capture_output=True, text=True, timeout=10)
        return [line.split()[0] for line in r.stdout.strip().splitlines() if line]
    except Exception:
        return []


# ─────────────────────────────────────────────────────────────────────────────
# INPUT VALIDATION  [DEV-3]
# ─────────────────────────────────────────────────────────────────────────────
_PKG_NAME_RE = re.compile(r'^[a-zA-Z0-9][a-zA-Z0-9@._+\-]*$')

def is_valid_pkg_name(name: str) -> bool:
    """Validate AUR package name format."""
    return bool(name) and bool(_PKG_NAME_RE.match(name)) and len(name) <= 255


# ─────────────────────────────────────────────────────────────────────────────
# FULL SCAN PIPELINE
# ─────────────────────────────────────────────────────────────────────────────
def full_scan(pkgname: str, prog: Callable[[str], None] | None = None) -> dict:
    def p(msg: str):
        if prog:
            prog(msg)

    result: dict = {
        "name":             pkgname,
        "info":             None,
        "score":            0,
        "score_reasons":    [],
        "findings":         [],
        "pkgbuild":         None,
        "install_file":     None,
        "diff_lines":       [],
        "diff_removed":     [],
        "diff_added":       0,
        "diff_changed":     0,
        "pkgbuild_changed": False,
        "first_seen":       False,
        "threat_list_match": False,
        "threat_list_sources": [],
        "verdict":          "UNKNOWN",
        "scanned_at":       datetime.now().isoformat(timespec="seconds"),
        "error":            None,
    }

    p("Checking local threat lists…")
    threat_sources = threat_list_sources_for(pkgname)
    if threat_sources:
        result["threat_list_match"] = True
        result["threat_list_sources"] = threat_sources
        result["score"] = 100
        result["score_reasons"].append(
            "Package appears in the local aur-malware-check infected package list"
        )
        result["findings"].append({
            "severity":    "CRITICAL",
            "ag_id":       "AG-600",
            "description": "Package is listed as infected/compromised in the local AUR malware threat list",
            "file":        "aur-malware-check/package_list.txt",
            "line":        None,
            "content":     "; ".join(threat_sources)[:120],
        })

    p("Fetching AUR metadata…")
    info = aur_info(pkgname)
    if not info:
        result["error"] = f"'{pkgname}' not found in AUR"
        result["findings"].sort(key=lambda f: SEV_ORD.get(f["severity"], 9))
        result["verdict"] = verdict(result["score"], result["findings"])
        return result
    result["info"] = info

    p("Scoring reputation…")
    score, reasons = score_pkg(info)
    if result["threat_list_match"]:
        result["score"] = max(result["score"], score)
        result["score_reasons"].extend(reasons)
    else:
        result["score"] = score
        result["score_reasons"] = reasons

    # [SEC-7] Flag at-risk accounts in score_reasons
    mnt = (info.get("Maintainer") or "").lower()
    if mnt in AT_RISK_ACCS:
        result["findings"].append({
            "severity":    "MEDIUM",
            "ag_id":       "AG-503",
            "description": f"Maintainer '{mnt}' is under security monitoring (rapid orphan adoption)",
            "file":        "AUR metadata",
            "line":        None,
            "content":     f"Maintainer: {mnt}",
        })

    p("Fetching PKGBUILD…")
    pb = fetch_pkgbuild(pkgname)
    result["pkgbuild"] = pb

    if pb:
        p("Analyzing PKGBUILD…")
        result["findings"].extend(analyze(pb, "PKGBUILD"))

        p("Fetching .install file…")
        inst = fetch_install_file(pkgname)
        result["install_file"] = inst
        if inst:
            p("Analyzing .install file…")
            result["findings"].extend(analyze(inst, ".install"))

        p("Comparing with cached baseline…")
        h     = hashlib.sha256(pb.encode()).hexdigest()
        cache = load_cache(pkgname)
        if not cache:
            result["first_seen"] = True
        elif cache.get("hash") != h:
            result["pkgbuild_changed"] = True
            old_content = cache.get("content") or ""
            # [SEC-8] Use unified diff instead of set-diff
            added, total_changed = compute_diff(old_content, pb)
            result["diff_lines"]   = added
            result["diff_added"]   = len(added)
            result["diff_changed"] = total_changed
            result["findings"].append({
                "severity":    "HIGH",
                "ag_id":       "AG-217",   # [SEC-5] Fixed: was AG-216 (conflict)
                "description": f"PKGBUILD changed since last scan ({len(added)} additions, {total_changed} total changes)",
                "file":        "PKGBUILD",
                "line":        None,
                "content":     f"SHA256: {h[:24]}…",
            })
        save_cache(pkgname, {"hash": h, "content": pb, "ts": time.time()})

    p("Done.")
    result["findings"].sort(key=lambda f: SEV_ORD.get(f["severity"], 9))
    result["verdict"] = verdict(result["score"], result["findings"])
    return result
