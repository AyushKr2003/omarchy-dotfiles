from __future__ import annotations
from pathlib import Path

def load_omarchy_theme() -> dict:
    d = {
        "bg":"#1a1b26","dark_bg":"#13141c","darker_bg":"#0e0e14",
        "lighter_bg":"#24283b","selection":"#292e42","muted":"#414868",
        "dark_fg":"#565f89","fg":"#a9b1d6","bright_fg":"#c0caf5",
        "accent":"#7aa2f7","red":"#f7768e","yellow":"#e0af68",
        "orange":"#eb927b","green":"#9ece6a","cyan":"#449dab",
        "name":"Tokyo Night",
    }
    n = Path.home()/".local/state/omarchy/current/theme.name"
    if n.exists(): d["name"] = n.read_text().strip()
    p = Path.home()/".local/state/omarchy/current/theme/colors.toml"
    if p.exists():
        try:
            for line in p.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line: continue
                k,_,v = line.partition("=")
                d[k.strip().replace("-","_")] = v.strip().strip('"').strip("'")
            d["name"] = n.read_text().strip() if n.exists() else d["name"]
        except: pass
    return d

T   = load_omarchy_theme()
BG  = T["bg"];  DBG = T["dark_bg"];  DKR = T.get("darker_bg","#0e0e14")
LBG = T["lighter_bg"];  SEL = T["selection"];  MUT = T["muted"]
DFG = T["dark_fg"];  FG = T["fg"];  BFG = T["bright_fg"]
ACC = T["accent"];  RED = T["red"];  YEL = T["yellow"]
GRN = T["green"];  CYN = T["cyan"];  ORG = T.get("orange",YEL)
