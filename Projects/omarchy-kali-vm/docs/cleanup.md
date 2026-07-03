# Cleanup Boundaries

The project keeps package ownership, VM runtime data, and Omarchy-specific user integration separate on purpose.

## Package Removal

Removing the package only removes package-owned files installed by pacman:

- launcher binaries in `/usr/bin`
- icon assets in `/usr/share/icons`
- packaged snippets and docs in `/usr/share/omarchy-kali-vm`

Package removal does not remove `~/.config/kali`, `~/.kali`, `~/Kali`, the runtime-created launcher in `~/.local/share/applications`, or any optional Omarchy integration markers under `~/.config`.

## VM Data Removal

Run `omarchy-kali-vm remove` when you want to delete the Kali VM runtime data created for your user. This removes:

- `~/.config/kali`
- `~/.kali`
- `~/Kali`
- `~/.local/share/applications/omarchy-kali-vm.desktop`

It does not uninstall the package and does not remove Omarchy integration markers.

Run `omarchy-kali-vm remove --debug` when you want the same VM cleanup while preserving downloaded Kali archives in a debug report directory under `~/.local/state/omarchy-kali-vm` and keeping the `qemux/qemu` image available for investigation.

## Omarchy Integration Removal (quattro branch)

Run `omarchy-kali-vm-unintegrate-os` when you want to remove the Omarchy integration that was previously added by this project. On the **quattro** branch, this removes:

- The `require("omarchy-kali-vm.hypr.omarchy-kali-vm")` marker block from `~/.config/hypr/hyprland.lua`
- The `install.kali` / `remove.kali` marker block from `~/.config/omarchy/extensions/omarchy-menu.jsonc`
- The copied Lua module directory, `~/.config/omarchy-kali-vm`

The helper removes only its own marked blocks and its own copied files — the rest of `hyprland.lua` and `omarchy-menu.jsonc` (including any other extensions you've added) is left exactly as it was.
