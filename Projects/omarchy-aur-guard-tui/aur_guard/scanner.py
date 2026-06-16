from __future__ import annotations
import re, json, time, hashlib, subprocess
from pathlib import Path
from datetime import datetime, timezone
from urllib import request as urllib_request
from typing import Callable

RULES = [
    (r"curl\s+.*\|\s*(bash|sh|zsh|fish|python|perl|ruby)","CRITICAL","Remote exec: curl piped to shell"),
    (r"wget\s+.*-O\s*-\s*\|\s*(bash|sh|zsh)",            "CRITICAL","Remote exec: wget piped to shell"),
    (r"\bnpm\s+install\b",  "CRITICAL","npm install -- Atomic Arch 2026 attack vector"),
    (r"\bbun\s+install\b",  "CRITICAL","bun install -- Atomic Arch Wave 2 vector"),
    (r"\bpip\s+install\b",  "HIGH",   "pip install in PKGBUILD -- cross-ecosystem injection"),
    (r"\bcargo\s+install\b","HIGH",   "cargo install in PKGBUILD"),
    (r"base64\s+(-d|--decode)",        "HIGH","base64 decode -- obfuscation"),
    (r"\beval\s+['\"`\$\(]",          "HIGH","eval of non-literal -- obfuscation"),
    (r"\\x[0-9a-fA-F]{2}(\\x[0-9a-fA-F]{2}){4,}","HIGH","Long hex escape -- encoded payload"),
    (r"cd\s+/tmp\s+&&",               "HIGH","Execution from /tmp"),
    (r"/tmp/[a-zA-Z0-9_\-]+\s+(&&|\|)","HIGH","Running binary from /tmp"),
    (r"\bchmod\s+\+x\s+/tmp/",        "HIGH","Making /tmp binary executable"),
    (r"systemctl\s+(enable|start)\s+","MEDIUM","Enabling systemd service -- verify expected"),
    (r"crontab\s+-",                   "HIGH","Modifying crontab -- persistence"),
    (r"\.bashrc|\.profile|\.zshrc",   "MEDIUM","Writing to shell RC -- persistence"),
    (r"\.ssh/",                        "HIGH","Accessing SSH directory"),
    (r"\.config/(chromium|google-chrome|brave|microsoft-edge)","HIGH","Accessing browser profile"),
    (r"\.mozilla/firefox",             "HIGH","Accessing Firefox profile"),
    (r"GITHUB_TOKEN|GH_TOKEN|NPM_TOKEN|AWS_SECRET|VAULT_TOKEN","HIGH","Referencing secret env vars"),
    (r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b","MEDIUM","Hardcoded IP address"),
    (r"(pastebin\.com|paste\.ee|hastebin|ghostbin|dpaste)","CRITICAL","Paste site download -- xeactor 2018"),
    (r"(ngrok\.io|\.ngrok\.app)",      "HIGH","ngrok tunnel -- C2 exfiltration"),
    (r"\bbpftool\b|\blibbpf\b",        "HIGH","eBPF reference -- rootkit indicator"),
    (r"insmod|modprobe",               "MEDIUM","Kernel module loading"),
]
BAD_NPM  = {"atomic-lockfile","lockfile-js","js-digest"}
BAD_ACCS = {"xeactor","custodiatovar","veramagalhaes","franziskaweber","tobiaswesterburg","ellenmyklebust"}
SEV_ORD  = {"CRITICAL":0,"HIGH":1,"MEDIUM":2,"LOW":3}

CACHE_DIR = Path.home()/".cache"/"aur-guard"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

def load_cache(n):
    p = CACHE_DIR/f"{n}.json"
    try: return json.loads(p.read_text()) if p.exists() else {}
    except: return {}

def save_cache(n,d):
    try: (CACHE_DIR/f"{n}.json").write_text(json.dumps(d,indent=2))
    except: pass

def analyze(content:str, fname:str) -> list[dict]:
    out = []
    for i,line in enumerate(content.splitlines(),1):
        if line.strip().startswith("#"): continue
        for pat,sev,desc in RULES:
            if re.search(pat,line,re.IGNORECASE):
                out.append({"severity":sev,"description":desc,"file":fname,"line":i,"content":line.strip()[:120]})
    for pkg in BAD_NPM:
        if pkg in content:
            out.append({"severity":"CRITICAL","description":f"Known malicious pkg '{pkg}' (Atomic Arch 2026)","file":fname,"line":None,"content":pkg})
    return out

def score_pkg(info:dict) -> tuple[int,list[str]]:
    s,r = 0,[]
    now = datetime.now(timezone.utc).timestamp()
    mnt = (info.get("Maintainer") or "").lower()
    if mnt in BAD_ACCS:   s+=50; r.append(f"Maintainer '{mnt}' is a known malicious account")
    if not info.get("Maintainer"): s+=25; r.append("Package is ORPHANED -- no active maintainer")
    sub = info.get("FirstSubmitted",0)
    age = (now-sub)/86400 if sub else 9999
    if age<7:    s+=20; r.append(f"Very new -- submitted {age:.0f} days ago")
    elif age<30: s+=10; r.append(f"Recently submitted -- {age:.0f} days ago")
    mod = info.get("LastModified",0)
    ma  = (now-mod)/86400 if mod else 9999
    if ma<3 and age>180: s+=15; r.append(f"Old package updated {ma:.0f}d ago -- review diff")
    v = info.get("NumVotes",0)
    if v==0 and age>90:   s+=10; r.append("Zero votes on old package")
    elif v<5 and age>365: s+=5;  r.append(f"Only {v} votes after {age:.0f} days")
    if info.get("OutOfDate"): s+=5; r.append("Flagged out-of-date")
    return min(s,100),r

def verdict(score:int, findings:list[dict]) -> str:
    nc = sum(1 for f in findings if f["severity"]=="CRITICAL")
    nh = sum(1 for f in findings if f["severity"]=="HIGH")
    t  = score + nc*30 + nh*15
    if t>=75 or nc>0: return "CRITICAL"
    if t>=50 or nh>0: return "HIGH"
    if t>=25 or findings: return "MEDIUM"
    return "CLEAN"

def aur_info(pkg:str) -> dict|None:
    url = f"https://aur.archlinux.org/rpc/?v=5&type=info&arg[]={pkg}"
    try:
        r = urllib_request.Request(url,headers={"User-Agent":"aur-guard/2.0"})
        with urllib_request.urlopen(r,timeout=10) as resp:
            res = json.loads(resp.read()).get("results",[])
            return res[0] if res else None
    except: return None

def fetch_pkgbuild(pkg:str) -> str|None:
    url = f"https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg}"
    try:
        r = urllib_request.Request(url,headers={"User-Agent":"aur-guard/2.0"})
        with urllib_request.urlopen(r,timeout=10) as resp:
            c = resp.read().decode("utf-8",errors="replace")
            return c if c and "<html" not in c[:100] else None
    except: return None

def fetch_install(pkg:str) -> str|None:
    for ext in [f"{pkg}.install","install"]:
        url = f"https://aur.archlinux.org/cgit/aur.git/plain/{ext}?h={pkg}"
        try:
            r = urllib_request.Request(url,headers={"User-Agent":"aur-guard/2.0"})
            with urllib_request.urlopen(r,timeout=8) as resp:
                c = resp.read().decode("utf-8",errors="replace")
                if c and "<html" not in c[:100] and len(c)>20: return c
        except: pass
    return None

def get_installed_aur() -> list[str]:
    try:
        r = subprocess.run(["pacman","-Qm"],capture_output=True,text=True,timeout=10)
        return [l.split()[0] for l in r.stdout.strip().splitlines() if l]
    except: return []

def full_scan(pkgname:str, prog:Callable[[str],None]|None=None) -> dict:
    def p(m):
        if prog: prog(m)
    result = dict(name=pkgname,info=None,score=0,score_reasons=[],findings=[],
                  pkgbuild=None,install_file=None,diff_lines=[],
                  pkgbuild_changed=False,first_seen=False,verdict="UNKNOWN",error=None)
    p("Fetching AUR metadata...")
    info = aur_info(pkgname)
    if not info:
        result["error"] = f"'{pkgname}' not found in AUR"; return result
    result["info"] = info
    p("Scoring reputation...")
    s,r = score_pkg(info); result["score"],result["score_reasons"] = s,r
    p("Fetching PKGBUILD...")
    pb = fetch_pkgbuild(pkgname); result["pkgbuild"] = pb
    if pb:
        p("Analyzing PKGBUILD...")
        result["findings"].extend(analyze(pb,"PKGBUILD"))
        p("Checking .install file...")
        inst = fetch_install(pkgname); result["install_file"] = inst
        if inst: result["findings"].extend(analyze(inst,".install"))
        p("Comparing with cache...")
        h = hashlib.sha256(pb.encode()).hexdigest()
        cache = load_cache(pkgname)
        if not cache:
            result["first_seen"] = True
        elif cache.get("hash") != h:
            result["pkgbuild_changed"] = True
            old = set((cache.get("content") or "").splitlines())
            result["diff_lines"] = [l for l in pb.splitlines() if l not in old and l.strip()]
            result["findings"].append({"severity":"HIGH","description":"PKGBUILD changed since last scan",
                                        "file":"PKGBUILD","line":None,"content":f"SHA256:{h[:16]}..."})
        save_cache(pkgname,{"hash":h,"content":pb,"ts":time.time()})
    p("Done.")
    result["findings"].sort(key=lambda f: SEV_ORD.get(f["severity"],9))
    result["verdict"] = verdict(result["score"],result["findings"])
    return result
