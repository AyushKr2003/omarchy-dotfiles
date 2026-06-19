"""
app.py — AurGuardApp main Textual application.

Improvements vs v3:
  [DEV-1]  Added g/G keybindings for jump to top/bottom of package list
  [DEV-3]  Package name validation before adding (AUR format check)
  [DEV-4]  Cache TTL (7 days) enforced in load_cache()
  [DEV-5]  Fixed action_remove_pkg: save pkg name BEFORE pop()
  [DEV-6]  Added scroll-in-tab with Ctrl+J/Ctrl+K (vim-style)
  [DEV-7]  Batch scan loading view updates per-package correctly
  [DEV-8]  Session persistence: packages saved to ~/.config/aur-guard/session.json
  [DEV-9]  Results dict access uses copy-on-read pattern to avoid threading issues
  [SEC-3]  New 'C' keybinding launches IoC compromise check overlay
"""
from __future__ import annotations

import json
import time
from datetime import datetime
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical, ScrollableContainer
from textual.css.query import NoMatches
from textual.widget import Widget
from textual.widgets import Button, Footer, Input, ProgressBar, RichLog, Static
from textual import events, work

from .theme import T, DBG, ACC, DFG, MUT, RED, ORG, YEL, GRN, CYN, FG, BFG
from .css import CSS
from .scanner import (
    CACHE_DIR,
    get_installed_aur, full_scan, is_valid_pkg_name,
    load_session, save_session,
)
from .ioc import IocChecker
from .threats import refresh_threat_list
from .widgets import PkgItem
from .views import WelcomeView, LoadingView, ScanView
from .icons import APP, HELP, WARN, OK, FAIL, INFO

MIN_WIDTH  = 100
MIN_HEIGHT = 28


class AurGuardApp(App):
    CSS   = CSS
    TITLE = "aur-guard"

    BINDINGS = [
        # Navigation — vim style
        Binding("j",        "cursor_down",    "↓ down",    show=True),
        Binding("k",        "cursor_up",      "↑ up",      show=True),
        Binding("g",        "cursor_top",     "g top",     show=False),
        Binding("G",        "cursor_bottom",  "G bottom",  show=False),   # [DEV-1]
        # Tab content scroll
        Binding("ctrl+j",   "scroll_down",    "",          show=False),   # [DEV-6]
        Binding("ctrl+k",   "scroll_up",      "",          show=False),   # [DEV-6]
        # Sidebar
        Binding("slash",    "focus_search",   "/ search",  show=True),
        Binding("a",        "focus_add",      "a add",     show=True),
        Binding("d",        "remove_pkg",     "d remove",  show=False),
        # Scan actions
        Binding("r",        "rescan",         "r rescan",  show=True),
        Binding("ctrl+r",   "refresh_threats","refresh",   show=False),
        Binding("S",        "scan_installed", "S scan ∀",  show=True),
        Binding("c",        "check_ioc_quick","c check",   show=True),
        Binding("C",        "check_ioc_full", "C full",    show=True),    # [SEC-3]
        Binding("A",        "toggle_all_time","A all-time",show=False),
        Binding("e",        "export",         "e export",  show=True),
        # UI
        Binding("question_mark", "toggle_help", "? help",  show=True),
        Binding("escape",   "escape_all",     "",          show=False),
        Binding("q",        "quit",           "q quit",    show=True),
        Binding("ctrl+c",   "quit",           "",          show=False),
    ]

    def __init__(self, preload: list[str] | None = None):
        super().__init__()
        # [DEV-8] Load previous session, then apply CLI preload on top
        session_pkgs = load_session()
        cli_pkgs     = list(preload or [])
        combined     = list(session_pkgs)
        for p in cli_pkgs:
            if p not in combined:
                combined.append(p)
        self._packages:   list[str]       = combined
        self._results:    dict[str, dict] = {}
        self._sel:        int             = -1
        self._scanning:   set[str]        = set()
        self._too_small:  bool            = False
        self._list_items: list[PkgItem]   = []
        self._ioc_all_time: bool          = False

    # ── Compose ───────────────────────────────────────────────────────────────
    def compose(self) -> ComposeResult:
        with Horizontal(id="header-bar"):
            yield Static(f"{APP}  aur-guard",       id="app-title")
            yield Static("│",                        id="header-divider")
            yield Static(f" {T['name']}",            id="theme-badge")
            yield Static("│  0 packages",            id="header-counts")
            yield Static("AUR Security Scanner",     id="header-status")

        with Horizontal(id="main-layout"):
            with Vertical(id="sidebar"):
                yield Static("  Packages",           id="sidebar-title")
                yield Input(
                    placeholder="Search AUR…",
                    id="pkg-search",
                    select_on_focus=False,
                )
                yield ScrollableContainer(id="pkg-list")
                with Horizontal(id="add-pkg-bar"):
                    yield Input(placeholder="Pkg Name", id="add-pkg-input")
                    yield Button("Add", id="btn-add")

            with Container(id="content-area"):
                yield WelcomeView()

        yield Footer()

        # Too-small notice
        with Container(id="too-small-overlay"):
            with Container(id="too-small-box"):
                yield Static("󰹍",                         classes="ts-icon")
                yield Static("Terminal too small",         classes="ts-title")
                yield Static("", id="ts-body",             classes="ts-body")
                yield Static("Resize your terminal to continue.", classes="ts-hint")

        # Batch scan progress
        with Container(id="batch-overlay"):
            with Container(id="batch-box"):
                yield Static(f"{APP} Scanning Installed Packages", classes="bt-title")
                yield Static("", id="batch-pkg",  classes="bt-pkg")
                yield ProgressBar(total=100,       id="batch-bar")
                yield Static("", id="batch-count", classes="bt-count")

        # IoC check overlay  [SEC-3]
        with Container(id="ioc-overlay"):
            with Container(id="ioc-box"):
                yield Static(f"{WARN}  Compromise Check",       id="ioc-title", classes="ioc-title")
                yield Static("Scanning system for IoCs…",       id="ioc-status")
                yield RichLog(highlight=False, markup=True,     id="ioc-log",
                              auto_scroll=False)
                yield Static("Press Esc to close", classes="ioc-hint")

        # Help overlay
        with Container(id="help-overlay"):
            with Container(id="help-box"):
                yield Static(f"{HELP}  Keybindings", classes="help-title")
                yield from self._help_rows()

    def on_mount(self) -> None:
        if self._packages:
            self._sync_list()
            self._select(0)
        self.set_timer(0.1, lambda: self.screen.set_focus(None))

    # ── Help ──────────────────────────────────────────────────────────────────
    def _help_rows(self):
        pairs = [
            ("j / k",         "Navigate package list"),
            ("g / G",         "Jump to top / bottom"),
            ("Ctrl+J / Ctrl+K", "Scroll content up/down"),
            ("/",             "Focus search bar"),
            ("a",             "Add package by name"),
            ("r",             "Rescan selected package"),
            ("Ctrl+R",         "Refresh infected package list"),
            ("S",             "Scan all installed AUR packages"),
            ("c / C",          "Quick / full compromise check"),
            ("A",              "Toggle IoC all-time date mode"),
            ("d",             "Remove package from list"),
            ("e",             "Export JSON report"),
            ("?",             "Toggle this help"),
            ("Esc",           "Dismiss overlays / unfocus"),
            ("q / Ctrl+C",    "Quit"),
        ]
        for key, desc in pairs:
            yield Static(
                f"  [bold {ACC}]{key:<22}[/]  [{DFG}]{desc}[/]",
                classes="help-row", markup=True,
            )
        yield Static("  Press  ?  or  Esc  to close", classes="help-hint")

    # ── Resize ────────────────────────────────────────────────────────────────
    def on_resize(self, event: events.Resize) -> None:
        w, h  = event.size.width, event.size.height
        small = w < MIN_WIDTH or h < MIN_HEIGHT
        if small != self._too_small:
            self._too_small = small
            try:
                self.query_one("#too-small-overlay").display = small
                if small:
                    self.query_one("#ts-body", Static).update(
                        f"Current:  {w} × {h}\nRequired: {MIN_WIDTH} × {MIN_HEIGHT} minimum"
                    )
            except NoMatches:
                pass

    # ── Sidebar pool ──────────────────────────────────────────────────────────
    def _sync_list(self, filter_q: str = "") -> None:
        pkg_list = self.query_one("#pkg-list", ScrollableContainer)
        self._update_header_counts()
        while len(self._list_items) < len(self._packages):
            idx  = len(self._list_items)
            item = PkgItem(index=idx, pkgname=self._packages[idx], verdict_="UNKNOWN")
            self._list_items.append(item)
            pkg_list.mount(item)
        for i, item in enumerate(self._list_items):
            if i < len(self._packages):
                pkg     = self._packages[i]
                # [DEV-9] Read result dict once to avoid TOCTOU
                result  = self._results.get(pkg)
                verd    = result["verdict"] if result else "UNKNOWN"
                active  = (i == self._sel)
                visible = not filter_q or filter_q.lower() in pkg.lower()
                item.pkg_index = i
                item.pkgname   = pkg
                item.display   = visible
                item.update_state(verd, active)
            else:
                item.display = False

    def _update_header_counts(self) -> None:
        done = sum(1 for p in self._packages if self._results.get(p, {}).get("info"))
        mode = "all-time" if self._ioc_all_time else "window"
        try:
            self.query_one("#header-counts", Static).update(
                f"│  {len(self._packages)} packages  ·  {done} scanned  ·  IoC {mode}"
            )
        except NoMatches:
            pass

    # ── Selection ─────────────────────────────────────────────────────────────
    def _select(self, idx: int) -> None:
        if not self._packages:
            return
        clamped = max(0, min(idx, len(self._packages) - 1))
        if clamped == self._sel and idx != clamped:
            return
        self._sel = clamped
        self._sync_list()
        pkg = self._packages[self._sel]
        if pkg in self._results:
            self._set_content(ScanView(self._results[pkg]))
        elif pkg not in self._scanning:
            self._launch_scan(pkg)

    def on_pkg_item_selected(self, msg: PkgItem.Selected) -> None:
        self._select(msg.index)

    # ── Content panel ─────────────────────────────────────────────────────────
    def _set_content(self, w: Widget) -> None:
        area = self.query_one("#content-area", Container)
        area.remove_children()
        area.mount(w)

    def _show_welcome(self) -> None:
        self._set_content(WelcomeView())

    def _show_result(self, r: dict) -> None:
        self._set_content(ScanView(r))

    def _show_loading(self, pkg: str = "") -> LoadingView:
        lv = LoadingView(pkgname=pkg)
        self._set_content(lv)
        return lv

    # ── Workers ───────────────────────────────────────────────────────────────
    @work(thread=True)
    def _launch_scan(self, pkgname: str) -> None:
        self._scanning.add(pkgname)
        lv: LoadingView | None = None

        def show_lv() -> None:
            nonlocal lv
            lv = self._show_loading(pkgname)

        self.call_from_thread(show_lv)
        time.sleep(0.05)

        result = full_scan(
            pkgname,
            prog=lambda m: lv and self.call_from_thread(lv.set_step, m),
        )
        self._results[pkgname] = result
        self._scanning.discard(pkgname)

        # [DEV-8] Save session after every scan completes
        self.call_from_thread(
            lambda: save_session(self._packages)
        )

        def done() -> None:
            self._sync_list()
            if 0 <= self._sel < len(self._packages) and self._packages[self._sel] == pkgname:
                self._show_result(result)

        self.call_from_thread(done)

    @work(thread=True)
    def _batch_scan(self, packages: list[str]) -> None:
        total = len(packages)

        def show_overlay() -> None:
            try:
                self.query_one("#batch-overlay").display = True
                pb = self.query_one("#batch-bar", ProgressBar)
                pb.total    = total
                pb.progress = 0
            except NoMatches:
                pass

        self.call_from_thread(show_overlay)

        for i, pkg in enumerate(packages):
            def update_ui(i: int = i, pkg: str = pkg) -> None:
                try:
                    self.query_one("#batch-pkg",   Static).update(f"Scanning: {pkg}")
                    self.query_one("#batch-bar",   ProgressBar).progress = i
                    self.query_one("#batch-count", Static).update(f"{i} / {total}")
                except NoMatches:
                    pass

            self.call_from_thread(update_ui)

            # [DEV-7] Per-package progress updates to batch-pkg label
            def pkg_prog(msg: str, pkg: str = pkg) -> None:
                try:
                    self.query_one("#batch-pkg", Static).update(f"{pkg}  —  {msg}")
                except (NoMatches, Exception):
                    pass

            self._results[pkg] = full_scan(pkg, prog=pkg_prog)

        def done() -> None:
            try:
                self.query_one("#batch-overlay").display = False
            except NoMatches:
                pass
            save_session(self._packages)
            self._sync_list()
            if self._packages:
                self._select(max(self._sel, 0))

        self.call_from_thread(done)

    @work(thread=True)
    def _run_ioc_check(self, full: bool = False) -> None:
        """[SEC-3] Run IoC compromise detection in background."""
        checker = IocChecker(all_time=self._ioc_all_time)
        mode_name = "Full" if full else "Quick"

        def show_overlay() -> None:
            try:
                self.query_one("#ioc-overlay").display = True
                self.query_one("#ioc-title", Static).update(f"{WARN}  {mode_name} Compromise Check")
                self.query_one("#ioc-status", Static).update("Scanning system for IoCs...")
                log = self.query_one("#ioc-log", RichLog)
                log.clear()
            except NoMatches:
                pass

        self.call_from_thread(show_overlay)

        def update_status(msg: str) -> None:
            try:
                self.query_one("#ioc-status", Static).update(msg)
            except NoMatches:
                pass

        self.call_from_thread(update_status, "Checking installed packages and pacman logs...")
        results = checker.check_all(
            systemd=full,
            ebpf=full,
            npm_cache=full,
            bun_cache=full,
            process_hiding=full,
        )
        severity = checker.severity(results)

        def show_results() -> None:
            try:
                log  = self.query_one("#ioc-log", RichLog)
                log.clear()
                sev_color = {"CRITICAL": RED, "HIGH": ORG, "CLEAN": GRN}.get(severity, YEL)

                if not checker.has_iocs(results):
                    log.write(f"[bold {GRN}]{OK}  No indicators of compromise found.[/]")
                    log.write(f"[{MUT}]  System appears clean from known AUR malware.[/]")
                else:
                    log.write(f"[bold {sev_color}]{WARN}  IoC findings — {severity}[/]")
                    log.write("")

                log.write(
                    f"[{MUT}]  Threat packages: {results.get('threat_packages_loaded', 0)}"
                    f"  ·  npm/bun names: {results.get('malicious_npm_loaded', 0)}"
                    f"  ·  Window: {results.get('date_window', 'unknown')}"
                    f"  ·  Exit: {results.get('exit_code', 0)}[/]"
                )
                enabled = results.get("enabled_checks", {})
                log.write(
                    f"[{MUT}]  Optional checks: "
                    f"systemd={enabled.get('systemd')}  "
                    f"eBPF={enabled.get('ebpf')}  "
                    f"npm={enabled.get('npm_cache')}  "
                    f"bun={enabled.get('bun_cache')}[/]"
                )
                log.write("")

                checks = [
                    ("ebpf_artifacts",     "eBPF rootkit artifacts", RED),
                    ("ld_preload",         "/etc/ld.so.preload injection", RED),
                    ("process_hiding",     "Hidden processes", RED),
                    ("installed_infected", "Risk-listed packages currently installed", ORG),
                    ("pacman_log_hits",    "Risk-listed packages in pacman logs", ORG),
                    ("suspicious_systemd", "Suspicious systemd services", ORG),
                    ("npm_cache",          "Malicious npm cache/global modules", YEL),
                    ("bun_cache",          "Malicious bun cache entries", YEL),
                ]
                for key, label, color in checks:
                    items = results.get(key, [])
                    if items:
                        log.write(f"[bold {color}]{WARN}  {label}:[/]")
                        for item in items[:5]:
                            if isinstance(item, dict):
                                if key == "installed_infected":
                                    detail = f"{item.get('name')} installed={item.get('install_date') or 'unknown'}"
                                elif key == "pacman_log_hits":
                                    detail = f"{item.get('package')} {item.get('action')} on {item.get('date')}"
                                elif key in ("npm_cache", "bun_cache", "suspicious_systemd"):
                                    detail = (
                                        f"{item.get('package')} in {item.get('location')}: "
                                        f"{item.get('path')}"
                                    )
                                else:
                                    detail = str(item)
                            else:
                                detail = str(item)
                            log.write(f"[{color}]     → {detail[:100]}[/]")
                        if len(items) > 5:
                            log.write(f"[{MUT}]       … {len(items) - 5} more[/]")
                    else:
                        log.write(f"[{GRN}]{OK}  {label}: clean[/]")

                if checker.has_iocs(results):
                    log.write("")
                    log.write(f"[bold {RED}]!  If an infected package was installed, treat system as COMPROMISED.[/]")
                    log.write(f"[{YEL}]   Rotate: SSH keys, GitHub tokens, browser sessions, Slack, Discord.[/]")
                    log.write(f"[{YEL}]   Consider: full reinstall from clean media.[/]")

                self.query_one("#ioc-status", Static).update(
                    f"Check complete — {severity}"
                )
                log.scroll_home(animate=False)
            except NoMatches:
                pass

        self.call_from_thread(show_results)

    @work(thread=True)
    def _refresh_threat_lists(self) -> None:
        def started() -> None:
            self.notify("Refreshing infected package list...", severity="information", timeout=3)

        self.call_from_thread(started)
        ok, message, count = refresh_threat_list()

        def done() -> None:
            if ok:
                self.notify(f"Threat list refreshed: {count} packages -> {message}", severity="information", timeout=6)
            else:
                self.notify(f"Threat list refresh failed: {message}", severity="error", timeout=7)

        self.call_from_thread(done)

    # ── Actions ───────────────────────────────────────────────────────────────
    def action_cursor_down(self) -> None:
        self._select(self._sel + 1)

    def action_cursor_up(self) -> None:
        self._select(self._sel - 1)

    def action_cursor_top(self) -> None:                      # [DEV-1]
        self._select(0)

    def action_cursor_bottom(self) -> None:                   # [DEV-1]
        self._select(len(self._packages) - 1)

    def action_scroll_down(self) -> None:                     # [DEV-6]
        """Scroll active RichLog content down."""
        try:
            for log in self.query("RichLog"):
                if log.display:
                    log.scroll_down(animate=False)
                    break
        except Exception:
            pass

    def action_scroll_up(self) -> None:                       # [DEV-6]
        """Scroll active RichLog content up."""
        try:
            for log in self.query("RichLog"):
                if log.display:
                    log.scroll_up(animate=False)
                    break
        except Exception:
            pass

    def action_focus_search(self) -> None:
        self.query_one("#pkg-search", Input).focus()

    def action_focus_add(self) -> None:
        self.query_one("#add-pkg-input", Input).focus()

    def action_toggle_help(self) -> None:
        try:
            overlay = self.query_one("#help-overlay")
            overlay.display = not overlay.display
        except NoMatches:
            pass

    def _toggle_ioc_overlay_or_run(self, full: bool) -> None:
        try:
            overlay = self.query_one("#ioc-overlay")
            if overlay.display:
                overlay.display = False
                return
        except NoMatches:
            pass
        self._run_ioc_check(full)

    def action_check_ioc_quick(self) -> None:
        self._toggle_ioc_overlay_or_run(False)

    def action_check_ioc_full(self) -> None:                  # [SEC-3]
        self._toggle_ioc_overlay_or_run(True)

    def action_toggle_all_time(self) -> None:
        self._ioc_all_time = not self._ioc_all_time
        self._update_header_counts()
        mode = "all-time" if self._ioc_all_time else "June 9-12 campaign window"
        self.notify(f"IoC date mode: {mode}", severity="information", timeout=4)

    def action_refresh_threats(self) -> None:
        self._refresh_threat_lists()

    def action_escape_all(self) -> None:
        for overlay_id in ("#help-overlay", "#ioc-overlay"):
            try:
                overlay = self.query_one(overlay_id)
                if overlay.display:
                    overlay.display = False
                    return
            except NoMatches:
                pass
        self.screen.set_focus(None)

    def action_rescan(self) -> None:
        if self._sel < 0 or not self._packages:
            return
        pkg = self._packages[self._sel]
        (CACHE_DIR / f"{pkg}.json").unlink(missing_ok=True)
        self._results.pop(pkg, None)
        self._launch_scan(pkg)

    def action_remove_pkg(self) -> None:
        """
        [DEV-5] Fixed: save pkg name BEFORE pop() — otherwise _packages[idx]
        refers to the next package after removal.
        """
        if self._sel < 0 or not self._packages:
            return
        idx      = self._sel
        pkg_name = self._packages[idx]           # save BEFORE pop
        self._packages.pop(idx)
        self._results.pop(pkg_name, None)
        self._scanning.discard(pkg_name)

        if self._list_items:
            removed_widget = self._list_items.pop()
            removed_widget.remove()

        self._sel = min(idx, len(self._packages) - 1)
        self._sync_list()
        save_session(self._packages)             # [DEV-8]

        if self._packages:
            self._select(self._sel)
        else:
            self._show_welcome()

    def action_scan_installed(self) -> None:
        pkgs = get_installed_aur()
        if not pkgs:
            self._show_loading("(no AUR packages found — pacman -Qm returned nothing)")
            return
        for p in pkgs:
            if p not in self._packages:
                self._packages.append(p)
        self._sync_list()
        save_session(self._packages)
        self._batch_scan(pkgs)

    def action_export(self) -> None:
        if self._sel < 0 or not self._packages:
            return
        pkg = self._packages[self._sel]
        if pkg not in self._results:
            self.notify("No scan result yet — run a scan first.", severity="warning")
            return
        export_dir = CACHE_DIR / "exports"
        export_dir.mkdir(parents=True, exist_ok=True)
        ts   = datetime.now().strftime("%Y%m%d_%H%M%S")
        path = export_dir / f"aur-guard-{pkg}-{ts}.json"
        try:
            path.write_text(json.dumps(self._results[pkg], indent=2, default=str))
            self.notify(f"Exported → {path}", severity="information", timeout=5)
        except Exception as exc:
            self.notify(f"Export failed: {exc}", severity="error", timeout=5)

    # ── Input handlers ────────────────────────────────────────────────────────
    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "add-pkg-input":
            self._add_pkg(event.value.strip())
            event.input.clear()
            event.stop()

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "pkg-search":
            self._sync_list(event.value.strip())

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-add":
            inp = self.query_one("#add-pkg-input", Input)
            self._add_pkg(inp.value.strip())
            inp.clear()

    def _add_pkg(self, pkgname: str) -> None:
        # [DEV-3] Validate package name format
        if not pkgname:
            return
        if not is_valid_pkg_name(pkgname):
            self.notify(
                f"Invalid package name: '{pkgname}'\n"
                "AUR names: letters, digits, @._+- only",
                severity="warning",
                timeout=4,
            )
            return
        if pkgname in self._packages:
            self._select(self._packages.index(pkgname))
            return
        self._packages.append(pkgname)
        self._sel = len(self._packages) - 1
        self._sync_list()
        save_session(self._packages)             # [DEV-8]
        self._launch_scan(pkgname)
