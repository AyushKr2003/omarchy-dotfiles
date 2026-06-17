"""css.py — All Textual CSS for aur-guard. Theme-aware via theme.py."""
from .theme import BG, DBG, DKR, LBG, SEL, MUT, DFG, FG, BFG, ACC, RED, YEL, GRN, CYN, ORG

CSS = f"""
Screen {{
    background: {DKR};
    color: {FG};
    layers: base overlay;
}}

/* ── Header ─────────────────────────────────────────────────── */
#header-bar {{
    layer: base;
    height: 3;
    background: {DBG};
    border-bottom: tall {LBG};
    padding: 0 2;
    layout: horizontal;
    align: left middle;
}}
#app-title      {{ color: {ACC}; text-style: bold; width: auto; margin-right: 2; }}
#header-divider {{ color: {MUT}; width: 1; margin-right: 2; }}
#theme-badge    {{ color: {MUT}; width: auto; margin-right: 2; }}
#header-counts  {{ color: {DFG}; width: auto; margin-right: 2; }}
#header-status  {{ color: {DFG}; width: 1fr; text-align: right; }}

/* ── Main layout ─────────────────────────────────────────────── */
#main-layout {{ layout: horizontal; height: 1fr; layer: base; }}

/* ── Sidebar ─────────────────────────────────────────────────── */
#sidebar {{
    width: 30;
    min-width: 24;
    background: {DBG};
    border-right: tall {LBG};
    layout: vertical;
}}
#sidebar-title {{
    background: {LBG};
    color: {BFG};
    text-style: bold;
    padding: 0 2;
    height: 2;
    content-align: left middle;
}}
#pkg-search {{
    margin: 1 1 0 1;
    border: tall {SEL};
    background: {BG};
    color: {FG};
    height: 3;
    padding: 0 1;
}}
#pkg-search:focus {{ border: tall {ACC}; }}
#pkg-list {{
    height: 1fr;
    overflow-y: auto;
    scrollbar-color: {MUT};
    scrollbar-background: {DBG};
    scrollbar-size-vertical: 1;
    margin: 0;
    padding: 0;
}}
#add-pkg-bar {{
    height: 5;
    background: {DBG};
    border-top: tall {LBG};
    padding: 1 1;
    layout: horizontal;
    align: center middle;
}}
#add-pkg-input {{
    width: 1fr;
    border: tall {SEL};
    background: {BG};
    color: {FG};
    height: 3;
    padding: 0 1;
}}
#add-pkg-input:focus {{ border: tall {ACC}; }}
#btn-add {{
    width: 7;
    margin-left: 1;
    background: {ACC};
    color: {DKR};
    border: none;
    height: 3;
    text-style: bold;
    content-align: center middle;
}}
#btn-add:hover  {{ background: {BFG}; color: {DKR}; }}
#btn-add:focus  {{ background: {BFG}; border: none; }}

/* ── Content area ────────────────────────────────────────────── */
#content-area {{ width: 1fr; background: {BG}; height: 1fr; }}

/* ── Welcome ─────────────────────────────────────────────────── */
#welcome-wrap {{
    align: center middle;
    height: 1fr;
    background: {BG};
    padding: 4;
}}
#welcome-box {{
    width: 64;
    height: auto;
    background: {DBG};
    border: round {LBG};
    padding: 3 5;
    align: center middle;
}}
.wl-icon  {{ color: {ACC};  text-align: center; text-style: bold; margin-bottom: 1; }}
.wl-title {{ color: {BFG}; text-align: center; text-style: bold; margin-bottom: 1; }}
.wl-body  {{ color: {DFG}; text-align: center; margin-bottom: 1; }}
.wl-hint  {{ color: {MUT}; text-align: center; }}

/* ── Loading ─────────────────────────────────────────────────── */
#loading-wrap {{ align: center middle; height: 1fr; background: {BG}; }}
.loading-box {{
    width: 50;
    height: 9;
    background: {DBG};
    border: round {ACC};
    padding: 2 4;
    align: center middle;
}}
.loading-pkg  {{ color: {ACC}; text-align: center; text-style: bold; margin-bottom: 1; }}
.loading-step {{ color: {FG};  text-align: center; margin-bottom: 1; }}
LoadingIndicator {{ color: {ACC}; width: 100%; height: 1; }}

/* ── Scan result ─────────────────────────────────────────────── */
#scan-wrap {{
    height: 1fr;
    layout: vertical;
    padding: 1 2 1 2;
    background: {BG};
}}

/* ── Verdict banner ──────────────────────────────────────────── */
#verdict-banner {{
    height: 7;
    background: {DBG};
    border: round {LBG};
    layout: horizontal;
    align: left middle;
    margin-bottom: 1;
}}
#v-accent {{
    width: 3;
    height: 100%;
}}
#v-accent.v-acc-critical {{ background: {RED}; }}
#v-accent.v-acc-high     {{ background: {ORG}; }}
#v-accent.v-acc-medium   {{ background: {YEL}; }}
#v-accent.v-acc-clean    {{ background: {GRN}; }}
#v-accent.v-acc-unknown  {{ background: {MUT}; }}
#v-body {{
    width: 1fr;
    height: 100%;
    padding: 1 2;
    layout: vertical;
}}
#v-top {{
    height: 3;
    layout: horizontal;
    align: left middle;
}}
#v-icon  {{ width: 14; text-style: bold; content-align: left middle; }}
#v-label {{ width: 1fr; content-align: left middle; }}
#v-score {{
    height: 2;
    layout: vertical;
    padding: 0 1;
}}
#v-score-bar   {{ color: {FG}; height: 1; }}
#v-score-label {{ color: {DFG}; height: 1; text-align: right; }}

/* ── Tabs ────────────────────────────────────────────────────── */
#scan-tabs {{ height: 1fr; }}
TabbedContent > Tabs {{
    background: {DBG};
    border-bottom: tall {LBG};
    padding: 0 1;
    height: 3;
}}
Tab {{
    color: {DFG};
    background: {DBG};
    padding: 0 2;
    min-width: 14;
    content-align: center middle;
}}
Tab:hover   {{ color: {FG};  background: {SEL}; }}
Tab.-active {{ color: {ACC}; background: {BG}; text-style: bold; border-bottom: tall {ACC}; }}
TabPane {{ padding: 1 2; background: {BG}; height: 1fr; }}

/* ── Log / viewer panes ──────────────────────────────────────── */
.ov-log, .fi-log, .pb-log, .df-log {{
    height: 1fr;
    background: {DKR};
    border: round {LBG};
    padding: 1 1;
    scrollbar-color: {MUT};
    scrollbar-background: {DBG};
    scrollbar-size-vertical: 1;
}}
.fi-log {{ background: {BG}; }}
.fi-empty {{
    align: center middle;
    height: 1fr;
    background: {BG};
    border: round {LBG};
    padding: 3;
    content-align: center middle;
}}

/* ── Footer ──────────────────────────────────────────────────── */
Footer {{
    background: {DBG};
    color: {MUT};
    border-top: tall {LBG};
    height: 1;
}}
Footer > .footer--key         {{ background: {LBG}; color: {ACC}; text-style: bold; }}
Footer > .footer--description {{ color: {DFG}; }}

/* ── Overlays (shared base) ──────────────────────────────────── */
.overlay-bg {{
    layer: overlay;
    align: center middle;
    background: {DKR}cc;
    width: 100%;
    height: 100%;
    display: none;
}}

/* Too-small */
#too-small-overlay {{ layer: overlay; align: center middle; background: {DKR}ee;
                      width: 100%; height: 100%; display: none; }}
#too-small-box     {{ width: 52; height: auto; background: {DBG};
                      border: round {RED}; padding: 3 5; align: center middle; }}
.ts-icon  {{ color: {RED};  text-align: center; text-style: bold; margin-bottom: 1; }}
.ts-title {{ color: {BFG}; text-align: center; text-style: bold; margin-bottom: 1; }}
.ts-body  {{ color: {FG};  text-align: center; margin-bottom: 1; }}
.ts-hint  {{ color: {MUT}; text-align: center; }}

/* Batch scan */
#batch-overlay {{ layer: overlay; align: center middle; background: {DKR}cc;
                  width: 100%; height: 100%; display: none; }}
#batch-box     {{ width: 56; height: 13; background: {DBG};
                  border: round {ACC}; padding: 2 4; align: center middle; }}
.bt-title {{ color: {ACC}; text-style: bold; text-align: center; margin-bottom: 1; }}
.bt-pkg   {{ color: {FG};  text-align: center; height: 1; margin-bottom: 1; }}
.bt-count {{ color: {DFG}; text-align: center; height: 1; }}
ProgressBar {{ width: 100%; margin-top: 1; }}
ProgressBar Bar {{ color: {ACC}; background: {LBG}; }}

/* Help */
#help-overlay {{ layer: overlay; align: center middle; background: {DKR}cc;
                 width: 100%; height: 100%; display: none; }}
#help-box     {{ width: 58; height: auto; background: {DBG};
                 border: round {ACC}; padding: 2 4; align: center middle; }}
.help-title {{ color: {ACC}; text-style: bold; text-align: center; margin-bottom: 1; }}
.help-row   {{ color: {FG};  text-align: left; height: 1; }}
.help-hint  {{ color: {MUT}; text-align: center; margin-top: 1; }}

/* Notification (export success) */
Toast {{ background: {DBG}; color: {FG}; border: round {ACC}; }}
"""
