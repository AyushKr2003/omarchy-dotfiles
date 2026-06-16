from __future__ import annotations
import json, time
from pathlib import Path
from datetime import datetime
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical, ScrollableContainer
from textual.css.query import NoMatches
from textual.widget import Widget
from textual.widgets import (
    Button, Footer, Input, ProgressBar, RichLog, Static,
)
from textual import events, work

from .theme import T, BG, DBG, DKR, LBG, SEL, MUT, DFG, FG, BFG, ACC, RED, YEL, GRN
from .css import CSS
from .scanner import CACHE_DIR, get_installed_aur, full_scan
from .widgets import PkgItem
from .views import WelcomeView, LoadingView, ScanView, V_COLOR

MIN_WIDTH  = 100
MIN_HEIGHT = 28

class AurGuardApp(App):
    CSS   = CSS
    TITLE = "aur-guard"
    BINDINGS = [
        Binding("j",           "cursor_down",    "down",     show=True),
        Binding("k",           "cursor_up",      "up",       show=True),
        Binding("slash",       "focus_search",   "/ search", show=True),
        Binding("a",           "focus_add",      "a add",    show=True),
        Binding("r",           "rescan",         "r rescan", show=True),
        Binding("S",           "scan_installed", "S all",    show=True),
        Binding("d",           "remove_pkg",     "d remove", show=False),
        Binding("e",           "export",         "e export", show=True),
        Binding("ctrl+h",       "show_help",      "? help",   show=True, priority=True),
        Binding("escape",      "escape_all",     "",         show=False, priority=True),
        Binding("q",           "quit",           "q quit",   show=True),
        Binding("ctrl+c",      "quit",           "",         show=False),
    ]

    def __init__(self, preload:list[str]|None=None):
        super().__init__()
        self._packages: list[str]      = list(preload or [])
        self._results:  dict[str,dict] = {}
        self._sel:      int            = -1
        self._scanning: set[str]       = set()
        self._too_small: bool          = False
        self._list_items: list[PkgItem] = []

    def compose(self) -> ComposeResult:
        with Horizontal(id="header-bar"):
            yield Static("\U000f04d3  aur-guard", id="app-title")
            yield Static("\u2502", id="header-divider")
            yield Static(f" {T['name']}", id="theme-badge")
            yield Static("\u2502  0 packages", id="header-counts")
            yield Static("AUR Security Scanner", id="header-status")
        with Horizontal(id="main-layout"):
            with Vertical(id="sidebar"):
                yield Static("  Packages", id="sidebar-title")
                yield Input(placeholder="\U000f0349 Search AUR...", id="pkg-search", select_on_focus=False)
                yield ScrollableContainer(id="pkg-list")
                with Horizontal(id="add-pkg-bar"):
                    yield Input(placeholder=" Package name...", id="add-pkg-input")
                    yield Button("Add", id="btn-add")
            with Container(id="content-area"):
                yield WelcomeView()
        yield Footer()
        with Container(id="too-small-overlay"):
            with Container(id="too-small-box"):
                yield Static("\U000f0955",                  classes="ts-icon")
                yield Static("Terminal too small", classes="ts-title")
                yield Static("",  id="ts-body",   classes="ts-body")
                yield Static("Resize your terminal to continue.", classes="ts-hint")
        with Container(id="batch-overlay"):
            with Container(id="batch-box"):
                yield Static("\U000f04d3 Scanning Installed Packages", classes="bt-title")
                yield Static("", id="batch-pkg",   classes="bt-pkg")
                yield ProgressBar(total=100, id="batch-bar")
                yield Static("", id="batch-count", classes="bt-count")
        with Container(id="help-overlay"):
            with Container(id="help-box"):
                yield Static("\U000f02db  Keybindings", classes="help-title")
                yield from self._help_rows()

    def on_mount(self) -> None:
        if self._packages:
            self._sync_list()
            self._select(0)
        self.set_timer(0.1, self._clear_focus)

    def _clear_focus(self) -> None:
        self.screen.set_focus(None)

    def on_resize(self, event:events.Resize) -> None:
        w,h = event.size.width, event.size.height
        ts  = w<MIN_WIDTH or h<MIN_HEIGHT
        if ts != self._too_small:
            self._too_small = ts
            try:
                self.query_one("#too-small-overlay").display = ts
                if ts:
                    self.query_one("#ts-body",Static).update(
                        f"Current:  {w} x {h}\nRequired: {MIN_WIDTH} x {MIN_HEIGHT} minimum"
                    )
            except NoMatches: pass

    def _sync_list(self, filter_q:str="") -> None:
        pkg_list = self.query_one("#pkg-list", ScrollableContainer)

        self._update_counts()

        while len(self._list_items) < len(self._packages):
            item = PkgItem(
                index   = len(self._list_items),
                pkgname = self._packages[len(self._list_items)],
                verdict_= "UNKNOWN",
            )
            self._list_items.append(item)
            pkg_list.mount(item)

        for i, item in enumerate(self._list_items):
            if i < len(self._packages):
                pkg      = self._packages[i]
                verd     = self._results[pkg]["verdict"] if pkg in self._results else "UNKNOWN"
                active   = (i == self._sel)
                visible  = not filter_q or filter_q.lower() in pkg.lower()
                item.pkg_index = i
                item.pkgname   = pkg
                item.display   = visible
                item.update_state(verd, active)
            else:
                item.display = False

    def _help_rows(self):
        keys = [
            ("j / k",      "Navigate package list"),
            ("/",          "Search packages"),
            ("a",          "Add package"),
            ("r",          "Rescan current package"),
            ("S",          "Scan all installed AUR packages"),
            ("d",          "Remove current package"),
            ("e",          "Export current result as JSON"),
            ("Ctrl+H",     "Show this help"),
            ("Esc",        "Dismiss help / unfocus"),
            ("q / Ctrl+C", "Quit"),
        ]
        for key, desc in keys:
            yield Static(f"  [bold]{key:<14}[/]  {desc}", classes="help-row", markup=True)
        yield Static("  Press Ctrl+H or Esc to close", classes="help-hint", markup=True)

    def _update_counts(self) -> None:
        done = sum(1 for p in self._packages if p in self._results and self._results[p].get("info"))
        try:
            s = f"\u2502  {len(self._packages)} packages  \u00b7  {done} scanned"
            self.query_one("#header-counts", Static).update(s)
        except NoMatches:
            pass

    def _select(self, idx:int) -> None:
        if not self._packages: return
        self._sel = max(0, min(idx, len(self._packages)-1))
        self._sync_list()
        pkg = self._packages[self._sel]
        if pkg in self._results:
            self._set_content(ScanView(self._results[pkg]))
        elif pkg not in self._scanning:
            self._launch_scan(pkg)

    def on_pkg_item_selected(self, msg:PkgItem.Selected) -> None:
        self._select(msg.index)

    def _set_content(self, w:Widget) -> None:
        area = self.query_one("#content-area", Container)
        area.remove_children()
        area.mount(w)

    def _show_welcome(self):   self._set_content(WelcomeView())
    def _show_result(self,r):  self._set_content(ScanView(r))
    def _show_loading(self, pkg="") -> LoadingView:
        lv = LoadingView(pkgname=pkg)
        self._set_content(lv)
        return lv

    @work(thread=True)
    def _launch_scan(self, pkgname:str) -> None:
        self._scanning.add(pkgname)
        lv: LoadingView|None = None

        def show_lv():
            nonlocal lv
            lv = self._show_loading(pkgname)
        self.call_from_thread(show_lv)
        time.sleep(0.05)

        result = full_scan(pkgname, prog=lambda m: lv and self.call_from_thread(lv.set_step, m))
        self._results[pkgname] = result
        self._scanning.discard(pkgname)

        def done():
            self._sync_list()
            if 0<=self._sel<len(self._packages) and self._packages[self._sel]==pkgname:
                self._show_result(result)
        self.call_from_thread(done)

    @work(thread=True)
    def _batch_scan(self, packages:list[str]) -> None:
        total = len(packages)
        def show_overlay():
            try:
                self.query_one("#batch-overlay").display = True
                self.query_one("#batch-bar",ProgressBar).total = total
            except NoMatches: pass
        self.call_from_thread(show_overlay)
        for i,pkg in enumerate(packages):
            self.call_from_thread(lambda i=i,pkg=pkg: (
                self.query_one("#batch-pkg",Static).update(f"Scanning: {pkg}"),
                self.query_one("#batch-bar",ProgressBar).__setattr__("progress",i),
                self.query_one("#batch-count",Static).update(f"{i} / {total}"),
            ) if True else None)
            self._results[pkg] = full_scan(pkg)
        def done():
            try: self.query_one("#batch-overlay").display = False
            except NoMatches: pass
            self._sync_list()
            if self._packages: self._select(max(self._sel,0))
        self.call_from_thread(done)

    # ── Actions ───────────────────────────────────────────────────────────────
    def action_cursor_down(self):    self._select(self._sel+1)
    def action_cursor_up(self):      self._select(self._sel-1)
    def action_focus_search(self):   self.query_one("#pkg-search",    Input).focus()
    def action_focus_add(self):      self.query_one("#add-pkg-input", Input).focus()
    def action_escape_focus(self):   self.screen.set_focus(None)

    def action_escape_all(self) -> None:
        try:
            self.query_one("#help-overlay").display = False
        except NoMatches:
            pass
        self.screen.set_focus(None)

    def action_show_help(self) -> None:
        try:
            overlay = self.query_one("#help-overlay")
            overlay.display = not overlay.display
        except NoMatches:
            pass

    def action_dismiss_help(self) -> None:
        try:
            self.query_one("#help-overlay").display = False
        except NoMatches:
            pass

    def action_export(self) -> None:
        if self._sel < 0 or not self._packages:
            return
        pkg = self._packages[self._sel]
        if pkg not in self._results:
            return
        export_dir = CACHE_DIR / "exports"
        export_dir.mkdir(parents=True, exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        path = export_dir / f"aur-guard-{pkg}-{ts}.json"
        try:
            path.write_text(json.dumps(self._results[pkg], indent=2, default=str))
            self.notify(f"Exported to {path}", severity="information", timeout=4)
        except Exception as exc:
            self.notify(f"Export failed: {exc}", severity="error", timeout=4)

    def action_rescan(self) -> None:
        if self._sel<0 or not self._packages: return
        pkg = self._packages[self._sel]
        (CACHE_DIR/f"{pkg}.json").unlink(missing_ok=True)
        self._results.pop(pkg,None)
        self._launch_scan(pkg)

    def action_remove_pkg(self) -> None:
        if self._sel<0 or not self._packages: return
        pkg = self._packages.pop(self._sel)
        self._results.pop(pkg,None)
        self._scanning.discard(pkg)
        if self._list_items:
            old = self._list_items.pop()
            old.remove()
        self._sel = min(self._sel, len(self._packages)-1)
        self._sync_list()
        if self._packages: self._select(self._sel)
        else:              self._show_welcome()

    def action_scan_installed(self) -> None:
        pkgs = get_installed_aur()
        if not pkgs:
            self._show_loading("(no AUR packages found -- pacman -Qm returned nothing)")
            return
        for p in pkgs:
            if p not in self._packages: self._packages.append(p)
        self._sync_list()
        self._batch_scan(pkgs)

    def on_input_submitted(self, event:Input.Submitted) -> None:
        if event.input.id=="add-pkg-input":
            self._add_pkg(event.value.strip())
            event.input.clear()
            event.stop()

    def on_input_changed(self, event:Input.Changed) -> None:
        if event.input.id=="pkg-search":
            self._sync_list(event.value.strip())

    def on_button_pressed(self, event:Button.Pressed) -> None:
        if event.button.id=="btn-add":
            inp = self.query_one("#add-pkg-input",Input)
            self._add_pkg(inp.value.strip()); inp.clear()

    def _add_pkg(self, pkgname:str) -> None:
        if not pkgname: return
        if pkgname in self._packages:
            self._select(self._packages.index(pkgname)); return
        self._packages.append(pkgname)
        self._sel = len(self._packages)-1
        self._sync_list()
        self._launch_scan(pkgname)
