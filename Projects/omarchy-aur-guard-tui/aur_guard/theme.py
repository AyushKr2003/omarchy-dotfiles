"""theme.py — Load active Omarchy theme from state dir. Single source of truth."""
from __future__ import annotations
from pathlib import Path


def load_omarchy_theme() -> dict:
    defaults: dict = {
        "bg":         "#1a1b26",
        "dark_bg":    "#13141c",
        "darker_bg":  "#0e0e14",
        "lighter_bg": "#24283b",
        "selection":  "#292e42",
        "muted":      "#414868",
        "dark_fg":    "#565f89",
        "fg":         "#a9b1d6",
        "bright_fg":  "#c0caf5",
        "accent":     "#7aa2f7",
        "red":        "#f7768e",
        "yellow":     "#e0af68",
        "orange":     "#eb927b",
        "green":      "#9ece6a",
        "cyan":       "#449dab",
        "magenta":    "#ad8ee6",
        "name":       "Tokyo Night",
    }
    name_path  = Path.home() / ".local/state/omarchy/current/theme.name"
    toml_path  = Path.home() / ".local/state/omarchy/current/theme/colors.toml"

    if name_path.exists():
        defaults["name"] = name_path.read_text().strip()

    if toml_path.exists():
        try:
            for raw in toml_path.read_text().splitlines():
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                defaults[k.strip().replace("-", "_")] = (
                    v.strip().strip('"').strip("'")
                )
            # Re-read name after TOML parse (TOML may not have it)
            if name_path.exists():
                defaults["name"] = name_path.read_text().strip()
        except Exception:
            pass

    return defaults


T   = load_omarchy_theme()

BG  = T["bg"]
DBG = T["dark_bg"]
DKR = T.get("darker_bg", "#0e0e14")
LBG = T["lighter_bg"]
SEL = T["selection"]
MUT = T["muted"]
DFG = T["dark_fg"]
FG  = T["fg"]
BFG = T["bright_fg"]
ACC = T["accent"]
RED = T["red"]
YEL = T["yellow"]
ORG = T.get("orange", "#eb927b")
GRN = T["green"]
CYN = T["cyan"]
MAG = T.get("magenta", "#ad8ee6")
