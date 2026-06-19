from __future__ import annotations

import glob
import locale
import os
import re
import subprocess
from dataclasses import asdict, dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Generator

from .threats import load_malicious_npm_names, load_threat_package_names

CAMPAIGN_START = "2026-06-09"
CAMPAIGN_END = "2026-06-12"


@dataclass(frozen=True)
class PackageMatch:
    name: str
    install_date: str | None


@dataclass(frozen=True)
class LogHit:
    package: str
    action: str
    date: str


@dataclass(frozen=True)
class EcosystemMatch:
    package: str
    location: str
    path: str


def _ensure_c_locale() -> None:
    try:
        locale.setlocale(locale.LC_TIME, "C")
    except locale.Error:
        pass


def parse_pacman_date(raw: str) -> date | None:
    _ensure_c_locale()
    raw = raw.strip()
    if not raw:
        return None
    if " " in raw:
        before, last = raw.rsplit(" ", 1)
        if last.isalpha() and last.upper() not in ("AM", "PM"):
            raw = before
    try:
        return datetime.strptime(raw, "%a %d %b %Y %I:%M:%S %p").date()
    except (ValueError, OSError):
        return None


def read_compressed_lines(path: Path) -> Generator[str, None, None]:
    try:
        if path.suffix.lower() == ".gz":
            import gzip
            with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
                yield from f
            return
        if path.suffix.lower() == ".xz":
            import lzma
            with lzma.open(path, "rt", encoding="utf-8", errors="replace") as f:
                yield from f
            return
        if path.suffix.lower() == ".bz2":
            import bz2
            with bz2.open(path, "rt", encoding="utf-8", errors="replace") as f:
                yield from f
            return
        if path.suffix.lower() == ".zst":
            try:
                r = subprocess.run(["zstdcat", "--", str(path)], capture_output=True, text=True, timeout=30)
                yield from r.stdout.splitlines(keepends=True)
            except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
                return
            return
        with path.open("r", encoding="utf-8", errors="replace") as f:
            yield from f
    except (OSError, PermissionError):
        return


def expand_log_glob(glob_pattern: str) -> list[Path]:
    return sorted(Path(p) for p in glob.glob(glob_pattern))


class IocChecker:
    SUSPICIOUS_BPF_NAMES: frozenset[str] = frozenset({
        "hidden_pids", "hidden_names", "hidden_inodes",
    })

    def __init__(
        self,
        start_date: str = CAMPAIGN_START,
        end_date: str = CAMPAIGN_END,
        all_time: bool = False,
    ) -> None:
        self.infected_packages = load_threat_package_names()
        self.malicious_npm_packages = load_malicious_npm_names()
        self._start = date.fromisoformat(start_date)
        self._end = date.fromisoformat(end_date)
        self.all_time = all_time

    def _in_window(self, d: date) -> bool:
        return self.all_time or self._start <= d <= self._end

    def check_all(
        self,
        *,
        systemd: bool = True,
        ebpf: bool = True,
        npm_cache: bool = True,
        bun_cache: bool = True,
        process_hiding: bool = True,
    ) -> dict:
        results = {
            "installed_infected": [asdict(m) for m in self._check_installed_packages()],
            "pacman_log_hits": [asdict(h) for h in self._check_pacman_logs()],
            "ld_preload": self._check_ld_preload(),
            "suspicious_systemd": [asdict(m) for m in self._check_systemd()] if systemd else [],
            "ebpf_artifacts": self._check_ebpf() if ebpf else [],
            "process_hiding": self._check_process_hiding() if process_hiding else [],
            "npm_cache": [asdict(m) for m in self._check_npm_cache()] if npm_cache else [],
            "bun_cache": [asdict(m) for m in self._check_bun_cache()] if bun_cache else [],
            "threat_packages_loaded": len(self.infected_packages),
            "malicious_npm_loaded": len(self.malicious_npm_packages),
            "date_window": "all-time" if self.all_time else f"{self._start.isoformat()} to {self._end.isoformat()}",
            "enabled_checks": {
                "systemd": systemd,
                "ebpf": ebpf,
                "npm_cache": npm_cache,
                "bun_cache": bun_cache,
                "process_hiding": process_hiding,
            },
        }
        results["exit_code"] = self.exit_code(results)
        return results

    def _check_ebpf(self) -> list[str]:
        found = []
        bpf = Path("/sys/fs/bpf")
        if not bpf.is_dir():
            return found
        for name in self.SUSPICIOUS_BPF_NAMES:
            if (bpf / name).exists():
                found.append(f"/sys/fs/bpf/{name}")
        try:
            r = subprocess.run(["bpftool", "prog", "list"], capture_output=True, text=True, timeout=10)
            for line in r.stdout.splitlines():
                if re.search(r"atomic|hide|hook|scales", line, re.IGNORECASE):
                    found.append(f"bpftool:{line.strip()[:80]}")
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pass
        return found

    def _check_ld_preload(self) -> list[str]:
        found = []
        p = Path("/etc/ld.so.preload")
        if p.exists() and p.stat().st_size > 0:
            try:
                found.append(p.read_text().strip()[:120])
            except Exception:
                found.append(str(p))
        return found

    def _check_npm_cache(self) -> list[EcosystemMatch]:
        found: list[EcosystemMatch] = []
        try:
            cache_ls = subprocess.run(["npm", "cache", "ls"], capture_output=True, text=True, timeout=30)
            cache_lines = cache_ls.stdout.splitlines()
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            cache_lines = []
        for pkg in sorted(self.malicious_npm_packages):
            for line in cache_lines:
                if pkg in line:
                    found.append(EcosystemMatch(pkg, "npm_cache_ls", line.strip()))
            try:
                r = subprocess.run(["npm", "root", "-g"], capture_output=True, text=True, timeout=15)
                global_mod = Path(r.stdout.strip()) / pkg
                if global_mod.is_dir():
                    found.append(EcosystemMatch(pkg, "global_node_modules", str(global_mod)))
            except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
                pass
            try:
                r = subprocess.run(["npm", "config", "get", "cache"], capture_output=True, text=True, timeout=15)
                cache = Path(r.stdout.strip())
                if cache.is_dir():
                    count = 0
                    for d in cache.rglob(f"*{pkg}*"):
                        if d.is_dir():
                            found.append(EcosystemMatch(pkg, "npm_cache_dir", str(d)))
                            count += 1
                            if count >= 5:
                                break
            except (FileNotFoundError, subprocess.TimeoutExpired, OSError, PermissionError):
                pass
        return found

    def _check_bun_cache(self) -> list[EcosystemMatch]:
        found: list[EcosystemMatch] = []
        try:
            cache_ls = subprocess.run(["bun", "pm", "cache", "ls"], capture_output=True, text=True, timeout=30)
            cache_lines = cache_ls.stdout.splitlines()
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            cache_lines = []
        for pkg in sorted(self.malicious_npm_packages):
            for line in cache_lines:
                if pkg in line:
                    found.append(EcosystemMatch(pkg, "bun_cache_ls", line.strip()))
        try:
            r = subprocess.run(["bun", "pm", "cache"], capture_output=True, text=True, timeout=15)
            cache = Path(r.stdout.strip())
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            cache = Path.home() / ".bun" / "install" / "cache"
        if cache.is_dir():
            for pkg in sorted(self.malicious_npm_packages):
                try:
                    count = 0
                    for d in cache.rglob(f"*{pkg}*"):
                        if d.is_dir():
                            found.append(EcosystemMatch(pkg, "bun_cache_dir", str(d)))
                            count += 1
                            if count >= 5:
                                break
                except PermissionError:
                    continue
        return found

    def _check_process_hiding(self) -> list[str]:
        found = []
        proc = Path("/proc")
        if not proc.is_dir():
            return found
        try:
            ps_r = subprocess.run(["ps", "-e", "-o", "pid="], capture_output=True, text=True, timeout=10)
            ps_pids = set(ps_r.stdout.split())
            for pid_dir in proc.iterdir():
                if not pid_dir.name.isdigit() or not (pid_dir / "status").exists():
                    continue
                if pid_dir.name not in ps_pids:
                    try:
                        comm = (pid_dir / "comm").read_text().strip()
                        found.append(f"PID {pid_dir.name} ({comm}) hidden from ps")
                    except Exception:
                        found.append(f"PID {pid_dir.name} hidden from ps")
        except (subprocess.TimeoutExpired, PermissionError, OSError):
            pass
        return found[:5]

    def _check_systemd(self) -> list[EcosystemMatch]:
        found: list[EcosystemMatch] = []
        dirs = [
            Path("/etc/systemd/system"),
            Path.home() / ".config" / "systemd" / "user",
        ]
        for d in dirs:
            if not d.is_dir():
                continue
            try:
                for svc in d.rglob("*.service"):
                    if not svc.is_file():
                        continue
                    try:
                        content = svc.read_text(encoding="utf-8", errors="replace")
                    except OSError:
                        continue
                    if "Restart=always" in content and "RestartSec=30" in content:
                        found.append(EcosystemMatch("systemd", "Restart=always + RestartSec=30", str(svc)))
            except PermissionError:
                continue
        return found

    def _check_installed_packages(self) -> list[PackageMatch]:
        try:
            r = subprocess.run(
                ["pacman", "-Qmq", *sorted(self.infected_packages)],
                capture_output=True, text=True, timeout=30,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            return []
        if r.returncode not in (0, 1):
            return []
        found: list[PackageMatch] = []
        for pkg in r.stdout.splitlines():
            pkg = pkg.strip()
            if not pkg or pkg not in self.infected_packages:
                continue
            install_date: date | None = None
            try:
                qi = subprocess.run(
                    ["pacman", "-Qi", "--", pkg],
                    capture_output=True, text=True, timeout=30,
                    env=os.environ | {"LC_ALL": "C"},
                )
                for line in qi.stdout.splitlines():
                    if line.startswith("Install Date"):
                        install_date = parse_pacman_date(line.split(":", 1)[1].strip())
                        break
            except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
                pass
            if install_date is None or self._in_window(install_date):
                found.append(PackageMatch(pkg, install_date.isoformat() if install_date else None))
        return found

    def _check_pacman_logs(self, log_glob: str = "/var/log/pacman.log*") -> list[LogHit]:
        hits: list[LogHit] = []
        date_re = re.compile(r"^\[(\d{4}-\d{2}-\d{2})")
        alpm_re = re.compile(r"\[ALPM\] (\w+) (\S+)")
        for file in expand_log_glob(log_glob):
            for line in read_compressed_lines(file):
                dm = date_re.match(line)
                if not dm:
                    continue
                hit_date = date.fromisoformat(dm.group(1))
                if not self._in_window(hit_date):
                    continue
                am = alpm_re.search(line)
                if not am:
                    continue
                action, pkg = am.group(1), am.group(2)
                if action in ("installed", "upgraded", "reinstalled") and pkg in self.infected_packages:
                    hits.append(LogHit(pkg, action, hit_date.isoformat()))
        return hits

    def has_iocs(self, results: dict) -> bool:
        ignored = {
            "threat_packages_loaded", "malicious_npm_loaded", "date_window",
            "enabled_checks", "exit_code",
        }
        return any(bool(v) for k, v in results.items() if k not in ignored)

    def severity(self, results: dict) -> str:
        if results.get("ebpf_artifacts") or results.get("ld_preload") or results.get("process_hiding"):
            return "CRITICAL"
        if (
            results.get("installed_infected")
            or results.get("pacman_log_hits")
            or results.get("npm_cache")
            or results.get("bun_cache")
            or results.get("suspicious_systemd")
        ):
            return "HIGH"
        return "CLEAN"

    def exit_code(self, results: dict) -> int:
        return 2 if self.has_iocs(results) else 0
