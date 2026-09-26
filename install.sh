#!/usr/bin/env bash
#
# install.sh — single-file installer for AyushKr2003/omarchy-dotfiles
#
# Run from the root of a freshly cloned copy of this repo:
#   git clone https://github.com/AyushKr2003/omarchy-dotfiles.git ~/omarchy-dotfiles
#   cd ~/omarchy-dotfiles
#   ./install.sh
#
# Safe to re-run. Organized into clearly marked sections below — to add a
# future package or step, find the matching section and add a line/block.
# No other files needed; this is intentionally one script.

set -euo pipefail

export DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure git submodules (omarchy-overview, shell-settings, omacale) are
# initialized. shell/omacale is its own repo (AyushKr2003/omacale); it is not
# symlinked into ~/.config. Install it with shell/omacale/install.sh, or for
# development sync shell/omacale/omacale.bar into ~/.config/omarchy/plugins.
if command -v git &>/dev/null && [[ -d "$DOTFILES_ROOT/.git" ]]; then
  git -C "$DOTFILES_ROOT" submodule update --init --recursive 2>/dev/null || true
  if [[ ! -f "$DOTFILES_ROOT/shell/omacale/install.sh" ]]; then
    echo "warning: shell/omacale submodule is missing; run: git submodule update --init shell/omacale" >&2
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: helpers / presentation
# ════════════════════════════════════════════════════════════════════════

# Ensure gum is available (almost always already true on Omarchy, but a
# bare Arch box running this repo standalone might not have it yet).
if ! command -v gum &>/dev/null; then
  if command -v omarchy-pkg-add &>/dev/null; then
    omarchy-pkg-add gum
  else
    sudo pacman -S --noconfirm --needed gum
  fi
fi

# Reasonable terminal width fallback (keeps gum --width flags sane even
# when run non-interactively or piped).
if [[ -e /dev/tty ]]; then
  TERM_SIZE=$(stty size 2>/dev/null </dev/tty || true)
  if [[ -n ${TERM_SIZE:-} ]]; then
    export TERM_WIDTH=$(echo "$TERM_SIZE" | cut -d' ' -f2)
  else
    export TERM_WIDTH=80
  fi
else
  export TERM_WIDTH=80
fi

# Backup existing target if it exists and is not already a symlink pointing to src
backup_target() {
  local target="$1"
  local src="$2"

  if [[ -e "$target" || -L "$target" ]]; then
    # If target is already a symlink pointing to src, no backup needed
    if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
      return 0
    fi

    local backup_path="${target}.bak"
    if [[ -e "$backup_path" || -L "$backup_path" ]]; then
      backup_path="${target}.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    echo "    [Backup] $(basename "$target") -> $(basename "$backup_path")"
    mv "$target" "$backup_path"
  fi
}

# Recursive, JSON-driven symlink helper function
process_symlink() {
  local src="$1"
  local dest="$2"
  local rel_path="$3"    # e.g. "omarchy" or "omarchy/plugins"
  local category="$4"    # e.g. "config"
  
  local link_type
  link_type=$(jq -r ".\"$category\"[\"$rel_path\"]" "$SYMLINKS_JSON" 2>/dev/null)
  
  if [[ "$link_type" == "null" ]]; then
    if [[ -f "$src" ]]; then
      link_type="file"
    else
      # If a directory doesn't have an explicit rule, keep recursing inside it
      link_type="files"
    fi
  fi
  
  if [[ "$link_type" == "dir" ]]; then
    backup_target "$dest" "$src"
    if [[ -e "$dest" || -L "$dest" ]]; then
      rm -rf "$dest"
    fi
    ln -s "$src" "$dest"
    echo "    [Dir]  $rel_path"
  elif [[ "$link_type" == "files" ]]; then
    mkdir -p "$dest"
    for child in "$src"/*; do
      [[ -e "$child" ]] || continue
      local basename="$(basename "$child")"
      process_symlink "$child" "$dest/$basename" "$rel_path/$basename" "$category"
    done
  elif [[ "$link_type" == "file" || -f "$src" ]]; then
    backup_target "$dest" "$src"
    if [[ -e "$dest" || -L "$dest" ]]; then
      rm -f "$dest"
    fi
    ln -s "$src" "$dest"
    echo "    [File] $rel_path"
  fi
}

clear
gum style --foreground 6 --border rounded --padding "1 2" --align center \
  "omarchy-dotfiles installer" "$(whoami)@$(hostname)"
echo ""

# ════════════════════════════════════════════════════════════════════════
# SECTION: pacman packages (official Arch 'extra' + Omarchy's own repo)
# ════════════════════════════════════════════════════════════════════════
# omarchy-pkg-add is idempotent — safe to re-run.
# To add a future package: just add it to the array below.

gum style --foreground 2 "==> Installing pacman packages"

PACMAN_PACKAGES=(
  jq              # required for symlinks.json parsing
  omarchy-fish    # Omarchy's own fish package (from pkgs.omarchy.org, not AUR)
  yazi            # terminal file manager
  qutebrowser     # keyboard-driven browser
  python-adblock  # adblock backend for qutebrowser
  socat           # fievel-notify listens on Hyprland's event socket
  librsvg         # omarchy-cursor-material renders Bibata SVGs
  xorg-xcursorgen # omarchy-cursor-material builds the X11 cursor set
  superfile       # GUI like file manager in termianl
  qt6-imageformats # quickshell webP image support
  python-curl_cffi # for manga quickshell plugin backend
  # Add more pacman packages here as you grow this repo.
)

omarchy-pkg-add "${PACMAN_PACKAGES[@]}"

# ════════════════════════════════════════════════════════════════════════
# SECTION: AUR packages
# ════════════════════════════════════════════════════════════════════════
# Currently empty — none of the packages above need the AUR.
# Add entries here as you adopt AUR-only tools in the future.

gum style --foreground 2 "==> Installing AUR packages"

AUR_PACKAGES=(
  herdr-bin       # terminal workspace manager for AI coding agents
  # Add more aur packages here as you grow this repo.
)

if ((${#AUR_PACKAGES[@]} > 0)); then
  omarchy-pkg-aur-add "${AUR_PACKAGES[@]}"
else
  echo "    No AUR packages to install, skipping."
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: browser — enable Google Account sign-in for Chromium
# ════════════════════════════════════════════════════════════════════════

gum style --foreground 2 "==> Enabling Chromium Google Account support"

omarchy-install-chromium-google-account

# ════════════════════════════════════════════════════════════════════════
# SECTION: terminal — install kitty, set as default, drop foot
# ════════════════════════════════════════════════════════════════════════
# omarchy-install-terminal installs kitty via pacman (official repo) and
# already points xdg-terminals.list at it; omarchy-default-terminal does
# the same thing again explicitly (harmless, matches the browser pattern
# above). foot is Omarchy's shipped default terminal, removed here since
# kitty replaces it.

gum style --foreground 2 "==> Installing and setting kitty as default terminal"

omarchy-install-terminal kitty
omarchy-default-terminal kitty

echo "    Removing foot (replaced by kitty)"
omarchy-pkg-drop foot

# ════════════════════════════════════════════════════════════════════════
# SECTION: shell — set fish as default shell
# ════════════════════════════════════════════════════════════════════════

gum style --foreground 2 "==> Setting fish as default shell"

chsh -s "$(which fish)"

# ════════════════════════════════════════════════════════════════════════
# SECTION: drop preinstall package
# ════════════════════════════════════════════════════════════════════════
# Remove some preinstall package from default install

omarchy-pkg-drop 1password-beta 1password-cli

# ════════════════════════════════════════════════════════════════════════
# SECTION: input group + uinput (required for fievel)
# ════════════════════════════════════════════════════════════════════════
# Mirrors Omarchy's own install/config/input-group.sh pattern exactly.

gum style --foreground 2 "==> Configuring uinput access for fievel"

echo "    Loading uinput kernel module"
sudo modprobe uinput

echo "    Persisting uinput module load across reboots"
echo uinput | sudo tee /etc/modules-load.d/uinput.conf >/dev/null

echo "    Adding $USER to the 'input' group"
if groups "$USER" | grep -qw input; then
  echo "    Already in 'input' group, skipping."
else
  sudo usermod -aG input "$USER"
  echo "    Added. NOTE: log out and back in (or reboot) for this to take effect."
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: icon install
# ════════════════════════════════════════════════════════════════════════

gum style --foreground 2 "==> Installing icon pack"

ICON_TAR="$DOTFILES_ROOT/icon_pack.tar.gz"
DEST_ICONS="$HOME/.local/share/icons"

if [[ -f "$ICON_TAR" ]]; then
  mkdir -p "$DEST_ICONS"
  tar -xzf "$ICON_TAR" -C "$DEST_ICONS"
  echo "    Extracted icon pack to $DEST_ICONS"
else
  echo "    icon_pack.tar.gz not found, skipping icon install."
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: copy .config/ (symlink everything directly based on json)
# ════════════════════════════════════════════════════════════════════════

gum style --foreground 2 "==> Installing .config/"

SRC_CONFIG="$DOTFILES_ROOT/config"
DEST_CONFIG="$HOME/.config"
SYMLINKS_JSON="$DOTFILES_ROOT/symlinks.json"

if [[ ! -d $SRC_CONFIG ]]; then
  echo "    No .config/ directory in this repo, skipping."
else
  mapfile -t CONFIG_ITEMS < <(find "$SRC_CONFIG" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)

  if ((${#CONFIG_ITEMS[@]} == 0)); then
    echo "    .config/ is empty, nothing to install."
  else
    mkdir -p "$DEST_CONFIG"
    for item in "${CONFIG_ITEMS[@]}"; do
      src_item="$SRC_CONFIG/$item"
      target_item="$DEST_CONFIG/$item"
      
      # Read the symlink type from JSON, default to "dir" if not specified at top level
      link_type=$(jq -r ".\"config\".\"$item\" // \"dir\"" "$SYMLINKS_JSON")
      
      if [[ "$link_type" == "dir" ]]; then
        backup_target "$target_item" "$src_item"
        if [[ -e "$target_item" || -L "$target_item" ]]; then
          rm -rf "$target_item"
        fi
        ln -s "$src_item" "$target_item"
        echo "    [Dir]  $item"
      elif [[ "$link_type" == "files" ]]; then
        process_symlink "$src_item" "$target_item" "$item" "config"
      else
        echo "    [Skip] Unknown link type '$link_type' for .config/$item"
      fi
    done
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: copy .local/ (symlink everything directly based on json)
# ════════════════════════════════════════════════════════════════════════

gum style --foreground 2 "==> Installing .local/"

SRC_LOCAL="$DOTFILES_ROOT/local"
DEST_LOCAL="$HOME/.local"

if [[ ! -d $SRC_LOCAL ]]; then
  echo "    No .local/ directory in this repo, skipping."
else
  mapfile -t LOCAL_ITEMS < <(find "$SRC_LOCAL" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)

  if ((${#LOCAL_ITEMS[@]} == 0)); then
    echo "    .local/ is empty, nothing to install."
  else
    mkdir -p "$DEST_LOCAL"
    for item in "${LOCAL_ITEMS[@]}"; do
      src_item="$SRC_LOCAL/$item"
      target_item="$DEST_LOCAL/$item"
      
      # Read the symlink type from JSON, default to "dir" if not specified at top level
      link_type=$(jq -r ".\"local\".\"$item\" // \"dir\"" "$SYMLINKS_JSON")
      
      if [[ "$link_type" == "dir" ]]; then
        backup_target "$target_item" "$src_item"
        if [[ -e "$target_item" || -L "$target_item" ]]; then
          rm -rf "$target_item"
        fi
        ln -s "$src_item" "$target_item"
        echo "    [Dir]  $item"
      elif [[ "$link_type" == "files" ]]; then
        process_symlink "$src_item" "$target_item" "$item" "local"
      else
        echo "    [Skip] Unknown link type '$link_type' for .local/$item"
      fi
    done

    # Re-mark any scripts executable in case git stripped the bit on clone.
    # Only affects actual files, resolving through symlinks where necessary
    find "$DEST_LOCAL/bin" -maxdepth 1 -type f -exec chmod +x {} \; 2>/dev/null || true
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: Material Bibata cursor (follows the theme accent)
# ════════════════════════════════════════════════════════════════════════
# omarchy-cursor-material rebuilds Bibata-Material-Omarchy from the Bibata
# SVG source on every theme change (hooks/theme-set.d/40-cursor-material).
# Pinned to the commit Ryoku builds from. Select it via cursor_theme in
# hypr/autostart.lua. Runs after .local/ so the tool is on PATH.

gum style --foreground 2 "==> Installing Material Bibata cursor"

BIBATA_COMMIT="f4ccfe8abb63fddc7b3ce51a866fd8378395cb3d"
BIBATA_SRC="$HOME/.local/share/omarchy-cursor-material/bibata"

if [[ $(git -C "$BIBATA_SRC" rev-parse HEAD 2>/dev/null) == "$BIBATA_COMMIT" ]]; then
  echo "    Bibata source already at pinned commit, skipping clone."
else
  rm -rf "$BIBATA_SRC"
  git clone -q https://github.com/rtgiskard/bibata_cursor.git "$BIBATA_SRC"
  git -C "$BIBATA_SRC" checkout -q "$BIBATA_COMMIT"
fi

"$HOME/.local/bin/omarchy-cursor-material" --force --full
echo "    Built Bibata-Material-Omarchy in the current theme accent."

# ════════════════════════════════════════════════════════════════════════
# SECTION: fievel (keyboard-driven mouse)
# ════════════════════════════════════════════════════════════════════════
# Not in the AUR — pinned release binary into ~/.local/bin. Runs after the
# .config/ section so fievel.config and fievel.service are already linked.
# To update: bump FIEVEL_VERSION and FIEVEL_SHA256 (sha256 of the tarball).

gum style --foreground 2 "==> Installing fievel"

FIEVEL_VERSION="1.1.0"
FIEVEL_SHA256="2ab24467951084c278bb3e5a07f8e27b8a367a149be4606289834e3113d14de5"
FIEVEL_BIN="$HOME/.local/bin/fievel"

if [[ -x $FIEVEL_BIN && -f $HOME/.local/state/fievel/installed-version && $(<"$HOME/.local/state/fievel/installed-version") == "$FIEVEL_VERSION" ]]; then
  echo "    fievel $FIEVEL_VERSION already installed, skipping download."
else
  FIEVEL_TMP=$(mktemp -d)
  FIEVEL_TAR="$FIEVEL_TMP/fievel.tar.gz"
  curl -fsSL -o "$FIEVEL_TAR" \
    "https://github.com/MontyTheSoftwareEngineer/fievel/releases/download/$FIEVEL_VERSION/fievel-$FIEVEL_VERSION-linux-x64.tar.gz"
  if ! echo "$FIEVEL_SHA256  $FIEVEL_TAR" | sha256sum -c --quiet -; then
    gum style --foreground 1 "fievel checksum mismatch, not installing."
    rm -rf "$FIEVEL_TMP"
    exit 1
  fi
  tar -xzf "$FIEVEL_TAR" -C "$FIEVEL_TMP" fievel
  install -Dm755 "$FIEVEL_TMP/fievel" "$FIEVEL_BIN"
  mkdir -p "$HOME/.local/state/fievel"
  echo "$FIEVEL_VERSION" >"$HOME/.local/state/fievel/installed-version"
  rm -rf "$FIEVEL_TMP"
  echo "    Installed fievel $FIEVEL_VERSION to $FIEVEL_BIN"
fi

# Replaced ydotool's cursor submap; stop its daemon if an older install left it on.
systemctl --user disable --now ydotool 2>/dev/null || true

systemctl --user daemon-reload
systemctl --user enable fievel fievel-notify 2>&1 || true
systemctl --user restart fievel fievel-notify 2>&1 || true

if systemctl --user is-active --quiet fievel; then
  echo "    fievel service is active (Super+Ctrl+M toggles mouse mode)."
else
  gum style --foreground 3 "fievel did not start. If you were just added to the 'input' group, log out/in and run:  systemctl --user restart fievel"
fi

# ════════════════════════════════════════════════════════════════════════
# Done
# ════════════════════════════════════════════════════════════════════════

echo ""
gum style --foreground 2 --bold "All done. Some changes (shell, input group) need a logout/reboot to fully apply."
