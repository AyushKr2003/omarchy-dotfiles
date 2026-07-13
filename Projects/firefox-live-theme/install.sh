#!/bin/bash
#
# install.sh -- sets up firefox-live-theme for the current user only.
# Safe to re-run any time (e.g. after `git pull`ing an update to this
# project); every step below is idempotent.
#
# What this touches:
#   ~/.local/share/firefox-live-theme/          (this project's payload)
#   ~/.config/omarchy/themed/firefox-theme.json.tpl   (Omarchy's own
#     supported per-user template override directory -- nothing in
#     Omarchy's install or git tree is touched)
#   ~/.config/systemd/user/firefox-live-theme.service
#   Firefox/Zen's own policies.json, only if a signed .xpi is present
#     (see README.md's "signing" section) -- also only ever touches its
#     own single key, never the rest of that file's content
#
set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$HOME/.local/share/firefox-live-theme"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
OMARCHY_THEMED_DIR="$HOME/.config/omarchy/themed"
SERVICE_NAME="firefox-live-theme.service"

log()  { printf '  %s\n' "$1"; }
step() { printf '\n==> %s\n' "$1"; }
warn() { printf '  !! %s\n' "$1" >&2; }

# --- 1. Copy the payload (server + extension) into place -------------------

step "Installing files to $INSTALL_ROOT"
mkdir -p "$INSTALL_ROOT/bin" "$INSTALL_ROOT/extension"
cp "$PROJECT_ROOT/bin/theme-server" "$INSTALL_ROOT/bin/theme-server"
chmod +x "$INSTALL_ROOT/bin/theme-server"
cp "$PROJECT_ROOT"/extension/*.js "$PROJECT_ROOT/extension/manifest.json" "$INSTALL_ROOT/extension/"
log "server -> $INSTALL_ROOT/bin/theme-server"
log "extension source -> $INSTALL_ROOT/extension/"

# --- 2. Drop the theme template into Omarchy's user-template dir -----------
#
# This is Omarchy's own supported extension point (see its
# docs/theming.md: "User templates in ~/.config/omarchy/themed/*.tpl
# are processed before the built-in templates"). We only ever manage
# our own single file here.

step "Installing theme template"
mkdir -p "$OMARCHY_THEMED_DIR"
TEMPLATE_DEST="$OMARCHY_THEMED_DIR/firefox-theme.json.tpl"
TEMPLATE_SRC="$PROJECT_ROOT/templates/firefox-theme.json.tpl"

if [[ -f $TEMPLATE_DEST ]] && ! cmp -s "$TEMPLATE_SRC" "$TEMPLATE_DEST"; then
  warn "$TEMPLATE_DEST already exists and differs from this project's version."
  warn "Leaving it alone -- if it's yours, no problem; if it's a stale copy"
  warn "from an older install of this project, compare it against:"
  warn "  $TEMPLATE_SRC"
else
  cp "$TEMPLATE_SRC" "$TEMPLATE_DEST"
  log "$TEMPLATE_DEST"
fi

# --- 3. Install the systemd unit, with the real path filled in --------------

step "Installing systemd user service"
mkdir -p "$SYSTEMD_USER_DIR"
sed "s#__EXEC_PATH__#$INSTALL_ROOT/bin/theme-server#" \
  "$PROJECT_ROOT/systemd/firefox-live-theme.service.tpl" \
  > "$SYSTEMD_USER_DIR/$SERVICE_NAME"
log "$SYSTEMD_USER_DIR/$SERVICE_NAME"

if command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null; then
  if systemctl --user enable --now "$SERVICE_NAME" 2>/dev/null; then
    log "service enabled and started"
  else
    warn "systemd unit installed but couldn't be enabled/started right now"
    warn "(no active user session bus?). It'll start on your next login,"
    warn "or start it manually:"
    warn "  systemctl --user enable --now $SERVICE_NAME"
  fi
else
  warn "systemctl --user not reachable right now (no session bus, or not"
  warn "on a system with systemd). The unit file is installed; start the"
  warn "server manually for this session with:"
  warn "  $INSTALL_ROOT/bin/theme-server"
fi

# --- 4. Force an immediate re-render, so you don't have to switch themes ---
# to see this take effect. Best-effort: if omarchy-theme-set or the
# current theme name aren't available for any reason, this is skipped
# and the template will simply apply on your next real theme switch.

step "Refreshing the current theme so the new template applies now"
THEME_NAME_FILE="$HOME/.local/state/omarchy/current/theme.name"
if command -v omarchy-theme-set >/dev/null 2>&1 && [[ -f $THEME_NAME_FILE ]]; then
  CURRENT_THEME="$(cat "$THEME_NAME_FILE")"
  omarchy-theme-set "$CURRENT_THEME"
  log "re-ran omarchy-theme-set $CURRENT_THEME"
else
  warn "couldn't find omarchy-theme-set and/or $THEME_NAME_FILE"
  warn "the template will still apply the next time you switch themes"
fi

# --- 5. Tell the user what's left (the one manual step) ---------------------

SIGNED_XPI="$PROJECT_ROOT/extension/firefox-live-theme.xpi"
step "Extension install"
if [[ -f $SIGNED_XPI ]]; then
  cat <<EOF

  Found a signed build at:
    $SIGNED_XPI

  Install it the normal way any extension gets installed -- open it in
  Firefox once and click "Add":

    firefox "$SIGNED_XPI"

  That's it. No policy files, no enterprise config, nothing else in
  Firefox gets touched. Firefox remembers it after that like any other
  installed extension.
EOF
else
  cat <<EOF

  No signed build found yet at:
    $SIGNED_XPI

  Firefox requires every extension (themes included) to be signed by
  Mozilla before it'll load -- there's no config flag that bypasses this
  on regular Firefox/Zen, even for a purely personal install. This is a
  one-time step; see README.md's "Signing" section. Once you have the
  .xpi, drop it at the path above and re-run this script, or just open
  it directly with \`firefox path/to/that.xpi\`.

  The theme server above is already running regardless, and the
  re-render-on-theme-switch behavior works without it too -- this step
  is only needed for Firefox itself to pick up the colors.
EOF
fi

step "Done"
log "check status any time with:"
log "  systemctl --user status $SERVICE_NAME"
log "  curl -s http://127.0.0.1:47732/health"
