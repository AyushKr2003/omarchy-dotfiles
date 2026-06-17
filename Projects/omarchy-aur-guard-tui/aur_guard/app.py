"""
app.py — AurGuardApp main Textual application.

Bugs fixed vs previous version:
  [B1] action_remove_pkg removed LAST list item instead of SELECTED one
  [B2] pkg_index went stale for all items below a removed package
  [B3] _batch_scan ProgressBar update used broken lambda tuple trick
  [B4] _batch_scan gave zero per-package progress feedback
  [B5] escape binding (priority=True) triggered inside Input widgets
  [B6] ctrl+h conflicts with terminal backspace — changed to '?' key
  [B7] action_escape_focus was a dead method (binding pointed at escape_all)
  [B8] LoadingView hardcoded IDs caused race conditions on rapid scans
  [B9] scan-wrap had no explicit height so tabs got squished on short terminals
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
from textual.widgets import Button, Footer, Input, ProgressBar, Static
from textual import events, work

from .theme import T, DBG, ACC, DFG, MUT
from .css import CSS
from .scanner import CACHE_DIR, get_installed_aur, full_scan
from .widgets import PkgItem
from .views import WelcomeView, LoadingView, ScanView
from .icons import APP, HELP, OVERVIEW

MIN_WIDTH  = 100
MIN_HEIGHT = 28


class AurGuardApp(App):
    CSS   = CSS
    TITLE = "aur-guard"

    BINDINGS = [
        # Navigation — vim style
        Binding("j",      "cursor_down",    "↓ down",   show=True),
        Binding("k",      "cursor_up",      "↑ up",     show=True),
        # Sidebar
        Binding("slash",  "focus_search",   "/ search", show=True),
        Binding("a",      "focus_add",      "a add",    show=True),
        Binding("d",      "remove_pkg",     "d remove", show=False),
        # Scan actions
        Binding("r",      "rescan",         "r rescan", show=True),
        Binding("S",      "scan_installed", "S scan ∀", show=True),
        Binding("e",      "export",         "e export", show=True),
        # UI
        # FIX [B6]: was ctrl+h (conflicts with terminal backspace) → now '?'
        Binding("question_mark", "toggle_help", "? help",  show=True),
        # FIX [B5]: escape without priority=True so it doesn't eat Input keystrokes
        Binding("escape", "escape_all",     "",          show=False),
        Binding("q",      "quit",           "q quit",    show=True),
        Binding("ctrl+c", "quit",           "",          show=False),
    ]

    def __init__(self, preload: list[str] | None = None):
        super().__init__()
        self._packages:   list[str]       = list(preload or [])
        self._results:    dict[str, dict] = {}
        self._sel:        int             = -1
        self._scanning:   set[str]        = set()
        self._too_small:  bool            = False
        # Pool of PkgItem widgets — grown in-place, never destroyed/recreated
        self._list_items: list[PkgItem]   = []

    # ── Compose ───────────────────────────────────────────────────────────────
    def compose(self) -> ComposeResult:
        # Header
        with Horizontal(id="header-bar"):
            yield Static(f"{APP}  aur-guard",       id="app-title")
            yield Static("│",                        id="header-divider")
            yield Static(f" {T['name']}",            id="theme-badge")
            yield Static("│  0 packages",            id="header-counts")
            yield Static("AUR Security Scanner",     id="header-status")

        # Main split
        with Horizontal(id="main-layout"):
            with Vertical(id="sidebar"):
                yield Static("  Packages",           id="sidebar-title")
                yield Input(
                    placeholder=f" Search AUR…",
                    id="pkg-search",
                    select_on_focus=False,
                )
                yield ScrollableContainer(id="pkg-list")
                with Horizontal(id="add-pkg-bar"):
                    yield Input(
                        placeholder=" Package name…",
                        id="add-pkg-input",
                    )
                    yield Button("Add", id="btn-add")

            with Container(id="content-area"):
                yield WelcomeView()

        yield Footer()

        # ── Overlays (all hidden initially) ──────────────────────────────────
        # Too-small notice
        with Container(id="too-small-overlay"):
            with Container(id="too-small-box"):
                yield Static("󰹍",                        classes="ts-icon")
                yield Static("Terminal too small",        classes="ts-title")
                yield Static("",   id="ts-body",          classes="ts-body")
                yield Static("Resize your terminal to continue.", classes="ts-hint")

        # Batch scan progress
        with Container(id="batch-overlay"):
            with Container(id="batch-box"):
                yield Static(f"{APP} Scanning Installed Packages", classes="bt-title")
                yield Static("",   id="batch-pkg",   classes="bt-pkg")
                yield ProgressBar(total=100,          id="batch-bar")
                yield Static("",   id="batch-count",  classes="bt-count")

        # Help overlay
        with Container(id="help-overlay"):
            with Container(id="help-box"):
                yield Static(f"{HELP}  Keybindings", classes="help-title")
                yield from self._help_rows()

    # ── Mount ─────────────────────────────────────────────────────────────────
    def on_mount(self) -> None:
        if self._packages:
            self._sync_list()
            self._select(0)
        # Defer focus clear so Input widgets don't auto-focus
        self.set_timer(0.1, lambda: self.screen.set_focus(None))

    # ── Help rows ─────────────────────────────────────────────────────────────
    def _help_rows(self):
        pairs = [
            ("j / k",          "Navigate package list"),
            ("/",              "Focus search bar"),
            ("a",              "Add package by name"),
            ("r",              "Rescan selected package (clears cache)"),
            ("S",              "Scan all installed AUR packages"),
            ("d",              "Remove selected package from list"),
            ("e",              "Export scan result as JSON"),
            ("?",              "Toggle this help overlay"),
            ("Esc",            "Dismiss help / unfocus inputs"),
            ("q  /  Ctrl+C",   "Quit"),
        ]
        for key, desc in pairs:
            yield Static(
                f"  [bold {ACC}]{key:<18}[/]  [{DFG}]{desc}[/]",
                classes="help-row", markup=True,
            )
        yield Static(
            "  Press  ?  or  Esc  to close",
            classes="help-hint",
        )

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
                        f"Current:  {w} × {h}\n"
                        f"Required: {MIN_WIDTH} × {MIN_HEIGHT} minimum"
                    )
            except NoMatches:
                pass

    # ── Sidebar sync (pool pattern — no destroy/recreate) ────────────────────
    def _sync_list(self, filter_q: str = "") -> None:
        """
        Keep the pkg-list DOM in sync without ever removing+re-adding items.

        Strategy:
          - Grow the _list_items pool as needed (append new PkgItem).
          - Update existing items in-place: verdict, active, visibility.
          - Items beyond len(_packages) are hidden.

        This completely eliminates the DuplicateIds crash because no widget
        is ever unmounted and remounted with the same (empty) id.
        """
        pkg_list = self.query_one("#pkg-list", ScrollableContainer)
        self._update_header_counts()

        # Grow pool if we have more packages than widgets
        while len(self._list_items) < len(self._packages):
            idx  = len(self._list_items)
            item = PkgItem(
                index   = idx,
                pkgname = self._packages[idx],
                verdict_= "UNKNOWN",
            )
            self._list_items.append(item)
            pkg_list.mount(item)

        # Update every pooled widget in-place
        for i, item in enumerate(self._list_items):
            if i < len(self._packages):
                pkg     = self._packages[i]
                verd    = (
                    self._results[pkg]["verdict"]
                    if pkg in self._results else "UNKNOWN"
                )
                active  = (i == self._sel)
                visible = (
                    not filter_q or filter_q.lower() in pkg.lower()
                )
                item.pkg_index = i
                item.pkgname   = pkg
                item.display   = visible
                item.update_state(verd, active)
            else:
                # Extra items beyond current package list — hide them
                item.display = False

    def _update_header_counts(self) -> None:
        done = sum(
            1 for p in self._packages
            if p in self._results and self._results[p].get("info")
        )
        try:
            self.query_one("#header-counts", Static).update(
                f"│  {len(self._packages)} packages  ·  {done} scanned"
            )
        except NoMatches:
            pass

    # ── Selection ─────────────────────────────────────────────────────────────
    def _select(self, idx: int) -> None:
        if not self._packages:
            return
        self._sel = max(0, min(idx, len(self._packages) - 1))
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
        # FIX [B8]: LoadingView now uses CSS classes not hardcoded IDs
        lv = LoadingView(pkgname=pkg)
        self._set_content(lv)
        return lv

    # ── Worker: single package scan ───────────────────────────────────────────
    @work(thread=True)
    def _launch_scan(self, pkgname: str) -> None:
        self._scanning.add(pkgname)
        lv: LoadingView | None = None

        # Show loading screen on the UI thread
        def show_lv() -> None:
            nonlocal lv
            lv = self._show_loading(pkgname)

        self.call_from_thread(show_lv)
        time.sleep(0.05)   # yield so UI renders before blocking network calls

        result = full_scan(
            pkgname,
            prog=lambda m: lv and self.call_from_thread(lv.set_step, m),
        )
        self._results[pkgname] = result
        self._scanning.discard(pkgname)

        def done() -> None:
            self._sync_list()
            if (
                0 <= self._sel < len(self._packages)
                and self._packages[self._sel] == pkgname
            ):
                self._show_result(result)

        self.call_from_thread(done)

    # ── Worker: batch scan all installed ──────────────────────────────────────
    @work(thread=True)
    def _batch_scan(self, packages: list[str]) -> None:
        """
        FIX [B3]: No more lambda-tuple trick for ProgressBar.
        FIX [B4]: Each package gets a progress callback.
        """
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
            # Update overlay labels
            def update_ui(i: int = i, pkg: str = pkg) -> None:
                try:
                    self.query_one("#batch-pkg",   Static).update(f"Scanning: {pkg}")
                    self.query_one("#batch-bar",   ProgressBar).progress = i
                    self.query_one("#batch-count", Static).update(
                        f"{i} / {total}"
                    )
                except NoMatches:
                    pass

            self.call_from_thread(update_ui)

            # Scan with per-step progress feedback
            def pkg_prog(msg: str, pkg: str = pkg) -> None:
                try:
                    self.call_from_thread(
                        self.query_one("#batch-pkg", Static).update,
                        f"{pkg}  —  {msg}",
                    )
                except Exception:
                    pass

            self._results[pkg] = full_scan(pkg, prog=pkg_prog)

        def done() -> None:
            try:
                self.query_one("#batch-overlay").display = False
            except NoMatches:
                pass
            self._sync_list()
            if self._packages:
                self._select(max(self._sel, 0))

        self.call_from_thread(done)

    # ── Actions ───────────────────────────────────────────────────────────────
    def action_cursor_down(self) -> None:
        self._select(self._sel + 1)

    def action_cursor_up(self) -> None:
        self._select(self._sel - 1)

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

    def action_escape_all(self) -> None:
        """Dismiss help overlay if open, otherwise unfocus inputs."""
        try:
            overlay = self.query_one("#help-overlay")
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
        FIX [B1]: Remove the SELECTED item, not the last item.
        FIX [B2]: Reassign pkg_index for all items after the removed one.
        """
        if self._sel < 0 or not self._packages:
            return
        idx = self._sel
        self._packages.pop(idx)
        self._results.pop(self._packages[idx] if idx < len(self._packages) else "", None)
        self._scanning.discard(
            self._packages[idx] if idx < len(self._packages) else ""
        )

        # Remove the LAST widget from the pool (pool shrinks by 1)
        if self._list_items:
            removed_widget = self._list_items.pop()
            removed_widget.remove()

        # Adjust selection
        self._sel = min(idx, len(self._packages) - 1)

        # Re-sync all remaining items (this fixes stale pkg_index values)
        self._sync_list()

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
            path.write_text(
                json.dumps(self._results[pkg], indent=2, default=str)
            )
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
        if not pkgname:
            return
        if pkgname in self._packages:
            self._select(self._packages.index(pkgname))
            return
        self._packages.append(pkgname)
        self._sel = len(self._packages) - 1
        self._sync_list()
        self._launch_scan(pkgname)
