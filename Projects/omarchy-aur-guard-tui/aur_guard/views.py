"""views.py — WelcomeView, LoadingView, ScanView.

UI fixes applied vs previous version:
  [U1] Verdict banner rebuilt: flat 3-column layout (accent | left | right)
       instead of nested Vertical+Horizontal. Height reduced from 7→5.
  [U2] Score bar + number now on ONE line inline in the banner's right column,
       not in a separate sub-panel that was eating space.
  [U3] Tab labels: dropped nerd-font icon prefix on Overview/Findings/PKGBUILD
       because the specific glyphs were rendering as blank boxes on many systems.
       Plain text labels with emoji fallback — always visible.
  [U4] RichLog.scroll_home() called after writing overview so it starts at top.
  [U5] Overview sec() no longer prepends a blank line on the very first section.
  [U6] "scanned_at" formatted as "2026-06-17 15:46:05" not ISO T-separator.
  [U7] Sidebar add-input placeholder shortened to fit 30-char sidebar.
  [U8] TabPane padding: 0 (moved to log widgets) so no dead space under tabs.
  [U9] .ov-log background = BG (not DKR) so overview matches findings visually.
"""
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
    APP, CLEAN, OK, FAIL, WARN, INFO, ARROW,
)

V_COLOR: dict[str, str] = {
    "CRITICAL": RED, "HIGH": ORG, "MEDIUM": YEL, "CLEAN": GRN, "UNKNOWN": MUT, "ERROR": RED,
}
S_COLOR: dict[str, str] = {
    "CRITICAL": RED, "HIGH": ORG, "MEDIUM": YEL, "LOW": CYN,
}

# Plain text tab labels — nerd-font glyphs were rendering as blank boxes
# on systems where the specific code points aren't mapped.
TAB_OVERVIEW  = "Overview"
TAB_FINDINGS  = "Findings"
TAB_PKGBUILD  = "PKGBUILD"
TAB_DIFF      = "Diff"


# ─────────────────────────────────────────────────────────────────────────────
class WelcomeView(Widget):
    DEFAULT_CSS = f"WelcomeView {{ height: 1fr; background: {BG}; }}"

    def compose(self):
        with Container(id="welcome-wrap"):
            with Container(id="welcome-box"):
                yield Static(APP,          classes="wl-icon")
                yield Static("aur-guard",  classes="wl-title")
                yield Static(
                    "Search & add AUR packages to scan them\n"
                    "for malicious patterns before installing.",
                    classes="wl-body",
                )
                yield Static(
                    f" [bold {ACC}]Tab[/]     sidebar/main   [bold {ACC}]j / k[/]  packages\n"
                    f" [bold {ACC}]h / l[/]   result tabs    [bold {ACC}]Ctrl+J/K[/]  scroll\n"
                    f" [bold {ACC}]a[/]       add package     [bold {ACC}]S[/]  scan installed\n"
                    f" [bold {ACC}]r[/]       rescan          [bold {ACC}]d[/]  remove\n"
                    f" [bold {ACC}]e[/]       export JSON     [bold {ACC}]?[/]  help",
                    classes="wl-hint", markup=True,
                )


# ─────────────────────────────────────────────────────────────────────────────
class LoadingView(Widget):
    DEFAULT_CSS = f"LoadingView {{ height: 1fr; background: {BG}; }}"

    def __init__(self, pkgname: str = "", **kw):
        super().__init__(**kw)
        self.pkgname   = pkgname
        self._step_ref: Static | None = None

    def compose(self):
        with Container(id="loading-wrap"):
            with Container(classes="loading-box"):
                yield Static(f"Scanning {self.pkgname}", classes="loading-pkg")
                step = Static("Starting…", classes="loading-step")
                self._step_ref = step
                yield step
                yield LoadingIndicator()

    def set_step(self, msg: str) -> None:
        if self._step_ref is not None:
            try:
                self._step_ref.update(msg)
            except Exception:
                pass


# ─────────────────────────────────────────────────────────────────────────────
class ScanView(Widget):
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
        # [U1] Flat 3-column layout: accent stripe | left info | right score
        # accent colour class
        accent_cls = {
            "CRITICAL": "v-acc-critical", "HIGH": "v-acc-high",
            "MEDIUM":   "v-acc-medium",   "CLEAN": "v-acc-clean",
            "ERROR":    "v-acc-error",
        }.get(v, "v-acc-unknown")

        # Verdict symbol — ASCII safe, always renders
        v_sym = {
            "CRITICAL": "⛔", "HIGH": "⚠ ", "MEDIUM": "◆ ",
            "CLEAN":    "✓ ", "UNKNOWN": "? ", "ERROR": "! ",
        }.get(v, "? ")

        name  = info.get("Name",        r["name"])
        ver   = info.get("Version",     "")
        if v == "ERROR":
            meta_label = "Status"
            meta_value = r.get("error") or "Scan could not be completed"
            meta_color = RED
        else:
            meta_label = "Maintainer"
            meta_value = info.get("Maintainer") or "ORPHANED"
            meta_color = RED if not info.get("Maintainer") else DFG

        # [U2] Score bar rendered as a single markup string with number inline
        score = r["score"]
        fill  = max(1, int(score / 5)) if score > 0 else 0
        empty = 20 - fill
        bar_str = f"[{vc}]{'█' * fill}[/][{MUT}]{'░' * empty}[/]  [{BFG}]{score}/100[/]"
        score_label = "Scan Status" if v == "ERROR" else "Risk Score"
        if v == "ERROR":
            bar_str = f"[bold {RED}]Scan failed[/]"

        with Container(id="scan-wrap"):
            with Horizontal(id="verdict-banner"):
                yield Static("", id="v-accent", classes=accent_cls)
                with Horizontal(id="v-body"):
                    # Left column: verdict + name + maintainer
                    with Vertical(id="v-left"):
                        yield Static(
                            f"[bold {vc}]{v_sym} {v}[/]",
                            id="v-verdict-line", markup=True,
                        )
                        yield Static(
                            f"[bold {FG}]{escape(name)}[/]  [dim]{escape(ver)}[/]",
                            id="v-name-line", markup=True,
                        )
                        yield Static(
                            f"[{DFG}]{meta_label}:[/]  [{meta_color}]{escape(str(meta_value))}[/]",
                            id="v-maint-line", markup=True,
                        )
                    # Right column: score bar + score label
                    with Vertical(id="v-right"):
                        yield Static(bar_str, id="v-score-line", markup=True)
                        yield Static(
                            f"[{DFG}]{score_label}[/]",
                            id="v-score-label", markup=True,
                        )

            # ── Tabs ──────────────────────────────────────────────────────
            # [U3] Plain text labels — no nerd-font glyphs that may be blank
            nc    = sum(1 for f in r["findings"] if f["severity"] == "CRITICAL")
            nf    = len(r["findings"])
            fi_badge = (
                f"{TAB_FINDINGS} [{RED}]{nf}[/]" if nc else
                f"{TAB_FINDINGS} [{YEL}]{nf}[/]" if nf else
                f"{TAB_FINDINGS}  0"
            )
            with TabbedContent(id="scan-tabs"):
                with TabPane(TAB_OVERVIEW,    id="tp-ov"):
                    yield self._overview()
                with TabPane(fi_badge,        id="tp-fi"):
                    yield self._findings()
                with TabPane(TAB_PKGBUILD,    id="tp-pb"):
                    yield self._pkgbuild()
                if r.get("pkgbuild_changed") or r.get("diff_lines"):
                    with TabPane(TAB_DIFF,    id="tp-df"):
                        yield self._diff()

    # ── Overview tab ──────────────────────────────────────────────────────────
    def _overview(self) -> Widget:
        r    = self.result
        info = r.get("info") or {}
        now  = datetime.now(timezone.utc).timestamp()
        log  = RichLog(highlight=False, markup=True, classes="ov-log",
                       auto_scroll=False)  # [U4] prevent auto-scroll to bottom

        first_section = True

        def sec(title: str) -> None:
            nonlocal first_section
            # [U5] No blank line before the very first section
            if first_section:
                first_section = False
                log.write(Text(f"  {title}", style=f"bold {ACC}"))
            else:
                log.write(Text(f"\n  {title}", style=f"bold {ACC}"))
            log.write(Text(f"  {'─' * 48}", style=MUT))

        def row(key: str, val: str, color: str = FG) -> None:
            log.write(Text(f"  {key:<20} {val}", style=color))

        if r.get("error"):
            sec("Scan Error")
            log.write(Text(f"  {FAIL}  {r['error']}", style=f"bold {RED}"))
            if not info:
                log.write(Text("  Check the package name and try again.", style=DFG))
            else:
                log.write(Text("  AUR metadata was found, but source retrieval failed.", style=DFG))
            log.scroll_home(animate=False)
            return log

        # Package metadata
        sec("Package")
        row("Name",         info.get("Name", r["name"]))
        row("Version",      info.get("Version", "—"))
        desc = (info.get("Description") or "—")
        row("Description",  (desc[:56] + "…") if len(desc) > 56 else desc)
        mnt = info.get("Maintainer")
        log.write(Text(
            f"  {'Maintainer':<20} {mnt or 'ORPHANED'}",
            style=RED if not mnt else FG,
        ))
        for key, label in [("FirstSubmitted", "Submitted"), ("LastModified", "Last modified")]:
            ts = info.get(key, 0)
            if ts:
                age = int((now - ts) / 86400)
                row(label, f"{datetime.fromtimestamp(ts).strftime('%Y-%m-%d')}  ({age}d ago)")
        row("Votes",        str(info.get("NumVotes", 0)))
        row("Popularity",   f"{info.get('Popularity', 0):.4f}")
        if info.get("OutOfDate"):
            log.write(Text(f"  {'Out-of-date':<20} {WARN} FLAGGED", style=YEL))
        if info.get("URL"):
            url = info["URL"]
            row("URL", (url[:60] + "…") if len(url) > 60 else url)

        # Reputation score
        sec("Reputation Score")
        vc    = V_COLOR.get(r["verdict"], MUT)
        score = r["score"]
        fill  = max(1, int(score / 5)) if score > 0 else 0
        empty = 20 - fill
        log.write(
            f"  [{vc}]{'█' * fill}[/][{MUT}]{'░' * empty}[/]"
            f"  [{BFG}]{score}/100[/]"
        )
        if r["score_reasons"]:
            for reason in r["score_reasons"]:
                log.write(Text(f"  {WARN}  {reason}", style=YEL))
        else:
            log.write(Text(f"  {OK}  No reputation flags", style=GRN))

        # Findings summary
        sec("Findings Summary")
        findings = r["findings"]
        if findings:
            counts: dict[str, int] = {}
            for f in findings:
                counts[f["severity"]] = counts.get(f["severity"], 0) + 1
            color_map = {"CRITICAL": RED, "HIGH": ORG, "MEDIUM": YEL, "LOW": CYN}
            parts = "  ".join(
                f"[{color_map.get(s, FG)}]{counts[s]} {s.lower()}[/]"
                for s in ("CRITICAL", "HIGH", "MEDIUM", "LOW") if s in counts
            )
            log.write(Text(f"  {WARN}  {len(findings)} findings:", style=YEL))
            log.write(f"  {parts}")
        else:
            log.write(Text(f"  {OK}  No suspicious patterns detected", style=GRN))

        # Scan status
        sec("Scan Status")
        if r.get("pkgbuild"):
            log.write(Text(f"  {OK}  PKGBUILD   ({len(r['pkgbuild'])} bytes)", style=GRN))
        else:
            log.write(Text(f"  {FAIL}  PKGBUILD unavailable", style=RED))
        if r.get("install_file"):
            log.write(Text(f"  {OK}  .install   ({len(r['install_file'])} bytes)", style=GRN))
        else:
            log.write(Text(f"  —   No .install file", style=MUT))
        if r.get("first_seen"):
            log.write(Text(f"  {INFO}  First scan — baseline saved for future diff", style=CYN))
        elif r.get("pkgbuild_changed"):
            diff_n = r.get("diff_added", len(r.get("diff_lines", [])))
            log.write(Text(f"  {WARN}  PKGBUILD changed ({diff_n} lines) — see Diff tab", style=YEL))
        else:
            log.write(Text(f"  {OK}  PKGBUILD unchanged since last scan", style=GRN))

        # [U6] Human-readable timestamp (replace ISO T separator with space)
        ts = (r.get("scanned_at") or "").replace("T", " ")
        if ts:
            log.write(Text(f"  {INFO}  Scanned  {ts}", style=MUT))

        if r.get("error"):
            log.write(Text(f"\n  {FAIL}  {r['error']}", style=RED))

        # [U4] Scroll to top after populating
        log.scroll_home(animate=False)
        return log

    # ── Findings tab ──────────────────────────────────────────────────────────
    def _findings(self) -> Widget:
        findings = self.result["findings"]
        if self.result.get("error") and not findings:
            return Static(
                f"[bold {RED}]{FAIL}  Scan could not be completed.[/]\n\n"
                f"[{MUT}]{escape(str(self.result.get('error')))}[/]",
                classes="fi-empty", markup=True,
            )
        if not findings:
            return Static(
                f"[bold {GRN}]{CLEAN}  No suspicious patterns found.[/]\n\n"
                f"[{MUT}]Package passed all static analysis checks.[/]",
                classes="fi-empty", markup=True,
            )

        log     = RichLog(highlight=False, markup=False, classes="fi-log",
                          auto_scroll=False)
        cur_sev = None
        sev_syms = {
            "CRITICAL": "⛔", "HIGH": "⚠ ", "MEDIUM": "◆ ", "LOW": "ℹ ",
        }

        for f in findings:
            sev   = f["severity"]
            color = S_COLOR.get(sev, MUT)
            sym   = sev_syms.get(sev, "• ")
            ag_id = f.get("ag_id", "")

            if sev != cur_sev:
                cur_sev = sev
                log.write(Text(f"\n  {sym} {sev}", style=f"bold {color}"))
                log.write(Text(f"  {'─' * 54}", style=MUT))

            log.write(Text(f"  [{ag_id}]  {f['description']}", style=color))
            loc = f["file"] + (f":{f['line']}" if f.get("line") else " (content match)")
            log.write(Text(f"  {ARROW} {loc}", style=DFG))
            if f.get("content"):
                log.write(Text(f"       {f['content'][:88]}", style=MUT))
            log.write(Text(""))

        log.scroll_home(animate=False)
        return log

    # ── PKGBUILD tab ──────────────────────────────────────────────────────────
    def _pkgbuild(self) -> Widget:
        pb  = self.result.get("pkgbuild")
        log = RichLog(highlight=False, markup=False, classes="pb-log",
                      auto_scroll=False)
        if not pb:
            log.write(Text(f"  {FAIL}  PKGBUILD could not be fetched.", style=MUT))
            return log

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
                log.write(Text(f"{i:4}  {line}", style=f"bold {S_COLOR.get(sev, YEL)}"))
            elif line.strip().startswith("#"):
                log.write(Text(f"{i:4}  {line}", style=MUT))
            else:
                log.write(Text(f"{i:4}  {line}", style=FG))

        log.scroll_home(animate=False)
        return log

    # ── Diff tab ──────────────────────────────────────────────────────────────
    def _diff(self) -> Widget:
        """[SEC-8] Now shows true unified diff (added + removed lines)."""
        log = RichLog(highlight=False, markup=False, classes="df-log",
                      auto_scroll=False)
        if not self.result.get("pkgbuild_changed"):
            log.write(Text(f"  {OK}  No changes since last scan.", style=GRN))
            return log
        added   = self.result.get("diff_lines", [])
        total   = self.result.get("diff_changed", len(added))
        log.write(Text(
            f"\n  {WARN}  PKGBUILD changed — {len(added)} additions, {total} total changes\n",
            style=f"bold {YEL}",
        ))
        log.write(Text(f"  {'─' * 60}", style=MUT))
        log.write(Text(f"  (+ added lines shown; use r to rescan for full unified diff)", style=MUT))
        log.write(Text(""))
        for line in added:
            stripped = line.lstrip()
            if stripped:
                log.write(Text(f"  + {line}", style=f"bold {RED}"))
        if not added:
            log.write(Text(f"  {WARN}  Content changed (no new lines — likely modifications)", style=YEL))
        log.scroll_home(animate=False)
        return log
