# Desktop Entries Vs Optional Omarchy Integration

## Runtime Launcher

The package does not install default desktop entries for non-Omarchy use.

After `omarchy-kali-vm install` succeeds, the command creates a single user-owned launcher:

- `~/.local/share/applications/omarchy-kali-vm.desktop`

That `Kali` launcher runs `omarchy-kali-vm launch` and is removed by `omarchy-kali-vm remove`. Until install completes, use the terminal commands directly.

## Optional Omarchy Integration (quattro branch)

> This document covers Omarchy's **quattro** branch, which replaced the classic
> `.conf`-based Hyprland config and the walker/`menu.sh` launcher with a
> **Lua** Hyprland config and a **Quickshell + JSONC** menu. If you're on
> Omarchy master/dev instead, the integration mechanics differ (plain
> `hyprland.conf` sourcing and `~/.config/omarchy/extensions/menu.sh`) —
> use an older release of this package for that branch.

Omarchy users can run `omarchy-kali-vm-integrate-os` to add two user-owned integrations:

- **Hyprland window rule.** The `o.window(...)` rule from the packaged
  `share/hypr/omarchy-kali-vm.lua` is inlined directly, inside marker
  comments, into `~/.config/hypr/hyprland.lua`. There's no separate
  module file and no `require()` — the rule lines themselves are copied
  in.
- **Omarchy menu entries.** Two rows, `install.kali` and `remove.kali`,
  are merged — inside marker comments, just before the file's closing
  `}` — into `~/.config/omarchy/extensions/omarchy-menu.jsonc`, the JSONC
  extension point Quickshell reads for user-added menu rows.

This optional integration gives the smoothest Omarchy experience:

- The Hyprland window rule makes the `remote-viewer` window behave correctly (fullscreen state, opacity) for the Kali session.
- The menu rows give you direct Install and Remove entries in Omarchy's Quickshell launcher alongside the existing system flows, without relying on package-owned desktop files.

The helper is idempotent. Re-running it does not duplicate the window rule or the menu rows — it checks for its own marker comments first.

Run `omarchy-kali-vm-unintegrate-os` to remove only the marker blocks managed by this project. It leaves the rest of `hyprland.lua` and `omarchy-menu.jsonc` untouched.

### What gets touched

| File | Change |
|---|---|
| `~/.config/hypr/hyprland.lua` | The `o.window(...)` rule block appended inside `-- >>> omarchy-kali-vm hypr integration >>>` / `-- <<< ... <<<` markers |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Two menu rows inserted before the closing `}`, inside `// >>> omarchy-kali-vm menu integration >>>` / `// <<< ... <<<` markers. Created (as `{}`) if it doesn't already exist |

No files are created outside these two — there's no `~/.config/omarchy-kali-vm` module directory.

### Why not a plain end-of-file append for the menu file?

`hyprland.lua` is a script, so appending after everything else is
harmless. `omarchy-menu.jsonc` is a JSON(C) object — appending after its
closing `}` would produce invalid JSON — so the integrate script instead
finds the last line that is only `}` and splices the marked block in
just before it.
