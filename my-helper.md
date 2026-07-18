## Snapper Command Cheat Sheet

### Basic info
```bash
snapper list-configs                    # list all configs (e.g. "root")
snapper -c root list                    # list all snapshots for root config
snapper -c root list --columns number,date,description
```

### Create
```bash
sudo snapper -c root create -d "before manual change"      # ad-hoc snapshot
sudo snapper -c root create -c number -d "pre-update"       # "number" type (what omarchy uses)
```

### Delete
```bash
sudo snapper -c root delete 3           # delete snapshot #3
sudo snapper -c root delete 1 2 3       # delete multiple
sudo snapper -c root delete 1-5         # delete a range
```

### Size / disk usage
```bash
sudo snapper -c root du 1 2 3 4         # space used by specific snapshots
sudo btrfs filesystem du -s /.snapshots/*/snapshot   # raw btrfs view (exclusive vs shared)
```

### Compare / diff
```bash
sudo snapper -c root status 1..2        # what changed between snapshot 1 and 2
sudo snapper -c root diff 1..2 -- /etc  # diff a specific path between snapshots
sudo snapper -c root status 0..1        # 0 = current live filesystem
```

### Cleanup (manual trigger)
```bash
sudo snapper -c root cleanup number     # run the "number" cleanup algorithm now
sudo snapper -c root cleanup timeline   # run "timeline" cleanup (n/a if TIMELINE_CREATE=no)
```

### Config
```bash
sudo snapper -c root create-config /            # create a new config for subvolume /
sudo snapper -c root get-config                 # show current config values (NUMBER_LIMIT etc.)
sudo snapper -c root set-config NUMBER_LIMIT=10 # change a config value
sudo cat /etc/snapper/configs/root              # view raw config file
```

### Rollback / restore (Omarchy-specific wrapper)
```bash
omarchy-snapshot create      # what omarchy-update calls before updating
omarchy-snapshot restore     # runs `limine-snapper-restore`
```

### Mini quick-reference (just the essentials)
```bash
snapper -c root list              # see snapshots
sudo snapper -c root create -d "x"  # take one
sudo snapper -c root delete N     # remove one
sudo snapper -c root du N         # check size of one
```



# TAR Command Cheat Sheet

### Basic info
```bash
tar --version                      # show tar version
tar -tf archive.tar                # list contents
tar -tvf archive.tar               # list contents with details
```

### Create archives
```bash
tar -cf archive.tar file1 file2 dir/          # create .tar
tar -czf archive.tar.gz dir/                  # create gzip-compressed archive
tar -cjf archive.tar.bz2 dir/                 # create bzip2-compressed archive
tar -cJf archive.tar.xz dir/                  # create xz-compressed archive
```

### Extract archives
```bash
tar -xf archive.tar                          # extract current directory
tar -xzf archive.tar.gz                      # extract .tar.gz
tar -xjf archive.tar.bz2                     # extract .tar.bz2
tar -xJf archive.tar.xz                      # extract .tar.xz
tar -xf archive.tar -C /path/to/dir          # extract to another directory
```

### List contents
```bash
tar -tf archive.tar                          # list files
tar -tvf archive.tar                         # verbose listing
tar -tf archive.tar.gz                       # list compressed archive
```

### Extract specific files
```bash
tar -xf archive.tar path/to/file             # extract one file
tar -xf archive.tar dir/                     # extract one directory
tar -xzf archive.tar.gz path/to/file         # from compressed archive
```

### Append / update (only uncompressed .tar)
```bash
tar -rf archive.tar newfile.txt              # append file
tar -uf archive.tar file.txt                 # update if newer
```

### Remove files (only uncompressed .tar)
```bash
tar --delete -f archive.tar file.txt
```

### Exclude files
```bash
tar -czf backup.tar.gz project/ --exclude='*.log'
tar -czf backup.tar.gz project/ --exclude='node_modules'
tar -czf backup.tar.gz project/ --exclude-vcs
```

### Preserve permissions
```bash
sudo tar -czpf backup.tar.gz /etc            # preserve ownership/permissions
sudo tar -xzpf backup.tar.gz                 # restore preserving ownership
```

### View without extracting
```bash
tar -xOf archive.tar file.txt                # print file to stdout
```

### Verify archive contents
```bash
tar -tf archive.tar
tar -tvf archive.tar | less
```

### Common backup examples
```bash
tar -czf home-backup.tar.gz ~/Documents
tar -czf etc-backup.tar.gz /etc
tar -czf project.tar.gz my-project/
```

### Common restore examples
```bash
tar -xzf home-backup.tar.gz
tar -xzf project.tar.gz -C ~/Projects
tar -xf archive.tar specific/file.txt
```

### Useful options
```text
-c    create archive
-x    extract archive
-t    list contents
-f    archive filename
-v    verbose output
-z    gzip (.tar.gz)
-j    bzip2 (.tar.bz2)
-J    xz (.tar.xz)
-C    extract into directory
-r    append files
-u    update newer files
-p    preserve permissions
-O    write file to stdout
--delete  remove file (only .tar)
--exclude=PATTERN  exclude files
```

### Mini quick-reference (just the essentials)
```bash
tar -czf backup.tar.gz dir/          # create compressed archive
tar -xzf backup.tar.gz               # extract
tar -tf backup.tar.gz                # list contents
tar -xf archive.tar file.txt         # extract one file
tar -xf archive.tar -C /tmp          # extract elsewhere
```



# Method : The Native AutoConfig Workaround (Advanced) (Firefox NewTab same html as the HomeTab)

If you want a truly native experience using your exact local path without any third-party extensions, you can use Firefox's **AutoConfig** feature.

## Step 1: Create the Configuration Files

You need to create two text files on your desktop:

### `autoconfig.js`

```javascript
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
```


### `firefox.cfg`

> **Make sure the first line is exactly a comment.**

```javascript
// First line must be a comment
try {
  const ff = {};
  ChromeUtils.defineESModuleGetters(ff, {
    AboutNewTab: "resource:///modules/AboutNewTab.sys.mjs"
  });
  ff.AboutNewTab.newTabURL = 'file:///home/shadow/.config/browser-default/default.html';
} catch (e) {
  ChromeUtils.reportError(e);
}
```

Replace:

```text
file:///home/shadow/.config/browser-default/default.html
```

with the actual file path to your custom HTML file.

## Step 2: Move Files to Firefox Installation Directory

Move these files into your Firefox installation directory (typically on Windows):

- Place `autoconfig.js` into the `defaults/pref` subfolder.
- Place `firefox.cfg` directly into the root Firefox folder.

Restart Firefox, and your custom HTML file will seamlessly load every time you open a new tab.
