"""
scanner.py — Security engine, AUR API, cache, full_scan pipeline.
All pure functions — no Textual dependency.
"""
from __future__ import annotations
import re, json, time, hashlib, subprocess
from pathlib import Path
from datetime import datetime, timezone
from typing import Callable

from .icons import CRITICAL, HIGH, MEDIUM, LOW, CLEAN, OK, FAIL, WARN, INFO

# ─────────────────────────────────────────────────────────────────────────────
# DETECTION RULES  (pattern, severity, AG-ID, description)
# AG-IDs follow Nessus-style numbering: AG-1xx CRITICAL, AG-2xx HIGH,
# AG-3xx MEDIUM, AG-4xx LOW — makes findings cross-referenceable.
# ─────────────────────────────────────────────────────────────────────────────
RULES: list[tuple[str, str, str, str]] = [
    # ── CRITICAL ─────────────────────────────────────────────────────────────
    (r"curl\s+[^|]*\|\s*(ba?sh|zsh|fish|python\d*|perl|ruby)",
     "CRITICAL","AG-101","Remote code exec: curl output piped directly to shell"),
    (r"wget\s+[^|]*-O\s*-\s*\|\s*(ba?sh|zsh)",
     "CRITICAL","AG-102","Remote code exec: wget output piped to shell"),
    (r"\bnpm\s+(install|i)\b",
     "CRITICAL","AG-103","npm install in PKGBUILD — Atomic Arch 2026 attack vector"),
    (r"\bbun\s+(install|add)\b",
     "CRITICAL","AG-104","bun install in PKGBUILD — Atomic Arch Wave 2 vector"),
    (r"(pastebin\.com|paste\.ee|hastebin\.com|ghostbin\.co|dpaste\.com)",
     "CRITICAL","AG-105","Download from paste site — used in xeactor 2018 attack"),
    (r"\$\(\s*echo\s+[A-Za-z0-9+/=]{16,}\s*\|\s*base64",
     "CRITICAL","AG-106","Encoded payload decoded and executed inline"),
    # ── HIGH ─────────────────────────────────────────────────────────────────
    (r"\bpip\d*\s+install\b",
     "HIGH","AG-201","pip install in PKGBUILD — cross-ecosystem dependency injection"),
    (r"\bcargo\s+install\b",
     "HIGH","AG-202","cargo install in PKGBUILD — cross-ecosystem dependency injection"),
    (r"base64\s+(-d|--decode)",
     "HIGH","AG-203","base64 decode — common payload obfuscation technique"),
    (r"\beval\s+['\"`$(\[]",
     "HIGH","AG-204","eval of non-literal expression — obfuscation / code injection"),
    (r"\\x[0-9a-fA-F]{2}(?:\\x[0-9a-fA-F]{2}){7,}",
     "HIGH","AG-205","Long hex escape sequence — likely obfuscated payload"),
    (r"cd\s+/tmp\s*&&",
     "HIGH","AG-206","Execution staged from /tmp — common malware pattern"),
    (r"/tmp/[a-zA-Z0-9_.\-]+\s*[;&|]",
     "HIGH","AG-207","Running executable from /tmp"),
    (r"\bchmod\s+(\+x|[0-7]{3,4})\s+/tmp/",
     "HIGH","AG-208","Making /tmp file executable"),
    (r"crontab\s+-[li]",
     "HIGH","AG-209","Modifying crontab — persistence mechanism"),
    (r"\.ssh/(?:id_|authorized_keys|known_hosts|config)",
     "HIGH","AG-210","Accessing SSH credentials directory"),
    (r"\.config/(?:chromium|google-chrome|brave|microsoft-edge|opera)(?:/|\")",
     "HIGH","AG-211","Reading Chromium-family browser profile — credential theft"),
    (r"\.mozilla/firefox",
     "HIGH","AG-212","Reading Firefox profile directory — credential theft"),
    (r"\b(?:GITHUB_TOKEN|GH_TOKEN|NPM_TOKEN|AWS_SECRET_ACCESS_KEY|VAULT_TOKEN|GITLAB_TOKEN)\b",
     "HIGH","AG-213","Referencing secret credential environment variable"),
    (r"(ngrok\.io|\.ngrok\.app|\.ngrok-free\.app)",
     "HIGH","AG-214","ngrok tunnel URL — C2 exfiltration channel"),
    (r"\b(?:bpftool|bpf_prog_load|libbpf)\b",
     "HIGH","AG-215","eBPF reference — used in Atomic Arch 2026 rootkit"),
    (r"\bcurl\b.*(?:-s|-sS|-sL).*-o\s+/tmp/",
     "HIGH","AG-216","Silent download to /tmp — staging malware pattern"),
    # ── MEDIUM ───────────────────────────────────────────────────────────────
    (r"systemctl\s+(?:enable|start|daemon-reload)\s+",
     "MEDIUM","AG-301","Enabling/starting systemd service — verify this is expected"),
    (r"(?:\.bashrc|\.bash_profile|\.profile|\.zshrc|\.config/fish/config\.fish)",
     "MEDIUM","AG-302","Writing to shell init file — potential persistence"),
    (r"\b(?:insmod|modprobe)\s+",
     "MEDIUM","AG-303","Loading kernel module — verify expected for this package"),
    (r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b",
     "MEDIUM","AG-304","Hardcoded IP address in script — verify it is an expected upstream"),
    (r"(?:useradd|groupadd|usermod)\s+",
     "MEDIUM","AG-305","Creating/modifying system user — verify expected for this package"),
    (r"iptables|nftables|ufw\s+",
     "MEDIUM","AG-306","Modifying firewall rules"),
    (r"chown\s+root|chmod\s+[46][0-7]{2,3}",
     "MEDIUM","AG-307","Setting SUID/SGID or root ownership"),
    # ── LOW ──────────────────────────────────────────────────────────────────
    (r"curl\b|wget\b",
     "LOW","AG-401","Network download present — verify source URL is official upstream"),
    (r"ldconfig\b",
     "LOW","AG-402","Running ldconfig — normal for library packages but worth noting"),
]

# Known malicious npm/bun packages (Atomic Arch 2026)
BAD_DEPS: dict[str, str] = {
    "atomic-lockfile": "AG-103",
    "lockfile-js":     "AG-103",
    "js-digest":       "AG-104",
}

# Known malicious AUR maintainer accounts
BAD_ACCS: set[str] = {
    "xeactor", "custodiatovar", "veramagalhaes",
    "franziskaweber", "tobiaswesterburg", "ellenmyklebust",
}

SEV_ORD: dict[str, int] = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}

CACHE_DIR = Path.home() / ".cache" / "aur-guard"
CACHE_DIR.mkdir(parents=True, exist_ok=True)


# ─────────────────────────────────────────────────────────────────────────────
# CACHE
# ─────────────────────────────────────────────────────────────────────────────
def load_cache(name: str) -> dict:
    p = CACHE_DIR / f"{name}.json"
    try:
        return json.loads(p.read_text()) if p.exists() else {}
    except Exception:
        return {}


def save_cache(name: str, data: dict) -> None:
    try:
        (CACHE_DIR / f"{name}.json").write_text(json.dumps(data, indent=2))
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────────────────────
# STATIC ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────
def analyze(content: str, fname: str) -> list[dict]:
    """
    Run all detection rules against content.

    Deduplication strategy:
      - Per-line rules: deduplicate on (lineno, ag_id) — same rule can fire
        on multiple lines (legitimate), but won't fire twice on the same line.
      - Content-level (known-bad deps): deduplicate on ag_id+dep name so the
        same dep referenced many times only produces one finding.
    """
    seen: set[tuple] = set()
    out: list[dict] = []

    for lineno, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        for pat, sev, ag_id, desc in RULES:
            if re.search(pat, line, re.IGNORECASE):
                key = (lineno, ag_id)           # same line + same rule → skip
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

    mod    = info.get("LastModified", 0)
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
    nc = sum(1 for f in findings if f["severity"] == "CRITICAL")
    nh = sum(1 for f in findings if f["severity"] == "HIGH")
    total = score + nc * 30 + nh * 15
    if total >= 75 or nc > 0:  return "CRITICAL"
    if total >= 50 or nh > 0:  return "HIGH"
    if total >= 25 or findings: return "MEDIUM"
    return "CLEAN"


# ─────────────────────────────────────────────────────────────────────────────
# AUR API
# ─────────────────────────────────────────────────────────────────────────────
from urllib import request as _urllib_req

def aur_info(pkg: str) -> dict | None:
    url = f"https://aur.archlinux.org/rpc/?v=5&type=info&arg[]={pkg}"
    try:
        req = _urllib_req.Request(url, headers={"User-Agent": "aur-guard/3.0"})
        with _urllib_req.urlopen(req, timeout=12) as r:
            results = json.loads(r.read()).get("results", [])
            return results[0] if results else None
    except Exception:
        return None


def fetch_pkgbuild(pkg: str) -> str | None:
    url = f"https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg}"
    try:
        req = _urllib_req.Request(url, headers={"User-Agent": "aur-guard/3.0"})
        with _urllib_req.urlopen(req, timeout=12) as r:
            c = r.read().decode("utf-8", errors="replace")
            return c if c and "<html" not in c[:100] else None
    except Exception:
        return None


def fetch_install_file(pkg: str) -> str | None:
    for name in [f"{pkg}.install", "install"]:
        url = f"https://aur.archlinux.org/cgit/aur.git/plain/{name}?h={pkg}"
        try:
            req = _urllib_req.Request(url, headers={"User-Agent": "aur-guard/3.0"})
            with _urllib_req.urlopen(req, timeout=10) as r:
                c = r.read().decode("utf-8", errors="replace")
                if c and "<html" not in c[:100] and len(c) > 20:
                    return c
        except Exception:
            pass
    return None


def get_installed_aur() -> list[str]:
    try:
        r = subprocess.run(["pacman", "-Qm"], capture_output=True, text=True, timeout=10)
        return [line.split()[0] for line in r.stdout.strip().splitlines() if line]
    except Exception:
        return []


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
        "diff_added":       0,
        "pkgbuild_changed": False,
        "first_seen":       False,
        "verdict":          "UNKNOWN",
        "scanned_at":       datetime.now().isoformat(timespec="seconds"),
        "error":            None,
    }

    p("Fetching AUR metadata…")
    info = aur_info(pkgname)
    if not info:
        result["error"] = f"'{pkgname}' not found in AUR"
        return result
    result["info"] = info

    p("Scoring reputation…")
    score, reasons = score_pkg(info)
    result["score"]         = score
    result["score_reasons"] = reasons

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
            old_lines = set((cache.get("content") or "").splitlines())
            added     = [l for l in pb.splitlines() if l not in old_lines and l.strip()]
            result["diff_lines"] = added
            result["diff_added"] = len(added)
            result["findings"].append({
                "severity":    "HIGH",
                "ag_id":       "AG-216",
                "description": f"PKGBUILD changed since last scan ({len(added)} new lines)",
                "file":        "PKGBUILD",
                "line":        None,
                "content":     f"SHA256: {h[:24]}…",
            })
        save_cache(pkgname, {"hash": h, "content": pb, "ts": time.time()})

    p("Done.")
    result["findings"].sort(key=lambda f: SEV_ORD.get(f["severity"], 9))
    result["verdict"] = verdict(result["score"], result["findings"])
    return result
