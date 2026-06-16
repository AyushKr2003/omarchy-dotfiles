from __future__ import annotations
from textual.message import Message
from textual.widget import Widget
from rich.text import Text
from .theme import FG, BFG, SEL, LBG, RED, ORG, YEL, GRN, MUT

class PkgItem(Widget):
    """Sidebar row. No DOM id -- avoids DuplicateIds on rebuild."""

    DEFAULT_CSS = f"""
    PkgItem {{
        height: 1;
        padding: 0 1 0 2;
        color: {FG};
        background: transparent;
    }}
    PkgItem:hover  {{ background: {SEL}; }}
    PkgItem.active {{ background: {LBG}; color: {BFG}; text-style: bold; }}
    PkgItem.active.verdict-clear {{ border: none; }}
    PkgItem.verdict-critical {{ color: {RED}; }}
    PkgItem.verdict-high {{ color: {ORG}; }}
    PkgItem.verdict-medium {{ color: {YEL}; }}
    PkgItem.verdict-clean {{ color: {GRN}; }}
    """

    _VERDICT_CLASSES = {
        "CRITICAL":"verdict-critical",
        "HIGH":"verdict-high",
        "MEDIUM":"verdict-medium",
        "CLEAN":"verdict-clean",
        "UNKNOWN":"",
    }

    class Selected(Message):
        def __init__(self, index: int) -> None:
            super().__init__()
            self.index = index

    def __init__(self, index:int, pkgname:str, verdict_:str="UNKNOWN", active:bool=False):
        super().__init__()
        self.pkg_index = index
        self.pkgname   = pkgname
        self.verdict_  = verdict_
        if active:
            self.add_class("active")

    def update_state(self, verdict_:str, active:bool) -> None:
        changed = self.verdict_ != verdict_
        if changed and self.verdict_:
            old = self._VERDICT_CLASSES.get(self.verdict_,"")
            if old: self.remove_class(old)
        self.verdict_ = verdict_
        new = self._VERDICT_CLASSES.get(verdict_,"")
        if new: self.add_class(new)
        if active:
            self.add_class("active")
        else:
            self.remove_class("active")
        if changed:
            self.refresh()

    def render(self) -> Text:
        icons = {
            "CRITICAL": ("\U000f068c", RED), "HIGH": ("\uf071", ORG),
            "MEDIUM":   ("\uf071", YEL),    "CLEAN": ("\U000f0e1e", GRN),
            "UNKNOWN":  ("\uf110", MUT),
        }
        icon, color = icons.get(self.verdict_, ("\uf110", MUT))
        t = Text()
        t.append(f" {icon}  ", style=color)
        if self.verdict_ == "UNKNOWN":
            t.append(self.pkgname, style=FG)
        else:
            t.append(self.pkgname, style=BFG)
        return t

    def on_click(self) -> None:
        self.post_message(self.Selected(self.pkg_index))
