"""widgets.py — PkgItem sidebar widget. No DOM id= to avoid DuplicateIds."""
from __future__ import annotations
from textual.message import Message
from textual.widget import Widget
from rich.text import Text
from .theme import FG, BFG, SEL, LBG, RED, ORG, YEL, GRN, MUT
from .icons import CRITICAL, HIGH, MEDIUM, LOW, CLEAN, UNKNOWN


class PkgItem(Widget):
    """
    One row in the sidebar package list.

    CRITICAL FIX: No id= parameter — avoids DuplicateIds crash when
    _sync_list grows the pool. Identified by position in _list_items.
    """

    DEFAULT_CSS = f"""
    PkgItem {{
        height: 1;
        padding: 0 1 0 2;
        color: {FG};
        background: transparent;
    }}
    PkgItem:hover  {{ background: {SEL}; }}
    PkgItem.active {{ background: {LBG}; color: {BFG}; text-style: bold; }}
    """

    _VERDICT_ICONS: dict[str, tuple[str, str]] = {
        "CRITICAL": (CRITICAL, RED),
        "HIGH":     (HIGH,     ORG),
        "MEDIUM":   (MEDIUM,   YEL),
        "CLEAN":    (CLEAN,    GRN),
        "UNKNOWN":  (UNKNOWN,  MUT),
    }

    class Selected(Message):
        """Posted when this item is clicked."""
        def __init__(self, index: int) -> None:
            super().__init__()
            self.index = index

    def __init__(self, index: int, pkgname: str, verdict_: str = "UNKNOWN"):
        super().__init__()          # ← NO id= kwarg — this is the key fix
        self.pkg_index = index
        self.pkgname   = pkgname
        self.verdict_  = verdict_

    def update_state(self, verdict_: str, active: bool) -> None:
        """Update verdict and active state in-place without remounting."""
        changed       = self.verdict_ != verdict_
        self.verdict_ = verdict_
        if active:
            self.add_class("active")
        else:
            self.remove_class("active")
        if changed:
            self.refresh()

    def render(self) -> Text:
        icon, color = self._VERDICT_ICONS.get(self.verdict_, (UNKNOWN, MUT))
        t = Text()
        t.append(f" {icon}  ", style=color)
        t.append(
            self.pkgname,
            style=BFG if self.verdict_ != "UNKNOWN" else FG,
        )
        return t

    def on_click(self) -> None:
        self.post_message(self.Selected(self.pkg_index))
