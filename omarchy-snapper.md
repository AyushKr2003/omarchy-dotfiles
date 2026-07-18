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

<!-- 
to compress a file command 
```
‘tar -czf icon_pack.tar.gz -C .local/share/icons . 
```
-->

