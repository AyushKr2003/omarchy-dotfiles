from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path
from urllib import request as _urllib_req

CONFIG_DIR = Path.home() / ".config" / "aur-guard"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)

HEDGEDOC_URL = "https://md.archlinux.org/s/SxbqukK6IA/download"

FALLBACK_INFECTED_PKGS: frozenset[str] = frozenset({
    "alvr", "alvr-git", "premake-git", "guiscrcpy", "netmon-git",
    "inadyn-mt", "nodejs-elm", "keepassx2", "compiz-git",
    "libquvi-scripts-deps",
})

FALLBACK_MALICIOUS_NPM: frozenset[str] = frozenset({
    "atomic-lockfile", "lockfile-js", "js-digest", "nextfile-js",
})

_PKG_RE = re.compile(r"^[a-z0-9][a-z0-9_.+\-]*[a-z0-9+]$", re.MULTILINE)


def workspace_root() -> Path:
    return Path(__file__).resolve().parents[3]


def _read_name_list(path: Path) -> set[str]:
    try:
        return {
            line.strip()
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
    except OSError:
        return set()


def _read_name_list_sources(path: Path, package: str) -> list[str]:
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            name = line.strip()
            if name and not name.startswith("#") and name == package:
                return [str(path)]
    except OSError:
        pass
    return []


def threat_package_candidates() -> list[Path]:
    candidates: list[Path] = []
    if env := os.environ.get("AUR_GUARD_PACKAGE_LIST"):
        candidates.append(Path(env).expanduser())
    candidates.extend([
        CONFIG_DIR / "package_list.txt",
        workspace_root() / "aur-malware-check" / "package_list.txt",
        Path(__file__).resolve().parents[1] / "package_list.txt",
        # Bundled compromised AUR list shipped with aur-guard
        Path(__file__).resolve().parent / "compromised_aurs.list",
    ])
    return candidates


def malicious_npm_candidates() -> list[Path]:
    candidates: list[Path] = []
    if env := os.environ.get("AUR_GUARD_MALICIOUS_NPM_LIST"):
        candidates.append(Path(env).expanduser())
    candidates.extend([
        CONFIG_DIR / "malicious_npm_packages.txt",
        workspace_root() / "aur-malware-check" / "malicious_npm_packages.txt",
        Path(__file__).resolve().parents[1] / "malicious_npm_packages.txt",
    ])
    return candidates


def load_threat_package_names() -> set[str]:
    names: set[str] = set(FALLBACK_INFECTED_PKGS)
    for path in threat_package_candidates():
        names.update(_read_name_list(path))
    return names


def threat_list_sources_for(package: str) -> list[str]:
    sources: list[str] = []
    if package in FALLBACK_INFECTED_PKGS:
        sources.append("built-in Atomic Arch confirmed package fallback")
    for path in threat_package_candidates():
        sources.extend(_read_name_list_sources(path, package))
    return sources


def load_malicious_npm_names() -> set[str]:
    names: set[str] = set(FALLBACK_MALICIOUS_NPM)
    for path in malicious_npm_candidates():
        names.update(_read_name_list(path))
    return names


def fetch_url(url: str = HEDGEDOC_URL, timeout: int = 15) -> str | None:
    try:
        req = _urllib_req.Request(url, headers={"User-Agent": "aur-guard/4.1"})
        with _urllib_req.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception:
        return None


def extract_package_names(text: str) -> list[str]:
    return _PKG_RE.findall(text)


def refresh_threat_list(url: str = HEDGEDOC_URL, target: Path | None = None) -> tuple[bool, str, int]:
    target = target or (CONFIG_DIR / "package_list.txt")
    text = fetch_url(url)
    if text is None:
        return False, f"Failed to fetch {url}", 0
    names = sorted(set(extract_package_names(text)))
    if not names:
        return False, "Fetched threat list but parsed 0 packages", 0
    target.parent.mkdir(parents=True, exist_ok=True)
    raw = "\n".join(names) + "\n"
    try:
        r = subprocess.run(["sort", "-u", "-o", str(target)], input=raw, text=True, timeout=15)
        if r.returncode != 0:
            return False, f"sort failed with exit code {r.returncode}", 0
    except OSError as exc:
        return False, f"Cannot write package list: {exc}", 0
    return True, str(target), len(names)
