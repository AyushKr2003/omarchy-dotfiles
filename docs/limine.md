## Limine Boot Menu (Omarchy default)

Omarchy's default boot menu config lives at
`/usr/share/omarchy/default/limine/limine.conf` (read-only, package-owned).
The live config is `/boot/limine.conf`.

### Default `limine.conf`
```
### Read more at config document: https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md
timeout: 1
quiet: yes
default_entry: 2
interface_branding: Omarchy Bootloader
interface_branding_color: 9ece6a
interface_help_color: 9ece6a
interface_help_color_bright: 9ece6a
hash_mismatch_panic: no

term_background: 1a1b26
backdrop: 1a1b26

# Terminal colors (Tokyo Night palette)
term_palette: 15161e;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6
term_palette_bright: 414868;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;c0caf5

# Text colors
term_foreground: c0caf5
term_foreground_bright: c0caf5
term_background_bright: 24283b
```

### What changed in Omarchy 4.5
| Setting   | Old default | New default |
|-----------|-------------|-------------|
| `timeout` | `5`         | `1`         |
| `quiet`   | `no`        | `yes`       |

- Boot menu waits 1 second and stays hidden.
- Tap any key (down arrow works) during startup to show the menu / pick a snapshot.

### Why my `/boot/limine.conf` didn't change
The update migration (`/usr/share/omarchy/migrations/1791898365.sh`) only:
- sets `timeout: 1` if there is **no** uncommented `timeout:` line
- adds `quiet: yes` if there is **no** `quiet:` line

An existing `timeout: 5` / `quiet: no` is treated as the user's choice and left alone.

### Switch to the new behaviour
```bash
sudo sed -i -E 's/^timeout:.*/timeout: 1/; s/^quiet:.*/quiet: yes/' /boot/limine.conf
```

To keep the menu visible longer, just set your own value (e.g. `timeout: 5`) — updates won't touch it.
