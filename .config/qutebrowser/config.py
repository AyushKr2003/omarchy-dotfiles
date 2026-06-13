# =============================================================================
#  Omarchy qutebrowser config.py
#  Live-adapts to the active omarchy theme by reading:
#    ~/.local/state/omarchy/current/theme/colors.toml
#
#  Drop this file at: ~/.config/qutebrowser/config.py
#  It is self-contained — no extra Python files needed.
# =============================================================================

import os
import re
import subprocess

# ── Silence linters ───────────────────────────────────────────────────────────
config = config  # noqa: F821 pylint: disable=E0602,C0103
c = c            # noqa: F821 pylint: disable=E0602,C0103

# ── Load GUI-set settings ─────────────────────────────────────────────────────
config.load_autoconfig(True)


# =============================================================================
#  1. Theme loader — reads the current omarchy colors.toml at startup
# =============================================================================

def _parse_colors_toml(path: str) -> dict:
    """Parse a simple key = "#hex" TOML palette into a dict."""
    out = {}
    if not os.path.isfile(path):
        return out
    with open(path) as f:
        for line in f:
            line = line.strip()
            m = re.match(r'^(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', line)
            if m:
                out[m.group(1)] = m.group(2)
    return out


def _mix(hex1: str, hex2: str, frac: float) -> str:
    """Linear-interpolate between two #rrggbb colors (frac=0 → hex1, 1 → hex2)."""
    def parse(h): return tuple(int(h.lstrip('#')[i:i+2], 16) for i in (0, 2, 4))
    r1, g1, b1 = parse(hex1)
    r2, g2, b2 = parse(hex2)
    r = int(r1 + (r2 - r1) * frac)
    g = int(g1 + (g2 - g1) * frac)
    b = int(b1 + (b2 - b1) * frac)
    return f'#{r:02x}{g:02x}{b:02x}'


# Active omarchy theme path (quattro layout)
_THEME_PATH = os.path.expanduser(
    '~/.local/state/omarchy/current/theme/colors.toml'
)
# Legacy path fallback (omarchy-shell branch layout)
_THEME_PATH_LEGACY = os.path.expanduser(
    '~/.config/omarchy/current/theme/colors.toml'
)

_raw = _parse_colors_toml(_THEME_PATH)
if not _raw:
    _raw = _parse_colors_toml(_THEME_PATH_LEGACY)

# Tokyo Night defaults — used when no theme file is found
_DEFAULTS = {
    'mode':       'dark',
    'bg':         '#1a1b26',
    'dark_bg':    '#13141c',
    'darker_bg':  '#0e0e14',
    'lighter_bg': '#24283b',
    'selection':  '#292e42',
    'muted':      '#414868',
    'dark_fg':    '#565f89',
    'fg':         '#a9b1d6',
    'light_fg':   '#b4bee6',
    'bright_fg':  '#c0caf5',
    'accent':     '#7aa2f7',
    'red':        '#f7768e',
    'yellow':     '#e0af68',
    'orange':     '#eb927b',
    'green':      '#9ece6a',
    'cyan':       '#449dab',
    'blue':       '#7aa2f7',
    'magenta':    '#ad8ee6',
    'bright_red':     '#ff7a93',
    'bright_yellow':  '#ff9e64',
    'bright_green':   '#b9f27c',
    'bright_cyan':    '#0db9d7',
    'bright_blue':    '#7da6ff',
    'bright_magenta': '#bb9af7',
}

T = {**_DEFAULTS, **_raw}

# Convenience aliases
BG      = T['bg']
DARK_BG = T.get('dark_bg',    _mix(T['bg'], '#000000', 0.25))
SEL_BG  = T.get('selection',  _mix(T['bg'], T['fg'],   0.15))
MUTED   = T.get('muted',      _mix(T['bg'], T['fg'],   0.35))
DARK_FG = T.get('dark_fg',    _mix(T['bg'], T['fg'],   0.55))
FG      = T['fg']
BRIGHT_FG = T.get('bright_fg', T['fg'])
ACCENT  = T.get('accent',     T.get('blue', '#7aa2f7'))
RED     = T.get('red',   '#f7768e')
YELLOW  = T.get('yellow','#e0af68')
GREEN   = T.get('green', '#9ece6a')
CYAN    = T.get('cyan',  '#449dab')
MAGENTA = T.get('magenta','#ad8ee6')
ORANGE  = T.get('orange', _mix(RED, YELLOW, 0.5))

# Subtle variant for alternating rows (slightly lighter/darker than BG)
EVEN_BG = _mix(BG, FG, 0.03)
ODD_BG  = BG

IS_LIGHT = T.get('mode', 'dark') == 'light'


# =============================================================================
#  2. Core behaviour
# =============================================================================

c.aliases = {
    'w':   'session-save',
    'q':   'close',
    'qa':  'quit',
    'wq':  'quit --save',
    'wqa': 'quit --save',
}

c.auto_save.session = True
c.session.lazy_restore = True

# Use the omarchy default font (Inter / system-ui fallback)
_FONT_FAMILY = 'Inter, "Noto Sans", system-ui, sans-serif'
_FONT_MONO   = '"JetBrainsMono Nerd Font", "JetBrains Mono", monospace'
_FONT_SIZE   = '10pt'

c.fonts.default_family = _FONT_FAMILY
c.fonts.default_size   = _FONT_SIZE
c.fonts.web.family.standard    = _FONT_FAMILY
c.fonts.web.family.sans_serif  = _FONT_FAMILY
c.fonts.web.family.fixed       = _FONT_MONO
c.fonts.web.size.default       = 16
c.fonts.web.size.default_fixed = 13

# Scrolling
c.scrolling.smooth = True
c.scrolling.bar    = 'overlay'

# Tabs
c.tabs.show            = 'multiple'
c.tabs.last_close      = 'close'
c.tabs.tabs_are_windows = False
c.tabs.mousewheel_switching = False
c.tabs.padding = {'top': 6, 'bottom': 6, 'left': 8, 'right': 8}
c.tabs.indicator.width = 2
c.tabs.indicator.padding = {'top': 2, 'bottom': 2, 'left': 0, 'right': 4}
c.tabs.favicons.scale = 1.0
c.tabs.title.format = '{audio}{index}: {current_title}'
c.tabs.title.format_pinned = '{audio}{index}'

# Status bar
c.statusbar.show    = 'always'
c.statusbar.padding = {'top': 4, 'bottom': 4, 'left': 8, 'right': 8}
c.statusbar.widgets = ['keypress', 'url', 'scroll', 'history', 'tabs', 'progress']

# URL bar
c.url.default_page    = 'https://duckduckgo.com'
c.url.start_pages     = ['https://duckduckgo.com']
c.url.searchengines   = {
    'DEFAULT': 'https://search.brave.com/search?q={}',
    'g':  'https://google.com/search?q={}',
    'gh': 'https://github.com/search?q={}',
    'yt': 'https://youtube.com/results?search_query={}',
    'w':  'https://en.wikipedia.org/w/index.php?search={}',
    'np': 'https://search.nixos.org/packages?query={}',
}

# Hints — use accent color letters
c.hints.mode        = 'letter'
c.hints.chars       = 'asdfjkl;'
c.hints.min_chars   = 1
c.hints.auto_follow = 'unique-match'
c.hints.padding     = {'top': 2, 'bottom': 2, 'left': 4, 'right': 4}
c.hints.border      = f'1px solid {ACCENT}'
c.hints.radius      = 4

# Downloads
c.downloads.location.directory  = '~/Downloads'
c.downloads.location.prompt     = False
c.downloads.open_dispatcher     = 'xdg-open'
c.downloads.position            = 'bottom'
c.downloads.remove_finished     = 5000

# Privacy / content
c.content.autoplay              = False
c.content.cookies.accept        = 'no-3rdparty'
c.content.geolocation           = 'ask'
c.content.notifications.enabled = 'ask'
c.content.javascript.clipboard = 'access'
c.content.pdfjs                 = True

# Completion popup
c.completion.height             = '30%'
c.completion.quick              = True
c.completion.show               = 'always'
c.completion.shrink             = True
c.completion.use_best_match     = False
c.completion.open_categories    = ['searchengines', 'quickmarks', 'bookmarks', 'history', 'filesystem']

# Zoom
c.zoom.default  = '100%'

# Editor (Ctrl-E in insert mode)
c.editor.command = ['alacritty', '-e', 'nvim', '{file}', '+{line}']


# =============================================================================
#  3. Colours — every surface mapped to the live omarchy palette
# =============================================================================

# ── 3a. Completion widget ─────────────────────────────────────────────────────

# Category headers (e.g. "Quickmarks", "History")
c.colors.completion.category.bg             = DARK_BG
c.colors.completion.category.fg             = BRIGHT_FG
c.colors.completion.category.border.top     = DARK_BG
c.colors.completion.category.border.bottom  = _mix(BG, ACCENT, 0.35)

# Even / odd rows
c.colors.completion.even.bg = EVEN_BG
c.colors.completion.odd.bg  = ODD_BG
c.colors.completion.fg      = [FG, MUTED, MUTED]   # [text, url, meta]

# Selected row
c.colors.completion.item.selected.bg              = SEL_BG
c.colors.completion.item.selected.fg              = BRIGHT_FG
c.colors.completion.item.selected.border.top      = _mix(SEL_BG, ACCENT, 0.5)
c.colors.completion.item.selected.border.bottom   = _mix(SEL_BG, ACCENT, 0.5)
c.colors.completion.item.selected.match.fg        = ACCENT

# Match highlight inside non-selected rows
c.colors.completion.match.fg = ACCENT

# Scrollbar
c.colors.completion.scrollbar.bg = DARK_BG
c.colors.completion.scrollbar.fg = MUTED

# ── 3b. Context menu ─────────────────────────────────────────────────────────

c.colors.contextmenu.menu.bg      = BG
c.colors.contextmenu.menu.fg      = FG
c.colors.contextmenu.selected.bg  = SEL_BG
c.colors.contextmenu.selected.fg  = BRIGHT_FG
c.colors.contextmenu.disabled.bg  = BG
c.colors.contextmenu.disabled.fg  = DARK_FG

# ── 3c. Downloads bar ────────────────────────────────────────────────────────

c.colors.downloads.bar.bg    = DARK_BG
c.colors.downloads.error.bg  = _mix(BG, RED, 0.25)
c.colors.downloads.error.fg  = RED
c.colors.downloads.start.bg  = _mix(BG, CYAN, 0.25)
c.colors.downloads.start.fg  = CYAN
c.colors.downloads.stop.bg   = _mix(BG, GREEN, 0.25)
c.colors.downloads.stop.fg   = GREEN
c.colors.downloads.system.bg = 'none'
c.colors.downloads.system.fg = 'none'

# ── 3d. Hints ────────────────────────────────────────────────────────────────

c.colors.hints.bg      = _mix(BG, YELLOW, 0.15)
c.colors.hints.fg      = YELLOW
c.colors.hints.match.fg = ACCENT

# ── 3e. Keyhint widget ───────────────────────────────────────────────────────

c.colors.keyhint.bg        = f'rgba({int(BG[1:3],16)},{int(BG[3:5],16)},{int(BG[5:7],16)},0.92)'
c.colors.keyhint.fg        = FG
c.colors.keyhint.suffix.fg = ACCENT

# ── 3f. Error / info / warning messages ──────────────────────────────────────

c.colors.messages.error.bg    = _mix(BG, RED,    0.20)
c.colors.messages.error.fg    = RED
c.colors.messages.error.border = RED

c.colors.messages.info.bg     = _mix(BG, CYAN,  0.15)
c.colors.messages.info.fg     = CYAN
c.colors.messages.info.border  = CYAN

c.colors.messages.warning.bg  = _mix(BG, YELLOW, 0.18)
c.colors.messages.warning.fg  = YELLOW
c.colors.messages.warning.border = YELLOW

# ── 3g. Prompts (yes/no, file picker) ────────────────────────────────────────

c.colors.prompts.bg           = BG
c.colors.prompts.fg           = FG
c.colors.prompts.border       = f'1px solid {_mix(BG, ACCENT, 0.5)}'
c.colors.prompts.selected.bg  = SEL_BG
c.colors.prompts.selected.fg  = BRIGHT_FG

# ── 3h. Status bar — every mode ──────────────────────────────────────────────

# Normal mode
c.colors.statusbar.normal.bg = BG
c.colors.statusbar.normal.fg = FG

# Insert mode  → green tint (mirrors omarchy active-state green)
c.colors.statusbar.insert.bg = _mix(BG, GREEN, 0.18)
c.colors.statusbar.insert.fg = GREEN

# Command mode → accent blue
c.colors.statusbar.command.bg = DARK_BG
c.colors.statusbar.command.fg = FG
c.colors.statusbar.command.private.bg = _mix(DARK_BG, MAGENTA, 0.15)
c.colors.statusbar.command.private.fg = MAGENTA

# Caret mode  → cyan
c.colors.statusbar.caret.bg              = _mix(BG, CYAN,  0.18)
c.colors.statusbar.caret.fg              = CYAN
c.colors.statusbar.caret.selection.bg    = _mix(BG, CYAN,  0.30)
c.colors.statusbar.caret.selection.fg    = BRIGHT_FG

# Passthrough mode → muted
c.colors.statusbar.passthrough.bg = _mix(BG, MUTED, 0.35)
c.colors.statusbar.passthrough.fg = FG

# Private browsing → magenta
c.colors.statusbar.private.bg = _mix(BG, MAGENTA, 0.18)
c.colors.statusbar.private.fg = MAGENTA

# Progress bar (loading indicator) — accent color
c.colors.statusbar.progress.bg = ACCENT

# URL display states
c.colors.statusbar.url.fg             = FG
c.colors.statusbar.url.error.fg       = RED
c.colors.statusbar.url.hover.fg       = ACCENT
c.colors.statusbar.url.success.http.fg  = YELLOW   # plain http → warn yellow
c.colors.statusbar.url.success.https.fg = GREEN    # https → reassuring green
c.colors.statusbar.url.warn.fg          = ORANGE

# ── 3i. Tabs ─────────────────────────────────────────────────────────────────

# Bar background (behind all tabs)
c.colors.tabs.bar.bg = DARK_BG

# Inactive tabs
c.colors.tabs.odd.bg  = DARK_BG
c.colors.tabs.odd.fg  = DARK_FG
c.colors.tabs.even.bg = DARK_BG
c.colors.tabs.even.fg = DARK_FG

# Selected tab
c.colors.tabs.selected.odd.bg  = BG
c.colors.tabs.selected.odd.fg  = BRIGHT_FG
c.colors.tabs.selected.even.bg = BG
c.colors.tabs.selected.even.fg = BRIGHT_FG

# Pinned tabs — slightly accented
c.colors.tabs.pinned.odd.bg           = _mix(DARK_BG, ACCENT, 0.10)
c.colors.tabs.pinned.odd.fg           = ACCENT
c.colors.tabs.pinned.even.bg          = _mix(DARK_BG, ACCENT, 0.10)
c.colors.tabs.pinned.even.fg          = ACCENT
c.colors.tabs.pinned.selected.odd.bg  = _mix(BG, ACCENT, 0.15)
c.colors.tabs.pinned.selected.odd.fg  = ACCENT
c.colors.tabs.pinned.selected.even.bg = _mix(BG, ACCENT, 0.15)
c.colors.tabs.pinned.selected.even.fg = ACCENT

# Tab indicator (loading / audio / muted)
c.colors.tabs.indicator.start  = CYAN
c.colors.tabs.indicator.stop   = ACCENT
c.colors.tabs.indicator.error  = RED
c.colors.tabs.indicator.system = 'none'

# ── 3j. Web page colours (dark mode injection) ────────────────────────────────
# Ask QtWebEngine to auto-darken pages if the omarchy theme is dark.
if not IS_LIGHT:
    c.colors.webpage.darkmode.enabled         = True
    c.colors.webpage.darkmode.algorithm       = 'lightness-cielab'
    c.colors.webpage.darkmode.contrast        = 0.0
    c.colors.webpage.darkmode.policy.page     = 'smart'
    c.colors.webpage.darkmode.policy.images   = 'smart'
    c.colors.webpage.darkmode.threshold.foreground  = 150
    c.colors.webpage.darkmode.threshold.background  = 205
else:
    c.colors.webpage.darkmode.enabled = False

c.colors.webpage.preferred_color_scheme = 'dark' if not IS_LIGHT else 'light'
c.colors.webpage.bg = BG


# =============================================================================
#  4. Fonts — every widget set to the omarchy font stack
# =============================================================================

c.fonts.completion.entry    = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.completion.category = f'bold {_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.contextmenu         = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.downloads           = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.hints               = f'bold {_FONT_SIZE} {_FONT_MONO}'
c.fonts.keyhint             = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.messages.error      = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.messages.info       = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.messages.warning    = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.prompts             = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.statusbar           = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.tabs.selected       = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.tabs.unselected     = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.tooltip             = f'{_FONT_SIZE} {_FONT_FAMILY}'


# =============================================================================
#  5. Keybindings — Vim-style, following omarchy conventions
# =============================================================================

# ── Normal mode ───────────────────────────────────────────────────────────────

# Navigation
config.bind('H',  'back')
config.bind('L',  'forward')
config.bind('J',  'tab-prev')
config.bind('K',  'tab-next')
config.bind('gj', 'tab-move -')
config.bind('gk', 'tab-move +')
config.bind('x',  'tab-close')
config.bind('X',  'undo')
config.bind('u',  'undo')

# Open
config.bind('o',  'cmd-set-text -s :open')
config.bind('O',  'cmd-set-text -s :open -t')
config.bind('go', 'cmd-set-text :open {url}')
config.bind('gO', 'cmd-set-text :open -t {url}')

# Quick search
config.bind('/',  'cmd-set-text /')
config.bind('?',  'cmd-set-text ?')
config.bind('n',  'search-next')
config.bind('N',  'search-prev')

# Bookmarks / quickmarks
config.bind('m',  'quickmark-save')
config.bind("'",  'cmd-set-text -s :quickmark-load')

# Zoom
config.bind('+', 'zoom-in')
config.bind('-', 'zoom-out')
config.bind('=', 'zoom 100')

# Clipboard
config.bind('yy', 'yank')
config.bind('yY', 'yank -s')
config.bind('yt', 'yank title')
config.bind('yp', 'yank pretty-url')

# Developer tools
config.bind('<F12>', 'devtools')
config.bind('wi',    'devtools')

# Session
config.bind('<Ctrl-s>', 'session-save')

# Reload current theme from disk (useful after `omarchy theme set …`)
config.bind('<Ctrl-Shift-r>', 'config-source ;; message-info "omarchy theme reloaded"')

# ── Insert mode ───────────────────────────────────────────────────────────────
config.bind('<Ctrl-e>', 'edit-text',     mode='insert')
config.bind('<Escape>', 'mode-leave',    mode='insert')

# ── Command mode ──────────────────────────────────────────────────────────────
config.bind('<Ctrl-j>', 'completion-item-focus next',     mode='command')
config.bind('<Ctrl-k>', 'completion-item-focus prev',     mode='command')
config.bind('<Ctrl-d>', 'completion-item-del',            mode='command')
config.bind('<Escape>', 'mode-leave',                     mode='command')

# ── Hint mode ────────────────────────────────────────────────────────────────
config.bind('<Ctrl-b>', 'hint all tab-bg', mode='hint')
config.bind('<Escape>', 'mode-leave',      mode='hint')


# =============================================================================
#  6. User stylesheet — injects omarchy CSS variables into every page
#     so pages that respect prefers-color-scheme get the right palette.
# =============================================================================

_CSS = f"""
:root {{
    --omarchy-bg:       {BG};
    --omarchy-fg:       {FG};
    --omarchy-accent:   {ACCENT};
    --omarchy-red:      {RED};
    --omarchy-green:    {GREEN};
    --omarchy-yellow:   {YELLOW};
    --omarchy-cyan:     {CYAN};
    --omarchy-magenta:  {MAGENTA};
    --omarchy-muted:    {MUTED};
    --omarchy-sel:      {SEL_BG};
}}
/* Scrollbar styling to match omarchy */
::-webkit-scrollbar {{ width: 6px; height: 6px; }}
::-webkit-scrollbar-track {{ background: {BG}; }}
::-webkit-scrollbar-thumb {{ background: {MUTED}; border-radius: 3px; }}
::-webkit-scrollbar-thumb:hover {{ background: {DARK_FG}; }}
/* Selection highlight */
::selection {{ background: {SEL_BG}; color: {BRIGHT_FG}; }}
"""

_css_path = os.path.expanduser('~/.config/qutebrowser/omarchy-user.css')
os.makedirs(os.path.dirname(_css_path), exist_ok=True)
with open(_css_path, 'w') as _f:
    _f.write(_CSS)

c.content.user_stylesheets = [_css_path]


# =============================================================================
#  7. omarchy-theme-watch: auto-reload when theme changes
#     A systemd path unit or inotifywait daemon can touch a trigger file;
#     qutebrowser picks it up on next config-source call.
#     For manual reload use <Ctrl-Shift-r> bound above.
# =============================================================================

# Optional: if you want qutebrowser to watch the theme file automatically,
# add this to ~/.config/systemd/user/qutebrowser-theme-watch.service:
#
#   [Unit]
#   Description=Reload qutebrowser when omarchy theme changes
#   [Service]
#   ExecStart=/bin/bash -c \
#     "inotifywait -m -e close_write \
#      ~/.local/state/omarchy/current/theme/colors.toml | \
#      while read; do \
#        qutebrowser ':config-source' 2>/dev/null; \
#      done"
#   [Install]
#   WantedBy=default.target
