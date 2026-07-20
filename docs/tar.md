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

