# omarchy-kali-vm

My custom fork of original [omarchy-kali-vm](https://github.com/r3b1s/omarchy-kali-vm.git). 

Provides an accessible "click-to-install" Kali Linux VM using a dockerized QEMU environment to minimize dependencies. Intended for [Omarchy](https://github.com/basecamp/omarchy), but should work on any Arch setup with `docker` engine set up. Supports clipboard-sharing + display auto-resizing on Hyprland. Includes window rules for a smooth, borderless experience. Can integrate into Omarchy's menu alongside Omarchy's default Windows VM.

> **Branch note:** This README describes integration with Omarchy's
> **quattro** branch (Lua Hyprland config + Quickshell/JSONC menu). If
> you're on Omarchy master/dev, use an older release of this package —
> the integration mechanics there target a plain `hyprland.conf` and a
> walker-based `menu.sh`, which quattro no longer has.

## Dependencies

Everything below is checked automatically by `omarchy-kali-vm` before it runs, but if you're setting things up manually or on a non-Omarchy Arch system, install these first:

| Dependency | Arch package | Used for |
|---|---|---|
| Docker Engine + Compose plugin | `docker`, `docker-compose` (compose v2 plugin) | Running the `qemux/qemu` container |
| `sudo` | `sudo` | Privileged setup steps |
| `gum` | `gum` | Interactive terminal prompts |
| `curl` | `curl` | Downloading Kali QEMU images |
| `gpg` | `gnupg` | Verifying image signatures |
| `sha256sum` | `coreutils` | Verifying image checksums |
| `remote-viewer` | `virt-viewer` | SPICE display to the VM |

Additional runtime requirements:

- `/dev/kvm` must exist (hardware virtualization enabled in BIOS/UEFI and the `kvm`/`kvm_intel`/`kvm_amd` kernel modules loaded).
- The Docker daemon must be running and your user must be able to run `docker` (typically via membership in the `docker` group).
- Enough free disk space for the VM disk image (default 64 GB virtual size + ~10 GB headroom; actual usage is much lower thanks to QCOW2's copy-on-write format).

Optional, for Omarchy's smoother integration:

- Omarchy on the **quattro** branch (for the Lua window rule and JSONC menu integration described below). Not required — `omarchy-kali-vm` works standalone via its own runtime-created `.desktop` launcher.

## Installation

### Manual install (no AUR)

1. **Install base build tooling and dependencies** (see the table above):

   **Non-Omarchy user:**
   ```sh
   sudo pacman -S base-devel git docker docker-compose sudo gum curl gnupg coreutils virt-viewer
   sudo systemctl enable --now docker
   sudo usermod -aG docker "$USER"   # log out/in afterward for group membership to take effect
   ```

   **Omarchy user:**
   `base-devel`, `git`, `docker`, `docker-compose`, `gum`, `sudo`, `curl`, `gnupg`, and `coreutils` all ship with Omarchy by default. Docker is already set up too — Omarchy socket-activates it via `docker.socket` (so it starts on demand without a running `docker.service`), and your user is already in the `docker` group. The only thing missing is `virt-viewer`:
   ```sh
   omarchy-pkg-add virt-viewer
   ```
2. **Clone this repo:**
   ```sh
   git clone https://github.com/AyushKr2003/omarchy-dotfiles
   cd omarchy-dotfiles/Projects/omarchy-kali-vm
   ```
3. **Add the `PKGBUILD`** to the repo root (next to `bin/`, `share/`, `docs/`) — see [PKGBUILD](PKGBUILD) — then build and install with `makepkg`:
   ```sh
   makepkg -si
   ```
   `-s` resolves and installs any missing `depends`/`makedepends` via pacman first; `-i` installs the resulting package once it's built. This installs the binaries, icon, and the packaged Hyprland/menu snippets to the same system paths the AUR package would use (`/usr/bin`, `/usr/share/icons`, `/usr/share/omarchy-kali-vm`).
4. **Run the VM setup:**
   ```sh
   omarchy-kali-vm install
   ```
5. **(Omarchy quattro only) Enable Hyprland/menu integration:**
   ```sh
   omarchy-kali-vm-integrate-os
   hyprctl reload
   ```

To uninstall a manual install, reverse the steps: `omarchy-kali-vm-unintegrate-os`, `omarchy-kali-vm remove`, then `sudo pacman -R omarchy-kali-vm` (since it was installed as a real pacman package via `makepkg -si`, a normal package removal cleans up the files from step 3).

## Summary
Adds first-class Kali VM support to Omarchy via `omarchy-kali-vm`. Uses [`qemux/qemu`](https://github.com/qemus/qemu), a containerized QEMU environment, to minimize dependencies. The only external display dependency required is `virt-viewer` for the SPICE display. Clipboard integration and desktop resizing are available out of the box.

The implementation intentionally follows the Windows VM design pattern, but adapts it for **Kali's prebuilt QEMU images**.

### Scope
The package does not edit `~/.local/share/omarchy` and does not clean up user dotfiles automatically on install or uninstall.

- Base package: launcher command, icon, packaged Hyprland and Omarchy menu snippets, and documentation.
- User runtime data: `~/.config/kali`, `~/.kali`, `~/Kali`, and the runtime-created desktop entry in `~/.local/share/applications`.
- Optional Omarchy integration: user-run helpers that add or remove Omarchy menu rows and a Hyprland window rule under `~/.config`. The Hyprland window rule makes the SPICE viewer behave like a native Omarchy app. The runtime-created launcher works without Omarchy; Omarchy-specific menu and Hyprland integration is opt-in.

### Patching the QEMU Image
The QEMU Image is patched during initial setup to apply selected configurations, expand the virtual harddrive and filesystem. While patching, SPICE agent support is wired in so resize events propagate properly. XFCE was given a small autoresize helper that polls `xrandr`, applies the preferred mode when the display changes, and restarts the user-session `spice-vdagent` if needed. That extra guest-side step was necessary because XFCE was not reliably applying the new SPICE-provided resolution on its own, which in turn caused mouse alignment to break after resizes.

### Control Flow
1. The user runs `omarchy-kali-vm install` from a terminal or an Omarchy-integrated menu entry. This is a first-time setup command and exits early if managed Kali VM state already exists.
2. The script gathers VM resources and guest credentials from the user, writes the Kali compose config, and prepares local storage under `~/.kali`.
3. It downloads the latest weekly Kali QEMU archive, verifies it cryptographically, extracts the QCOW2, and patches the image offline with the configured user/session changes. If something goes wrong with the weekly image, the script falls back to the latest current/stable Kali QEMU archive.
4. It starts the VM through the `qemux/qemu` container, waits for the SPICE socket, writes a user-owned `Kali` desktop entry, and opens `remote-viewer`. By default, closing the viewer powers the VM down cleanly.
5. Later launches reuse the same compose/storage setup and just start the VM and connect over SPICE.
6. Removal tears down the Kali VM state from the same entrypoint and removes the runtime-created launcher.

## Commands

- `omarchy-kali-vm install`
- `omarchy-kali-vm install --debug`
- `omarchy-kali-vm launch`
- `omarchy-kali-vm stop`
- `omarchy-kali-vm status`
- `omarchy-kali-vm remove`
- `omarchy-kali-vm remove --debug`
- `omarchy-kali-vm-integrate-os`
- `omarchy-kali-vm-unintegrate-os`

For Omarchy users on the quattro branch, `omarchy-kali-vm-integrate-os` enables the packaged Hyprland window rule for a smoother `remote-viewer` experience and adds Omarchy menu integration for install and removal flows.

## Omarchy Integration (quattro branch)

`omarchy-kali-vm-integrate-os` makes two changes, both reversible and idempotent:

1. Inlines the `o.window(...)` rule from `share/hypr/omarchy-kali-vm.lua` directly into `~/.config/hypr/hyprland.lua`, inside marker comments — no separate module file, no `require()`.
2. Merges the `install.kali` / `remove.kali` rows from `share/omarchy-menu.jsonc` into `~/.config/omarchy/extensions/omarchy-menu.jsonc`, inside marker comments, just before the file's closing `}`.

Run `hyprctl reload` afterward to pick up the window rule. See [docs/integration.md](docs/integration.md) for the full mechanics and [docs/cleanup.md](docs/cleanup.md) for exactly what gets removed by `omarchy-kali-vm-unintegrate-os`.

## Cleanup Boundaries

- Remove Kali VM data: `omarchy-kali-vm remove`
- Remove Kali VM data but preserve archives and debug evidence: `omarchy-kali-vm remove --debug`
- Remove optional Omarchy integration: `omarchy-kali-vm-unintegrate-os`
- Remove the package: `yay -R omarchy-kali-vm` (or reverse the manual-install steps)

Additional details live in [docs/cleanup.md](docs/cleanup.md) and [docs/integration.md](docs/integration.md).
