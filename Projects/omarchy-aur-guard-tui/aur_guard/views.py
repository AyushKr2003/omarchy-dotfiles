from __future__ import annotations
from datetime import datetime, timezone
from textual.containers import Container, Horizontal, Vertical, ScrollableContainer
from textual.css.query import NoMatches
from textual.widget import Widget
from textual.widgets import LoadingIndicator, RichLog, Static, TabbedContent, TabPane
from rich.text import Text
from rich.markup import escape
from .theme import BG, DBG, LBG, MUT, DFG, FG, BFG, ACC, RED, YEL, GRN, CYN, ORG
from .scanner import SEV_ORD

V_COLOR = {"CRITICAL":RED,"HIGH":ORG,"MEDIUM":YEL,"CLEAN":GRN,"UNKNOWN":MUT}
S_COLOR = {"CRITICAL":RED,"HIGH":ORG,"MEDIUM":YEL,"LOW":CYN}

class WelcomeView(Widget):
    DEFAULT_CSS = f"WelcomeView {{ height: 1fr; background: {BG}; }}"
    def compose(self):
        with Container(id="welcome-wrap"):
            with Container(id="welcome-box"):
                yield Static("\U000f04d3", classes="wl-icon")
                yield Static("aur-guard", classes="wl-title")
                yield Static(
                    "Search & add AUR packages to scan them\n"
                    "for malicious patterns before installing.",
                    classes="wl-body",
                )
                yield Static(
                    f" [bold {ACC}]j/k[/]  navigate    [bold {ACC}]/[/]  search\n"
                    f" [bold {ACC}]a[/]    add pkg     [bold {ACC}]S[/]  scan all installed\n"
                    f" [bold {ACC}]r[/]    rescan      [bold {ACC}]d[/]  remove\n"
                    f" [bold {ACC}]e[/]    export      [bold {ACC}]Ctrl+H[/]  help",
                    classes="wl-hint", markup=True,
                )

class LoadingView(Widget):
    DEFAULT_CSS = f"LoadingView {{ height: 1fr; background: {BG}; }}"
    def __init__(self, pkgname:str="", **kw):
        super().__init__(**kw)
        self.pkgname = pkgname
    def compose(self):
        with Container(id="loading-wrap"):
            with Container(id="loading-box"):
                yield Static(f"\U000f04d3  Scanning {self.pkgname}", id="loading-pkg")
                yield Static("Starting...", id="loading-step")
                yield LoadingIndicator()
    def set_step(self, msg:str) -> None:
        try: self.query_one("#loading-step", Static).update(msg)
        except NoMatches: pass

class ScanView(Widget):
    DEFAULT_CSS = f"ScanView {{ height: 1fr; background: {BG}; }}"
    def __init__(self, result:dict, **kw):
        super().__init__(**kw)
        self.result = result

    def compose(self):
        r    = self.result
        v    = r["verdict"]
        vc   = V_COLOR.get(v, MUT)
        info = r.get("info") or {}

        with Container(id="scan-wrap"):
            with Horizontal(id="verdict-banner"):
                accents = {"CRITICAL":"v-acc-critical","HIGH":"v-acc-high","MEDIUM":"v-acc-medium","CLEAN":"v-acc-clean","UNKNOWN":"v-acc-unknown"}
                yield Static("", id="v-accent", classes=accents.get(v,"v-acc-unknown"))
                with Vertical(id="v-body"):
                    with Horizontal(id="v-top"):
                        icons = {"CRITICAL":"\U000f068c ","HIGH":"\uf071 ","MEDIUM":"\uf071 ","CLEAN":"\U000f0e1e ","UNKNOWN":"\uf110 "}
                        yield Static(f"[bold {vc}]{icons.get(v,' ')}{v}[/]", id="v-icon", markup=True)
                        name = info.get("Name", r["name"])
                        ver  = info.get("Version","")
                        mnt  = info.get("Maintainer") or f"[{RED}]ORPHANED[/]"
                        yield Static(
                            f"[bold]{escape(name)}[/]  [dim]{escape(ver)}[/]\n[dim]Maintainer:[/] {mnt}",
                            id="v-label", markup=True,
                        )
                    score = r["score"]
                    fill  = int(score/5)
                    bar   = f"[{vc}]{'█'*fill}[/][dim]{'░'*(20-fill)}[/]"
                    yield Static(f"{bar}  [dim]Risk score {score}/100[/]", id="v-score", markup=True)

            nc = sum(1 for f in r["findings"] if f["severity"]=="CRITICAL")
            nf = len(r["findings"])
            badge = f" [{RED}]{nf}[/]" if nc else (f" [{YEL}]{nf}[/]" if nf else " 0")
            with TabbedContent(id="scan-tabs"):
                with TabPane("\U000f02fd Overview",    id="tp-ov"): yield self._overview()
                with TabPane(f" Findings{badge}",  id="tp-fi"): yield self._findings()
                with TabPane(" PKGBUILD",          id="tp-pb"): yield self._pkgbuild()
                if r["pkgbuild_changed"] or r["diff_lines"]:
                    with TabPane(" Diff",          id="tp-df"): yield self._diff()

    def _overview(self) -> Widget:
        r,info = self.result, self.result.get("info") or {}
        now = datetime.now(timezone.utc).timestamp()
        log = RichLog(highlight=False, markup=True, classes="ov-log")

        def sec(t):
            log.write(Text(f"\n  {t}", style=f"bold {ACC}"))
            log.write(Text(f"  {'─'*44}", style=MUT))
        def row(k, v, c=FG):
            log.write(Text(f"  {k:<22} {v}", style=c))

        sec("Package")
        row("Name",        info.get("Name", r["name"]))
        row("Version",     info.get("Version", "\u2014"))
        row("Description", (info.get("Description") or "\u2014")[:60])
        mnt = info.get("Maintainer")
        log.write(Text(f"  {'Maintainer':<22} {mnt or 'ORPHANED'}", style=RED if not mnt else FG))
        for k,lbl in [("FirstSubmitted","Submitted"),("LastModified","Last modified")]:
            ts = info.get(k,0)
            if ts:
                age = int((now-ts)/86400)
                row(lbl, f"{datetime.fromtimestamp(ts).strftime('%Y-%m-%d')}  ({age}d ago)")
        row("Votes",      str(info.get("NumVotes", 0)))
        row("Popularity", f"{info.get('Popularity', 0):.4f}")
        if info.get("OutOfDate"):
            log.write(Text(f"  {'Out-of-date':<22} \u26a0 FLAGGED", style=YEL))
        if info.get("URL"):
            row("URL", info["URL"][:64])

        sec("Reputation Score")
        vc   = V_COLOR.get(r["verdict"], MUT)
        fill = int(r["score"]/5)
        bar  = Text.from_markup(f"[{vc}]{'█'*fill}[/][dim]{'░'*(20-fill)}[/]")
        log.write(Text(f"  Score:  ", style=DFG))
        log.write(Text(f"  {bar} ", style=MUT))
        log.write(Text(f"  {r['score']}/100", style=BFG))
        if r["score_reasons"]:
            for reason in r["score_reasons"]:
                log.write(Text(f"  \u26a0  {reason}", style=YEL))
        else:
            log.write(Text(f"  \u2713  No reputation flags", style=GRN))

        sec("Findings Summary")
        findings = r["findings"]
        if findings:
            nc = sum(1 for f in findings if f["severity"]=="CRITICAL")
            nh = sum(1 for f in findings if f["severity"]=="HIGH")
            nm = sum(1 for f in findings if f["severity"]=="MEDIUM")
            nl = sum(1 for f in findings if f["severity"]=="LOW")
            parts = []
            if nc: parts.append(f"[{RED}]{nc} critical[/]")
            if nh: parts.append(f"[{ORG}]{nh} high[/]")
            if nm: parts.append(f"[{YEL}]{nm} medium[/]")
            if nl: parts.append(f"[{CYN}]{nl} low[/]")
            log.write(Text(f"  \u26a0  {len(findings)} total:", style=YEL))
            log.write(Text.from_markup(f"  {'  \u00b7  '.join(parts)}"))
        else:
            log.write(Text("  \u2713  No suspicious patterns detected", style=GRN))

        sec("Scan Status")
        if r.get("pkgbuild"):
            log.write(Text(f"  \u2713  PKGBUILD  ({len(r['pkgbuild'])} bytes)", style=GRN))
        else:
            log.write(Text("  \u2717  PKGBUILD unavailable", style=RED))
        if r.get("install_file"):
            log.write(Text(f"  \u2713  .install  ({len(r['install_file'])} bytes)", style=GRN))
        else:
            log.write(Text("  \u2014  No .install file", style=MUT))
        if r.get("first_seen"):
            log.write(Text("  \u2139  First scan \u2014 baseline saved", style=CYN))
        elif r.get("pkgbuild_changed"):
            log.write(Text("  \u26a0  PKGBUILD changed since last scan", style=YEL))
        else:
            log.write(Text("  \u2713  PKGBUILD unchanged since last scan", style=GRN))

        if r.get("error"):
            log.write(Text(f"\n  \u2717  {r['error']}", style=RED))
        return log

    def _findings(self) -> Widget:
        findings = self.result["findings"]
        if not findings:
            return Static(
                f"[bold {GRN}]\U000f0e1e  No suspicious patterns found.[/]\n\n"
                f"[{MUT}]This package passed all static analysis checks.[/]",
                classes="fi-empty", markup=True,
            )
        log = RichLog(highlight=False, markup=False, classes="fi-log")
        cur = None
        icons = {"CRITICAL":"\U000f068c","HIGH":"\uf071","MEDIUM":"\uf071","LOW":""}
        for f in findings:
            sev = f["severity"]
            c   = S_COLOR.get(sev, MUT)
            if sev != cur:
                cur = sev
                log.write(Text(f"\n  {icons.get(sev,'\u2022')}  {sev}", style=f"bold {c}"))
                log.write(Text(f"  {'─'*50}", style=MUT))
            log.write(Text(f"  {f['description']}", style=c))
            loc = f"{f['file']}"
            if f.get("line"): loc += f":{f['line']}"
            else:             loc += " (content match)"
            log.write(Text(f"  [{loc}]", style=DFG))
            if f.get("content"):
                log.write(Text(f"  \u2514\u2500 {f['content'][:88]}", style=MUT))
        return log

    def _pkgbuild(self) -> Widget:
        pb  = self.result.get("pkgbuild")
        log = RichLog(highlight=False, markup=False, classes="pb-log")
        if not pb:
            log.write(Text("  PKGBUILD could not be fetched.", style=MUT)); return log
        sbl: dict[int,str] = {}
        for f in self.result["findings"]:
            ln = f.get("line")
            if ln and f.get("file")=="PKGBUILD":
                old = sbl.get(ln)
                if old is None or SEV_ORD[f["severity"]] < SEV_ORD[old]:
                    sbl[ln] = f["severity"]
        for i,line in enumerate(pb.splitlines(),1):
            sev = sbl.get(i)
            if sev:   log.write(Text(f"{i:4}  {line}", style=f"bold {S_COLOR.get(sev,YEL)}"))
            elif line.strip().startswith("#"): log.write(Text(f"{i:4}  {line}", style=MUT))
            else:     log.write(Text(f"{i:4}  {line}", style=FG))
        return log

    def _diff(self) -> Widget:
        log = RichLog(highlight=False, markup=False, classes="df-log")
        if not self.result.get("pkgbuild_changed"):
            log.write(Text("  No changes since last scan.", style=GRN)); return log
        log.write(Text(f"\n  PKGBUILD changed since last scan\n", style=f"bold {YEL}"))
        log.write(Text("  New or changed lines:\n", style=MUT))
        for line in self.result.get("diff_lines",[]):
            log.write(Text(f"  + {line}", style=f"bold {RED}"))
        return log
