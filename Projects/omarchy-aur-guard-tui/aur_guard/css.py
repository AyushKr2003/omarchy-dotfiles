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
    padding-top: 1;
    layout: horizontal;
    align: left middle;
}}
#app-title      {{ color: {ACC}; text-style: bold; width: auto; margin-right: 2; }}
#header-divider {{ color: {MUT}; width: auto; margin-right: 2; }}
#theme-badge    {{ color: {FG};  width: auto; margin-right: 2; }}
#header-counts  {{ color: {DFG}; width: auto; margin-right: 2; }}
#header-status  {{ color: {MUT}; width: 1fr; text-align: right; padding-right: 1; }}

/* ── Main layout ─────────────────────────────────────────────── */
#main-layout {{
    layout: horizontal;
    height: 1fr;
    layer: base;
    background: {BG};
}}

/* ── Sidebar ─────────────────────────────────────────────────── */
#sidebar {{
    width: 32;
    min-width: 28;
    background: {DBG};
    border-right: tall {LBG};
    layout: vertical;
}}
#sidebar.nav-focused {{
    border-right: tall {ACC};
}}
#sidebar-title {{
    background: {LBG};
    color: {BFG};
    text-style: bold;
    padding: 1 2;
    height: 3;
    border-bottom: tall {LBG};
    content-align: left middle;
}}
#sidebar.nav-focused #sidebar-title {{
    color: {BFG};
    background: {SEL};
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
    margin: 1 0 0 0;
    padding: 0;
}}

/* ── Add package bar ─────────────────────────────────────────── */
#add-pkg-bar {{
    height: 7;
    background: {DBG};
    border-top: tall {LBG};
    padding: 0 1;
    layout: horizontal;
    align: left middle;
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
#btn-add:hover {{ background: {BFG}; color: {DKR}; }}
#btn-add:focus {{ background: {BFG}; border: none; }}

/* ── Content area ────────────────────────────────────────────── */
#content-area {{
    width: 1fr;
    height: 1fr;
    background: {BG};
}}
#content-area.nav-focused {{
    background: {BG};
}}

/* ── Welcome ─────────────────────────────────────────────────── */
#welcome-wrap {{
    align: center middle;
    height: 1fr;
    background: {BG};
    padding: 3 4;
}}
#welcome-box {{
    width: 66;
    height: auto;
    background: {DBG};
    border-left: tall {ACC};
    padding: 2 5;
    align: center middle;
}}
.wl-icon  {{ color: {ACC};  text-align: center; text-style: bold; margin-bottom: 1; }}
.wl-title {{ color: {BFG}; text-align: center; text-style: bold; margin-bottom: 1; }}
.wl-body  {{ color: {DFG}; text-align: center; margin-bottom: 1; }}
.wl-hint  {{ color: {MUT}; text-align: center; }}

/* ── Loading ─────────────────────────────────────────────────── */
#loading-wrap {{ align: center middle; height: 1fr; background: {BG}; }}
.loading-box {{
    width: 52;
    height: 8;
    background: {DBG};
    border-left: tall {ACC};
    padding: 2 4;
    align: center middle;
}}
.loading-pkg  {{ color: {ACC}; text-align: center; text-style: bold; margin-bottom: 1; }}
.loading-step {{ color: {FG};  text-align: center; margin-bottom: 1; }}
LoadingIndicator {{ color: {ACC}; width: 100%; height: 1; }}

/* ── Scan result wrapper ─────────────────────────────────────── */
#scan-wrap {{
    height: 1fr;
    layout: vertical;
    padding: 1 2 0 2;
    background: {BG};
}}

/* ── Verdict banner ──────────────────────────────────────────── */
#verdict-banner {{
    height: 5;
    background: {DBG};
    border-bottom: tall {LBG};
    layout: horizontal;
    margin-bottom: 1;
    padding: 0;
}}
#v-accent {{
    width: 2;
    height: 100%;
}}
#v-accent.v-acc-critical {{ background: {RED}; }}
#v-accent.v-acc-error    {{ background: {RED}; }}
#v-accent.v-acc-high     {{ background: {ORG}; }}
#v-accent.v-acc-medium   {{ background: {YEL}; }}
#v-accent.v-acc-clean    {{ background: {GRN}; }}
#v-accent.v-acc-unknown  {{ background: {MUT}; }}

#v-body {{
    width: 1fr;
    height: 100%;
    padding: 0 2;
    layout: horizontal;
    align: left middle;
}}
#v-left {{
    width: 1fr;
    height: 100%;
    layout: vertical;
    align: left middle;
}}
#v-verdict-line {{
    height: 1;
    color: {BFG};
    text-style: bold;
    content-align: left middle;
}}
#v-name-line {{
    height: 1;
    color: {FG};
    content-align: left middle;
}}
#v-maint-line {{
    height: 1;
    color: {DFG};
    content-align: left middle;
}}
#v-right {{
    width: 28;
    height: 100%;
    layout: vertical;
    align: right middle;
    padding: 0 1;
}}
#v-score-line {{
    height: 1;
    content-align: right middle;
}}
#v-score-label {{
    height: 1;
    color: {DFG};
    text-align: right;
    content-align: right middle;
}}

/* ── Tabs ────────────────────────────────────────────────────── */
#scan-tabs {{ height: 1fr; }}
TabbedContent > Tabs {{
    background: {BG};
    border-bottom: tall {LBG};
    padding: 0;
    height: 3;
}}
#content-area.nav-focused TabbedContent > Tabs {{
    border-bottom: tall {ACC};
}}
Tab {{
    color: {DFG};
    background: {BG};
    padding: 0 3;
    min-width: 14;
    content-align: center middle;
}}
Tab:hover {{
    color: {FG};
    background: {SEL};
}}
Tab.-active {{
    color: {BFG};
    background: {SEL};
    text-style: bold;
}}
#content-area.nav-focused Tab.-active {{
    color: {ACC};
}}
TabPane {{
    padding: 0;
    background: {BG};
    height: 1fr;
}}

/* ── Log / viewer panes ──────────────────────────────────────── */
.ov-log, .fi-log, .pb-log, .df-log {{
    height: 1fr;
    background: {BG};
    border-left: tall {LBG};
    padding: 0 1;
    scrollbar-color: {MUT};
    scrollbar-background: {DBG};
    scrollbar-size-vertical: 1;
}}
#content-area.nav-focused .ov-log,
#content-area.nav-focused .fi-log,
#content-area.nav-focused .pb-log,
#content-area.nav-focused .df-log {{
    border-left: tall {ACC};
}}

.fi-empty {{
    align: center middle;
    height: 1fr;
    background: {BG};
    border-left: tall {LBG};
    padding: 3;
    content-align: center middle;
}}
#content-area.nav-focused .fi-empty {{
    border-left: tall {ACC};
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

/* ── Too-small overlay ───────────────────────────────────────── */
#too-small-overlay {{
    layer: overlay;
    align: center middle;
    background: {DKR}ee;
    width: 100%;
    height: 100%;
    display: none;
}}
#too-small-box {{
    width: 52;
    height: auto;
    background: {DBG};
    border: round {RED};
    padding: 3 5;
    align: center middle;
}}
.ts-icon  {{ color: {RED};  text-align: center; text-style: bold; margin-bottom: 1; }}
.ts-title {{ color: {BFG}; text-align: center; text-style: bold; margin-bottom: 1; }}
.ts-body  {{ color: {FG};  text-align: center; margin-bottom: 1; }}
.ts-hint  {{ color: {MUT}; text-align: center; }}

/* ── Batch scan overlay ──────────────────────────────────────── */
#batch-overlay {{
    layer: overlay;
    align: center middle;
    background: {DKR}cc;
    width: 100%;
    height: 100%;
    display: none;
}}
#batch-box {{
    width: 56;
    height: 12;
    background: {DBG};
    border: round {ACC};
    padding: 2 4;
    align: center middle;
}}
.bt-title {{ color: {ACC}; text-style: bold; text-align: center; margin-bottom: 1; }}
.bt-pkg   {{ color: {FG};  text-align: center; height: 1; margin-bottom: 1; }}
.bt-count {{ color: {DFG}; text-align: center; height: 1; }}
ProgressBar {{ width: 100%; margin-top: 1; }}
ProgressBar Bar {{ color: {ACC}; background: {LBG}; }}

/* ── Help overlay ────────────────────────────────────────────── */
#help-overlay {{
    layer: overlay;
    align: center middle;
    background: {DKR}cc;
    width: 100%;
    height: 100%;
    display: none;
}}
#help-box {{
    width: 58;
    height: auto;
    background: {DBG};
    border: round {ACC};
    padding: 2 4;
    align: center middle;
}}
.help-title {{ color: {ACC}; text-style: bold; text-align: center; margin-bottom: 1; }}
.help-row   {{ color: {FG};  text-align: left; height: 1; }}
.help-hint  {{ color: {MUT}; text-align: center; margin-top: 1; }}

/* ── IoC Compromise Check overlay ───────────────────────────── */
#ioc-overlay {{
    layer: overlay;
    align: center middle;
    background: {DKR}cc;
    width: 100%;
    height: 100%;
    display: none;
}}
#ioc-box {{
    width: 72;
    height: 26;
    background: {DBG};
    border: round {RED};
    padding: 1 3;
    layout: vertical;
}}
.ioc-title  {{ color: {RED};  text-style: bold; text-align: center; margin-bottom: 1; height: 1; }}
#ioc-status {{ color: {YEL};  text-align: center; margin-bottom: 1; height: 1; }}
#ioc-log    {{
    height: 1fr;
    background: {BG};
    border-left: tall {LBG};
    padding: 0 1;
    scrollbar-color: {MUT};
    scrollbar-background: {DBG};
    scrollbar-size-vertical: 1;
    margin-bottom: 1;
}}
.ioc-hint   {{ color: {MUT};  text-align: center; height: 1; }}

/* ── Toast notifications ─────────────────────────────────────── */
Toast {{ background: {DBG}; color: {FG}; border: round {ACC}; }}
"""
