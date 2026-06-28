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
  omarchy-fish    # Omarchy's own fish package (from pkgs.omarchy.org, not AUR)
  yazi            # terminal file manager
  qutebrowser     # keyboard-driven browser
  python-adblock  # adblock backend for qutebrowser
  ydotool         # uinput-based input automation (keyboard-driven cursor)
  superfile       # GUI like file manager in termianl
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
  # example-aur-package
)

if ((${#AUR_PACKAGES[@]} > 0)); then
  omarchy-pkg-aur-add "${AUR_PACKAGES[@]}"
else
  echo "    No AUR packages to install, skipping."
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: browser — install Chrome, set as default, drop Chromium
# ════════════════════════════════════════════════════════════════════════
# omarchy-install-browser pulls google-chrome from the AUR and wires up
# its policy dir / chromium-flags. omarchy-default-browser then points
# xdg-settings + xdg-mime at it. Finally we remove Chromium, which Omarchy
# ships by default, since Chrome replaces it here.

gum style --foreground 2 "==> Installing and setting Chrome as default browser"

omarchy-install-browser chrome
omarchy-default-browser chrome

echo "    Removing chromium (replaced by Chrome)"
omarchy-pkg-drop chromium

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
# SECTION: input group + uinput (required for ydotool)
# ════════════════════════════════════════════════════════════════════════
# Mirrors Omarchy's own install/config/input-group.sh pattern exactly.

gum style --foreground 2 "==> Configuring uinput access for ydotool"

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
# SECTION: ydotool service
# ════════════════════════════════════════════════════════════════════════
# Backs the keyboard-driven cursor binds in ~/.config/hypr/bindings.lua.
# If the user was JUST added to the 'input' group above, this may still
# fail until they log out/in — that's expected, not a bug.

gum style --foreground 2 "==> Enabling ydotool service"

systemctl --user enable --now ydotool 2>&1 || true

if systemctl --user is-active --quiet ydotool; then
  echo "    ydotool service is active."
else
  gum style --foreground 3 "ydotool service did not start. If you were just added to the 'input' group, log out/in and run:  systemctl --user restart ydotool"
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: copy .config/ (interactive checklist, pre-checked)
# ════════════════════════════════════════════════════════════════════════

gum style --foreground 2 "==> Copying .config/"

SRC_CONFIG="$DOTFILES_ROOT/.config"
DEST_CONFIG="$HOME/.config"

if [[ ! -d $SRC_CONFIG ]]; then
  echo "    No .config/ directory in this repo, skipping."
else
  mapfile -t CONFIG_ITEMS < <(find "$SRC_CONFIG" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)

  if ((${#CONFIG_ITEMS[@]} == 0)); then
    echo "    .config/ is empty, nothing to copy."
  else
    SELECTED_STRING=$(gum choose --no-limit --selected='*' \
      --header "Select .config/ items to install into ~/.config/ (space to toggle, enter to confirm)" \
      --selected-prefix="✓ " --unselected-prefix="✗ " \
      "${CONFIG_ITEMS[@]}")

    SELECTED=()
    while IFS= read -r line; do
      [[ -n $line ]] && SELECTED+=("$line")
    done <<<"$SELECTED_STRING"

    if ((${#SELECTED[@]} == 0)); then
      echo "    Nothing selected, skipping .config/ copy."
    else
      mkdir -p "$DEST_CONFIG"
      for item in "${SELECTED[@]}"; do
        cp -rT "$SRC_CONFIG/$item" "$DEST_CONFIG/$item" 2>/dev/null \
          || cp -r "$SRC_CONFIG/$item" "$DEST_CONFIG/"
        echo "    Copied .config/$item"
      done
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# SECTION: copy .local/ (interactive checklist, pre-checked)
# ════════════════════════════════════════════════════════════════════════

gum style --foreground 2 "==> Copying .local/"

SRC_LOCAL="$DOTFILES_ROOT/.local"
DEST_LOCAL="$HOME/.local"

if [[ ! -d $SRC_LOCAL ]]; then
  echo "    No .local/ directory in this repo, skipping."
else
  mapfile -t LOCAL_ITEMS < <(find "$SRC_LOCAL" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)

  if ((${#LOCAL_ITEMS[@]} == 0)); then
    echo "    .local/ is empty, nothing to copy."
  else
    SELECTED_STRING=$(gum choose --no-limit --selected='*' \
      --header "Select .local/ items to install into ~/.local/ (space to toggle, enter to confirm)" \
      --selected-prefix="✓ " --unselected-prefix="✗ " \
      "${LOCAL_ITEMS[@]}")

    SELECTED=()
    while IFS= read -r line; do
      [[ -n $line ]] && SELECTED+=("$line")
    done <<<"$SELECTED_STRING"

    if ((${#SELECTED[@]} == 0)); then
      echo "    Nothing selected, skipping .local/ copy."
    else
      mkdir -p "$DEST_LOCAL"
      for item in "${SELECTED[@]}"; do
        cp -rT "$SRC_LOCAL/$item" "$DEST_LOCAL/$item" 2>/dev/null \
          || cp -r "$SRC_LOCAL/$item" "$DEST_LOCAL/"
        echo "    Copied .local/$item"
      done

      # Re-mark any scripts executable in case git stripped the bit on clone.
      find "$DEST_LOCAL/bin" -maxdepth 1 -type f -exec chmod +x {} \; 2>/dev/null || true
    fi
  fi
fi

# ════════════════════════════════════════════════════════════════════════
# Done
# ════════════════════════════════════════════════════════════════════════

echo ""
gum style --foreground 2 --bold "All done. Some changes (shell, input group) need a logout/reboot to fully apply."
