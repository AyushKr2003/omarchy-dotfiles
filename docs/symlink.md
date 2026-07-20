# Symlink Configuration

The `symlinks.json` file controls how the `install.sh` script links directories and files from this repo (`config/` and `local/`) to your home directory (`~/.config/` and `~/.local/`).

## Rule Types

There are two primary rule types you can assign to any path:

*   **`"dir"`**: Symlinks the *entire directory* directly. 
    *   *Result:* `~/.config/mpv` -> `omarchy-dotfiles/config/mpv`
    *   *Use when:* You want the repo to be the sole source of truth for a folder, and no other apps will be automatically generating cache/junk files inside it.
    *   *(This is the default for any top-level folder not explicitly defined).*

*   **`"files"`**: Recursively steps into the directory, creates a real folder in your home directory, and symlinks *only the individual files* inside.
    *   *Result:* `~/.config/hypr/input.lua` -> `omarchy-dotfiles/config/hypr/input.lua`
    *   *Use when:* You only want to track specific config files, but want to allow the app to generate its own untracked files in the same folder without polluting your git repo.

## Multi-Layer (Nested) Rules

The script's logic is highly scalable. You can define rules for specific subdirectories to override their parent's behavior. 

**Example (omarchy):**
```json
{
  "config": {
    "omarchy": "files",
    "omarchy/plugins": "dir"
  }
}
```
*What this does:*
1. Sees `"omarchy": "files"`, so it creates a real `~/.config/omarchy/` folder.
2. It symlinks the individual files directly inside it (like `shell.json`).
3. When it reaches the `plugins/` subdirectory, it sees the override `"omarchy/plugins": "dir"`, so it symlinks the *entire* plugins folder at once instead of recursing further.

## Adding a New Folder

1. Place your new folder inside `config/` or `local/` in this repo.
2. If you just want the whole directory symlinked, **you don't need to do anything**. (`"dir"` is the default).
3. If you want to use the `"files"` behavior, open `symlinks.json` and add a line under the appropriate category:
   ```json
   "your-new-folder": "files"
   ```
4. Run `./install.sh`.
