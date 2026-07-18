# ~/.config/qutebrowser/private.py
# Loaded by the private/incognito window launched via SUPER+SHIFT+B.
# Inherits everything from config.py then overrides colours to signal private mode.

config.load_autoconfig(False)  # noqa: F821

# Load main config cleanly — using 'with' ensures the file is properly closed
with open('/home/shadow/.config/qutebrowser/config.py') as _f:
    exec(_f.read())  # noqa: S102

# ── Visual indicator: dark red chrome so you always know you're private ────────
# Uses the same _mix helper that was defined by the exec above.
_P = '#3d0000'   # private dark red background
_PL = '#5a0a0a'  # slightly lighter for selected tab / active elements
_PR = '#ff8a8a'  # pink-red foreground

c.colors.statusbar.normal.bg      = _P     # noqa: F821
c.colors.statusbar.normal.fg      = _PR
c.colors.statusbar.insert.bg      = _mix(_P, '#9ece6a', 0.25)  # noqa: F821
c.colors.statusbar.command.bg     = _P
c.colors.statusbar.command.fg     = _PR
c.colors.statusbar.url.fg         = _PR
c.colors.statusbar.url.success.https.fg = '#ff9a9a'
c.colors.statusbar.url.hover.fg         = '#ffbbbb'

c.colors.tabs.bar.bg              = _P
c.colors.tabs.odd.bg              = _P
c.colors.tabs.odd.fg              = '#cc6666'
c.colors.tabs.even.bg             = _P
c.colors.tabs.even.fg             = '#cc6666'
c.colors.tabs.selected.odd.bg     = _PL
c.colors.tabs.selected.odd.fg     = _PR
c.colors.tabs.selected.even.bg    = _PL
c.colors.tabs.selected.even.fg    = _PR
