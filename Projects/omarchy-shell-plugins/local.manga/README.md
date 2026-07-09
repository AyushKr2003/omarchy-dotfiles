# Local Manga

`local.manga` is an Omarchy panel plugin that opens a detached manga browser,
library, reader, favorites, and download window backed by a small local Python
server.

The backend scrapes WeebCentral and stores plugin data in:

```text
~/.local/share/omarchy-manga/
```

Install or copy the plugin to Omarchy's plugin directory, then rescan and
enable it:

```bash
omarchy plugin rescan
omarchy plugin enable local.manga
```

Open or toggle it with shell IPC:

```bash
omarchy-shell shell toggle local.manga '{}'
```

The backend uses Python 3. If `curl_cffi` is installed it will use browser-grade
TLS impersonation; otherwise it falls back to `requests`.
