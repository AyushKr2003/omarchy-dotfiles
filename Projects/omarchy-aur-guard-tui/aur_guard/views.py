"""views.py — WelcomeView, LoadingView, ScanView."""
from __future__ import annotations
from datetime import datetime, timezone
from textual.containers import Container, Horizontal, Vertical
from textual.css.query import NoMatches
from textual.widget import Widget
from textual.widgets import LoadingIndicator, RichLog, Static, TabbedContent, TabPane
from rich.text import Text
from rich.markup import escape

from .theme import BG, DBG, DKR, LBG, MUT, DFG, FG, BFG, ACC, RED, YEL, GRN, CYN, ORG
from .scanner import SEV_ORD
from .icons import (
    APP, CRITICAL, HIGH, MEDIUM, LOW, CLEAN, UNKNOWN,
    OVERVIEW, FINDINGS, PKGBUILD, DIFF, OK, FAIL, WARN, INFO, ARROW,
)

V_COLOR: dict[str, str] = {
    "CRITICAL": RED, "HIGH": ORG, "MEDIUM": YEL, "CLEAN": GRN, "UNKNOWN": MUT,
}
S_COLOR: dict[str, str] = {
    "CRITICAL": RED, "HIGH": ORG, "MEDIUM": YEL, "LOW": CYN,
}


# ─────────────────────────────────────────────────────────────────────────────
class WelcomeView(Widget):
    DEFAULT_CSS = f"WelcomeView {{ height: 1fr; background: {BG}; }}"

    def compose(self):
        with Container(id="welcome-wrap"):
            with Container(id="welcome-box"):
                yield Static(APP,           classes="wl-icon")
                yield Static("aur-guard",   classes="wl-title")
                yield Static(
                    "Search & add AUR packages to scan them\n"
                    "for malicious patterns before installing.",
                    classes="wl-body",
                )
                yield Static(
                    f" [bold {ACC}]j/k[/]   navigate      [bold {ACC}]/[/]  search AUR\n"
                    f" [bold {ACC}]a[/]     add package   [bold {ACC}]S[/]  scan all installed\n"
                    f" [bold {ACC}]r[/]     rescan        [bold {ACC}]d[/]  remove from list\n"
                    f" [bold {ACC}]e[/]     export JSON   [bold {ACC}]?[/]  keybinding help",
                    classes="wl-hint", markup=True,
                )


# ─────────────────────────────────────────────────────────────────────────────
class LoadingView(Widget):
    """
    BUG FIX: Uses CSS classes (not hardcoded IDs) for pkg/step labels
    so multiple instances don't collide. Each instance owns its own subtree.
    """
    DEFAULT_CSS = f"LoadingView {{ height: 1fr; background: {BG}; }}"

    def __init__(self, pkgname: str = "", **kw):
        super().__init__(**kw)
        self.pkgname   = pkgname
        self._step_ref: Static | None = None

    def compose(self):
        with Container(id="loading-wrap"):
            with Container(classes="loading-box"):
                yield Static(f"{APP}  Scanning {self.pkgname}", classes="loading-pkg")
                step = Static("Starting…", classes="loading-step")
                self._step_ref = step
                yield step
                yield LoadingIndicator()

    def set_step(self, msg: str) -> None:
        """Update progress label — safe to call from thread via call_from_thread."""
        if self._step_ref is not None:
            try:
                self._step_ref.update(msg)
            except Exception:
                pass


# ─────────────────────────────────────────────────────────────────────────────
class ScanView(Widget):
    """Full scan result with verdict banner and four tabs."""
    DEFAULT_CSS = f"ScanView {{ height: 1fr; background: {BG}; }}"

    def __init__(self, result: dict, **kw):
        super().__init__(**kw)
        self.result = result

    def compose(self):
        r    = self.result
        v    = r["verdict"]
        vc   = V_COLOR.get(v, MUT)
        info = r.get("info") or {}

        # ── Verdict banner ────────────────────────────────────────────────
        accent_cls = {
            "CRITICAL": "v-acc-critical", "HIGH": "v-acc-high",
            "MEDIUM":   "v-acc-medium",   "CLEAN": "v-acc-clean",
        }.get(v, "v-acc-unknown")

        v_icons = {
            "CRITICAL": CRITICAL, "HIGH": HIGH, "MEDIUM": MEDIUM,
            "CLEAN": CLEAN, "UNKNOWN": UNKNOWN,
        }

        with Container(id="scan-wrap"):
            with Horizontal(id="verdict-banner"):
                yield Static("", id="v-accent", classes=accent_cls)
                with Vertical(id="v-body"):
                    with Horizontal(id="v-top"):
                        yield Static(
                            f"[bold {vc}]{v_icons.get(v, UNKNOWN)}  {v}[/]",
                            id="v-icon", markup=True,
                        )
                        name = info.get("Name", r["name"])
                        ver  = info.get("Version", "")
                        mnt  = info.get("Maintainer") or f"[{RED}]ORPHANED[/]"
                        yield Static(
                            f"[bold]{escape(name)}[/]  [dim]{escape(ver)}[/]\n"
                            f"[dim]Maintainer:[/] {mnt}",
                            id="v-label", markup=True,
                        )
                    # Score bar — single widget, single line
                    with Vertical(id="v-score"):
                        score = r["score"]
                        fill  = int(score / 5)
                        bar   = (
                            f"[{vc}]{'█' * fill}[/]"
                            f"[dim]{'░' * (20 - fill)}[/]"
                        )
                        yield Static(bar, id="v-score-bar", markup=True)
                        yield Static(
                            f"Risk score  {score}/100",
                            id="v-score-label",
                        )

            # ── Tabs ──────────────────────────────────────────────────────
            nc    = sum(1 for f in r["findings"] if f["severity"] == "CRITICAL")
            nf    = len(r["findings"])
            badge = (
                f" [{RED}]{nf}[/]"   if nc else
                f" [{YEL}]{nf}[/]"   if nf else
                " 0"
            )
            with TabbedContent(id="scan-tabs"):
                with TabPane(f"{OVERVIEW} Overview",          id="tp-ov"):
                    yield self._overview()
                with TabPane(f"{FINDINGS} Findings{badge}",   id="tp-fi"):
                    yield self._findings()
                with TabPane(f"{PKGBUILD} PKGBUILD",          id="tp-pb"):
                    yield self._pkgbuild()
                if r.get("pkgbuild_changed") or r.get("diff_lines"):
                    with TabPane(f"{DIFF} Diff",              id="tp-df"):
                        yield self._diff()

    # ── Overview tab ──────────────────────────────────────────────────────────
    def _overview(self) -> Widget:
        r    = self.result
        info = r.get("info") or {}
        now  = datetime.now(timezone.utc).timestamp()
        log  = RichLog(highlight=False, markup=True, classes="ov-log")

        def sec(title: str) -> None:
            log.write(Text(f"\n  {title}", style=f"bold {ACC}"))
            log.write(Text(f"  {'─' * 48}", style=MUT))

        def row(key: str, val: str, color: str = FG) -> None:
            log.write(Text(f"  {key:<22} {val}", style=color))

        # Package metadata
        sec("Package")
        row("Name",        info.get("Name", r["name"]))
        row("Version",     info.get("Version", "—"))
        row("Description", (info.get("Description") or "—")[:60])
        mnt = info.get("Maintainer")
        log.write(Text(
            f"  {'Maintainer':<22} {mnt or 'ORPHANED'}",
            style=RED if not mnt else FG,
        ))
        for key, label in [("FirstSubmitted", "Submitted"), ("LastModified", "Last modified")]:
            ts = info.get(key, 0)
            if ts:
                age = int((now - ts) / 86400)
                row(label, f"{datetime.fromtimestamp(ts).strftime('%Y-%m-%d')}  ({age}d ago)")
        row("Votes",       str(info.get("NumVotes", 0)))
        row("Popularity",  f"{info.get('Popularity', 0):.4f}")
        if info.get("OutOfDate"):
            log.write(Text(f"  {'Out-of-date':<22} {WARN} FLAGGED", style=YEL))
        if info.get("URL"):
            row("URL", info["URL"][:64])

        # Reputation score — single block, not split across multiple writes
        sec("Reputation Score")
        vc    = V_COLOR.get(r["verdict"], MUT)
        score = r["score"]
        fill  = int(score / 5)
        # Write bar + number on ONE line using markup
        bar_markup = (
            f"  [{vc}]{'█' * fill}[/][dim]{'░' * (20 - fill)}[/]"
            f"  [bold]{score}/100[/]"
        )
        log.write(bar_markup)
        if r["score_reasons"]:
            for reason in r["score_reasons"]:
                log.write(Text(f"  {WARN}  {reason}", style=YEL))
        else:
            log.write(Text(f"  {OK}  No reputation flags", style=GRN))

        # Findings summary
        sec("Findings Summary")
        findings = r["findings"]
        if findings:
            counts = {}
            for f in findings:
                counts[f["severity"]] = counts.get(f["severity"], 0) + 1
            color_map = {"CRITICAL": RED, "HIGH": ORG, "MEDIUM": YEL, "LOW": CYN}
            parts = " · ".join(
                f"[{color_map.get(s, FG)}]{counts[s]} {s.lower()}[/]"
                for s in ("CRITICAL", "HIGH", "MEDIUM", "LOW") if s in counts
            )
            log.write(Text(f"  {WARN}  {len(findings)} total findings:", style=YEL))
            log.write(f"  {parts}")
        else:
            log.write(Text(f"  {OK}  No suspicious patterns detected", style=GRN))

        # Scan status
        sec("Scan Status")
        if r.get("pkgbuild"):
            log.write(Text(f"  {OK}  PKGBUILD  ({len(r['pkgbuild'])} bytes)", style=GRN))
        else:
            log.write(Text(f"  {FAIL}  PKGBUILD unavailable", style=RED))
        if r.get("install_file"):
            log.write(Text(f"  {OK}  .install  ({len(r['install_file'])} bytes)", style=GRN))
        else:
            log.write(Text(f"  —   No .install file", style=MUT))
        if r.get("first_seen"):
            log.write(Text(f"  {INFO}  First scan — baseline saved for future diff", style=CYN))
        elif r.get("pkgbuild_changed"):
            diff_n = r.get("diff_added", len(r.get("diff_lines", [])))
            log.write(Text(f"  {WARN}  PKGBUILD changed ({diff_n} new lines) — see Diff tab", style=YEL))
        else:
            log.write(Text(f"  {OK}  PKGBUILD unchanged since last scan", style=GRN))
        ts = r.get("scanned_at", "")
        if ts:
            log.write(Text(f"  {INFO}  Scanned at {ts}", style=MUT))
        if r.get("error"):
            log.write(Text(f"\n  {FAIL}  {r['error']}", style=RED))

        return log

    # ── Findings tab ──────────────────────────────────────────────────────────
    def _findings(self) -> Widget:
        findings = self.result["findings"]
        if not findings:
            return Static(
                f"[bold {GRN}]{CLEAN}  No suspicious patterns found.[/]\n\n"
                f"[{MUT}]This package passed all {len(self.result.get('findings', []))} "
                f"static analysis checks.[/]",
                classes="fi-empty", markup=True,
            )
        log     = RichLog(highlight=False, markup=False, classes="fi-log")
        cur_sev = None
        sev_icons = {
            "CRITICAL": CRITICAL, "HIGH": HIGH, "MEDIUM": MEDIUM, "LOW": LOW,
        }
        for f in findings:
            sev   = f["severity"]
            color = S_COLOR.get(sev, MUT)
            icon  = sev_icons.get(sev, "•")
            ag_id = f.get("ag_id", "")

            if sev != cur_sev:
                cur_sev = sev
                log.write(Text(f"\n  {icon}  {sev}", style=f"bold {color}"))
                log.write(Text(f"  {'─' * 54}", style=MUT))

            # Finding header: AG-ID + description
            log.write(Text(f"  [{ag_id}]  {f['description']}", style=color))

            # Location
            loc = f["file"]
            if f.get("line"):
                loc += f":{f['line']}"
            else:
                loc += " (content match)"
            log.write(Text(f"  {ARROW} {loc}", style=DFG))

            # Code snippet
            if f.get("content"):
                snippet = f["content"][:88]
                log.write(Text(f"       {snippet}", style=MUT))

            log.write(Text(""))
        return log

    # ── PKGBUILD tab ──────────────────────────────────────────────────────────
    def _pkgbuild(self) -> Widget:
        pb  = self.result.get("pkgbuild")
        log = RichLog(highlight=False, markup=False, classes="pb-log")
        if not pb:
            log.write(Text(f"  {FAIL}  PKGBUILD could not be fetched.", style=MUT))
            return log

        # Build per-line severity map (highest severity wins)
        sbl: dict[int, str] = {}
        for f in self.result["findings"]:
            ln = f.get("line")
            if ln and f.get("file") == "PKGBUILD":
                old = sbl.get(ln)
                if old is None or SEV_ORD[f["severity"]] < SEV_ORD[old]:
                    sbl[ln] = f["severity"]

        for i, line in enumerate(pb.splitlines(), 1):
            sev = sbl.get(i)
            if sev:
                marker = S_COLOR.get(sev, YEL)
                log.write(Text(f"{i:4}  {line}", style=f"bold {marker}"))
            elif line.strip().startswith("#"):
                log.write(Text(f"{i:4}  {line}", style=MUT))
            else:
                log.write(Text(f"{i:4}  {line}", style=FG))
        return log

    # ── Diff tab ──────────────────────────────────────────────────────────────
    def _diff(self) -> Widget:
        log = RichLog(highlight=False, markup=False, classes="df-log")
        if not self.result.get("pkgbuild_changed"):
            log.write(Text(f"  {OK}  No changes since last scan.", style=GRN))
            return log
        added = self.result.get("diff_lines", [])
        log.write(Text(
            f"\n  {WARN}  PKGBUILD changed — {len(added)} new/modified lines\n",
            style=f"bold {YEL}",
        ))
        log.write(Text(f"  {'─' * 54}", style=MUT))
        for line in added:
            log.write(Text(f"  + {line}", style=f"bold {RED}"))
        return log
