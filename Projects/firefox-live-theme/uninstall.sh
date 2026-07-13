#!/bin/bash
#
# uninstall.sh -- reverses install.sh. Safe to run even if install.sh
# was only partially successful (e.g. systemd wasn't reachable at
# install time) -- every step below tolerates the thing it's removing
# already being absent.
#
set -uo pipefail  # no -e: we want every cleanup step attempted regardless

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$HOME/.local/share/firefox-live-theme"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
OMARCHY_THEMED_DIR="$HOME/.config/omarchy/themed"
SERVICE_NAME="firefox-live-theme.service"

log()  { printf '  %s\n' "$1"; }
step() { printf '\n==> %s\n' "$1"; }
warn() { printf '  !! %s\n' "$1" >&2; }

step "Stopping and removing systemd service"
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user disable --now "$SERVICE_NAME" 2>/dev/null \
    && log "stopped and disabled" \
    || warn "couldn't stop/disable via systemctl (maybe already stopped, or no session bus)"
else
  warn "systemctl not found, skipping"
fi
rm -f "$SYSTEMD_USER_DIR/$SERVICE_NAME"
command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true
log "removed $SYSTEMD_USER_DIR/$SERVICE_NAME"

step "Removing installed payload"
rm -rf "$INSTALL_ROOT"
log "removed $INSTALL_ROOT"

step "Theme template"
TEMPLATE_DEST="$OMARCHY_THEMED_DIR/firefox-theme.json.tpl"
TEMPLATE_SRC="$PROJECT_ROOT/templates/firefox-theme.json.tpl"
if [[ -f $TEMPLATE_DEST ]]; then
  if cmp -s "$TEMPLATE_SRC" "$TEMPLATE_DEST"; then
    rm -f "$TEMPLATE_DEST"
    log "removed $TEMPLATE_DEST"
  else
    warn "$TEMPLATE_DEST differs from this project's version -- leaving it"
    warn "in place in case you've customized it. Remove it yourself if you"
    warn "don't want it: rm '$TEMPLATE_DEST'"
  fi
else
  log "no template file present, nothing to do"
fi

step "Firefox extension"
cat <<'EOF'
  This script doesn't touch the extension inside Firefox itself --
  remove it the normal way if you installed it:
    about:addons -> Firefox Live Theme (Omarchy) -> Remove
EOF

step "Done"
log "your Omarchy theme-set flow is untouched; nothing else changes."
