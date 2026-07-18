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
_FONT_SIZE   = '11pt'

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
# ── Tabs — match tmux window-status style ─────────────────────────────────────
# tmux: window-status-format         = " #I:#W "  (dim)
# tmux: window-status-current-format = " #I:#W "  (accent, bold)
c.tabs.show            = 'multiple'
c.tabs.last_close      = 'close'
c.tabs.tabs_are_windows = False
c.tabs.mousewheel_switching = False
c.tabs.padding = {'top': 5, 'bottom': 5, 'left': 8, 'right': 8}
c.tabs.indicator.width = 0            # no side indicator — tmux has none
c.tabs.favicons.scale = 0.8
# Mirror tmux: " #I:#W " — index:title, no favicon clutter
c.tabs.title.format        = ' {index}:{current_title} '
c.tabs.title.format_pinned = ' {index}:{current_title} '

# Status bar — mirrors tmux status bar layout:
#   LEFT:  [ mode pill ]   like tmux's "#[fg=black,bg=blue,bold] #S "
#   MID:   url             like the window list area
#   RIGHT: scroll | mode indicators | host   like tmux right
c.statusbar.show    = 'always'
c.statusbar.padding = {'top': 4, 'bottom': 4, 'left': 6, 'right': 6}
c.statusbar.widgets = ['keypress', 'url', 'scroll', 'history', 'progress']

# URL bar
c.url.default_page    = 'https://duckduckgo.com'
c.url.start_pages     = ['https://duckduckgo.com']
c.url.searchengines   = {
    'DEFAULT': 'https://duckduckgo.com/search?q={}',
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

# Custom hint selector groups
# Per the Reddit thread (r/qutebrowser/comments/ajczeh):
#   - 'f' already shows hints on iframes natively — the hint appears in the
#     top-left corner of each frame. Follow it to focus that frame.
#   - For arbitrary scrollable divs (not iframes), use the 'scrollable' group
#     below, which works in tandem with the qb-scrollable.js Greasemonkey
#     script that marks scrollable elements with .__qb_scrollable__ at runtime.
c.hints.selectors = {
    # Default groups (keep these so built-in bindings still work)
    'all': [
        'a', 'area', 'textarea', 'select',
        'input:not([type="hidden"])', 'button',
        'frame', 'iframe', 'img', 'link', 'summary',
        '[contenteditable]:not([contenteditable="false"])',
        '[onclick]', '[onmousedown]',
        '[role="link"]', '[role="option"]', '[role="button"]',
        '[role="tab"]', '[role="checkbox"]', '[role="switch"]',
        '[role="menuitem"]', '[aria-haspopup]',
        '[tabindex]:not([tabindex="-1"])',
    ],
    'links':  ['a[href]', 'area[href]', 'link[href]', '[role="link"][href]'],
    'images': ['img'],
    'media':  ['audio', 'img', 'video'],
    'url':    ['[src]', '[href]'],
    'inputs': [
        'input[type="text"]', 'input[type="email"]', 'input[type="url"]',
        'input[type="tel"]', 'input[type="number"]', 'input[type="password"]',
        'input[type="search"]', 'input:not([type])', 'textarea',
    ],
    # 'scrollable' group intentionally removed — the qb-scrollable.js script
    # that powers it walks the full DOM with getComputedStyle() on every node,
    # causing pages to hang and RAM to spike. Use ;f / f for iframes instead.
}

# Downloads
c.downloads.location.directory  = '~/Downloads'
c.downloads.location.prompt     = True
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

# ── 3h. Status bar — tmux-mirrored per-mode styling ─────────────────────────
#
# tmux pattern  (from omarchy config/tmux/tmux.conf):
#   status-style              bg=default, fg=default
#   status-left               #[fg=black,bg=blue,bold] #S    → accent pill
#   status-right              #[fg=blue] COPY/PREFIX/ZOOM  #[fg=brightblack] host
#   window-status-format      #[fg=brightblack] #I:#W        → dim inactive
#   window-status-current     #[fg=blue,bold]   #I:#W        → accent active
#   message-style             bg=default, fg=blue
#   mode-style                bg=blue, fg=black
#   pane-active-border-style  fg=blue
#
# We map these 1:1:
#   tmux "blue"        → ACCENT   (theme accent key)
#   tmux "black"       → BG       (terminal background)
#   tmux "brightblack" → MUTED    (dim fg / color8)
#   tmux "default"     → BG / FG  (terminal bg/fg)

# ── Normal mode — "default" bg like tmux status-style ────────────────────────
c.colors.statusbar.normal.bg = DARK_BG
c.colors.statusbar.normal.fg = FG

# ── Insert mode — GREEN pill (maps to a safe/active state, not in tmux) ──────
# We use a solid accent-colored left segment approach: bg=green fg=BG
# so it reads as a filled pill exactly like tmux's " #S " segment.
c.colors.statusbar.insert.bg = GREEN
c.colors.statusbar.insert.fg = BG

# ── Command mode — accent fg on dark bg, like tmux message-style fg=blue ─────
c.colors.statusbar.command.bg         = DARK_BG
c.colors.statusbar.command.fg         = ACCENT
c.colors.statusbar.command.private.bg = DARK_BG
c.colors.statusbar.command.private.fg = MAGENTA

# ── Caret mode — CYAN pill (visual selection indicator) ──────────────────────
c.colors.statusbar.caret.bg           = CYAN
c.colors.statusbar.caret.fg           = BG
c.colors.statusbar.caret.selection.bg = CYAN
c.colors.statusbar.caret.selection.fg = BG

# ── Passthrough — YELLOW pill (maps to tmux ZOOM indicator color) ─────────────
c.colors.statusbar.passthrough.bg = YELLOW
c.colors.statusbar.passthrough.fg = BG

# ── Private — MAGENTA pill ────────────────────────────────────────────────────
c.colors.statusbar.private.bg = MAGENTA
c.colors.statusbar.private.fg = BG

# ── Progress bar — accent, like tmux pane-active-border fg=blue ───────────────
c.colors.statusbar.progress.bg = ACCENT

# ── URL states — mirrors tmux right-status color logic ───────────────────────
c.colors.statusbar.url.fg              = MUTED       # idle, like brightblack host
c.colors.statusbar.url.hover.fg        = ACCENT      # accent on hover
c.colors.statusbar.url.error.fg        = RED
c.colors.statusbar.url.success.http.fg = YELLOW      # warn: plain http
c.colors.statusbar.url.success.https.fg = GREEN      # safe: https
c.colors.statusbar.url.warn.fg         = ORANGE

# ── 3i. Tabs — tmux window-status exact mapping ──────────────────────────────
#
# tmux: window-status-format         "#[fg=brightblack] #I:#W "  → MUTED, dim
# tmux: window-status-current-format "#[fg=blue,bold]   #I:#W "  → ACCENT, bold
# tmux: status-style bg=default                                   → DARK_BG
# tmux: window-status-separator ""                                → no gap

# Bar background — "bg=default" in tmux = terminal background = DARK_BG
c.colors.tabs.bar.bg = DARK_BG

# Inactive tabs → tmux brightblack (MUTED) fg, default bg
c.colors.tabs.odd.bg  = DARK_BG
c.colors.tabs.odd.fg  = MUTED
c.colors.tabs.even.bg = DARK_BG
c.colors.tabs.even.fg = MUTED

# Active/selected tab → tmux blue (ACCENT) fg, bold, same bg
# We give it a very subtle bg lift so there's a visual anchor without a border
c.colors.tabs.selected.odd.bg  = _mix(DARK_BG, ACCENT, 0.08)
c.colors.tabs.selected.odd.fg  = ACCENT
c.colors.tabs.selected.even.bg = _mix(DARK_BG, ACCENT, 0.08)
c.colors.tabs.selected.even.fg = ACCENT

# Pinned tabs — same as active but always accent-tinted
c.colors.tabs.pinned.odd.bg           = _mix(DARK_BG, ACCENT, 0.06)
c.colors.tabs.pinned.odd.fg           = _mix(MUTED, ACCENT, 0.5)
c.colors.tabs.pinned.even.bg          = _mix(DARK_BG, ACCENT, 0.06)
c.colors.tabs.pinned.even.fg          = _mix(MUTED, ACCENT, 0.5)
c.colors.tabs.pinned.selected.odd.bg  = _mix(DARK_BG, ACCENT, 0.08)
c.colors.tabs.pinned.selected.odd.fg  = ACCENT
c.colors.tabs.pinned.selected.even.bg = _mix(DARK_BG, ACCENT, 0.08)
c.colors.tabs.pinned.selected.even.fg = ACCENT

# Tab loading indicator — tmux uses cyan→blue for session switches
# start=CYAN (loading), stop=ACCENT (done), error=RED
c.colors.tabs.indicator.start  = CYAN
c.colors.tabs.indicator.stop   = ACCENT
c.colors.tabs.indicator.error  = RED
c.colors.tabs.indicator.system = 'none'

# ── 3j. Web page colours ─────────────────────────────────────────────────────
# NOTE: darkmode.enabled is intentionally OFF.
# QtWebEngine's dark mode re-renders every page through a colour inversion
# algorithm which is very RAM and CPU intensive, causes pages to get stuck
# in a loading state, and breaks many sites. Use a dark-mode browser
# extension or site-level dark themes instead.
c.colors.webpage.darkmode.enabled       = False
c.colors.webpage.preferred_color_scheme = 'dark' if not IS_LIGHT else 'light'
c.colors.webpage.bg                     = BG


# =============================================================================
#  4. Fonts — every widget set to the omarchy font stack
# =============================================================================

c.fonts.completion.entry    = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.completion.category = f'bold {_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.contextmenu         = f'{_FONT_SIZE} {_FONT_FAMILY}'
c.fonts.downloads           = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.hints               = f'bold {_FONT_SIZE} {_FONT_MONO}'
c.fonts.keyhint             = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.messages.error      = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.messages.info       = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.messages.warning    = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.prompts             = f'{_FONT_SIZE} {_FONT_FAMILY}'
# Statusbar and tabs use the mono font — mirrors tmux's terminal font rendering
c.fonts.statusbar           = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.tabs.selected       = f'bold {_FONT_SIZE} {_FONT_MONO}'
c.fonts.tabs.unselected     = f'{_FONT_SIZE} {_FONT_MONO}'
c.fonts.tooltip             = f'{_FONT_SIZE} {_FONT_FAMILY}'


# =============================================================================
#  5. Keybindings — Vim-style, following omarchy conventions
# =============================================================================

# ── Normal mode ───────────────────────────────────────────────────────────────

# Drops focus from the video player and returns it to the page
config.bind('<Ctrl-e>', 'jseval -q document.activeElement.blur()')

# Hints — restore defaults explicitly so they are never shadowed
config.bind('f',  'hint links')
config.bind('F',  'hint links tab')
config.bind(';b', 'hint all tab-bg')
config.bind(';i', 'hint images')
config.bind(';I', 'hint images tab')
config.bind(';r', 'hint --rapid links tab-bg')
# Frame focus:
#   f   → natively shows hints on links AND iframes (top-left of each iframe)
#   gF  → return focus to the main page
config.bind('gF', 'focus-main-frame')

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
#  6. User stylesheet — DISABLED
#     Injecting a stylesheet into every page adds per-page overhead and can
#     interfere with site rendering. The scrollbar + selection styles below
#     are kept as a comment so you can opt in per-site if needed.
#     To re-enable: uncomment the block and run :config-source
# =============================================================================

# _CSS = f"""
# ::-webkit-scrollbar {{ width: 6px; height: 6px; }}
# ::-webkit-scrollbar-track {{ background: {BG}; }}
# ::-webkit-scrollbar-thumb {{ background: {MUTED}; border-radius: 3px; }}
# ::-webkit-scrollbar-thumb:hover {{ background: {DARK_FG}; }}
# ::selection {{ background: {SEL_BG}; color: {BRIGHT_FG}; }}
# """
# _css_path = os.path.expanduser('~/.config/qutebrowser/omarchy-user.css')
# os.makedirs(os.path.dirname(_css_path), exist_ok=True)
# with open(_css_path, 'w') as _f:
#     _f.write(_CSS)
# c.content.user_stylesheets = [_css_path]


# =============================================================================
#  7. Ad blocking
#
#  REQUIRES: pip install adblock   (or: pacman -S python-adblock)
#  After first install or any list change, run:  :adblock-update
#
#  Method 'both' = Brave's Rust ABP engine (network blocking) + hosts file
#  blocker working in tandem for maximum coverage.
# =============================================================================

c.content.blocking.enabled = True
c.content.blocking.method  = 'both'          # ABP engine + hosts, combined
c.content.blocking.hosts.block_subdomains = True   # block *.ads.example.com too

# ── ABP / uBlock-style filter lists (network request blocking) ────────────────
# These are evaluated by the Brave adblock engine built into qutebrowser.
# Run :adblock-update after changing this list.
c.content.blocking.adblock.lists = [

    # ── Core — EasyList + EasyPrivacy (industry standard, always alive) ───────
    'https://easylist.to/easylist/easylist.txt',
    'https://easylist.to/easylist/easyprivacy.txt',

    # ── uBlock Origin filters (verified paths from uBlockOrigin/uAssets) ──────
    # Main filter — catches what EasyList misses, includes YouTube ad rules
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt',
    # Current-year supplement (uBO splits filters by year since 2020)
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters-2025.txt',
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters-2026.txt',
    # Privacy — telemetry, fingerprinting, tracking params, CDN trackers
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt',
    # Privacy removeparam — strips tracking query parameters from URLs
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy-removeparam.txt',
    # Unbreak — re-allows things broken by other filters
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/unbreak.txt',
    # Resource abuse — cryptomining, pop-unders, tab-unders
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/resource-abuse.txt',
    # Badware — known malicious domains and scripts
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt',
    # Quick fixes — emergency patches pushed between major releases
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/quick-fixes.txt',
    # General filters (cross-platform, non-cosmetic rules)
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters-general.txt',

    # ── uBO Annoyances (social.txt was removed; replaced by these) ────────────
    # Cookie consent banners — auto-dismisses GDPR overlays
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances-cookies.txt',
    # Everything else: newsletter popups, push prompts, survey walls, social widgets
    'https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances-others.txt',

    # ── Fanboy annoyances (separate from uBO, good supplemental coverage) ─────
    'https://secure.fanboy.co.nz/fanboy-cookiemonster.txt',
    'https://secure.fanboy.co.nz/fanboy-annoyance.txt',

    # ── Malware / phishing — URLhaus live blocklist ───────────────────────────
    'https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-online.txt',

    # ── AdGuard base + tracking + annoyances (via AdGuard CDN) ───────────────
    'https://filters.adtidy.org/extension/ublock/filters/2.txt',   # AdGuard Base
    'https://filters.adtidy.org/extension/ublock/filters/3.txt',   # AdGuard Tracking
    'https://filters.adtidy.org/extension/ublock/filters/14.txt',  # AdGuard Annoyances
    'https://filters.adtidy.org/extension/ublock/filters/4.txt',   # AdGuard Social Media
]

# ── Hosts-file blocklists (domain-level, no python-adblock needed) ────────────
# These work even without the python-adblock package installed.
# StevenBlack's unified hosts file = base + malware + fakenews
c.content.blocking.hosts.lists = [
    'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts',
]

# ── Whitelist — sites that should never be blocked ───────────────────────────
# Add domains here that get accidentally broken by the lists above.
c.content.blocking.whitelist = [
    # 'example.com',
]


# =============================================================================
#  8. omarchy-theme-watch: auto-reload when theme changes
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
