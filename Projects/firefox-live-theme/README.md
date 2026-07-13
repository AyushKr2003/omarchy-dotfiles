# firefox-live-theme

Live-updates Firefox's colors to match your current [Omarchy](https://github.com/basecamp/omarchy)
theme, the same way Omarchy already does for Chrome/Edge/Brave -- but as
a personal, standalone project rather than a fork or PR against Omarchy
itself. Nothing in Omarchy's own git tree or install is touched; this
only uses Omarchy's own supported per-user template override directory
(`~/.config/omarchy/themed/`).

## Why this exists

Omarchy's Chromium-family theming works by writing an enterprise policy
file and telling the browser to `--refresh-platform-policy`. Firefox has
no equivalent "refresh now" mechanism, so this project takes a different
route:

1. Omarchy already renders a small `firefox-theme.json` for every theme,
   via a template dropped into its user-template directory (this
   project owns that one file: `templates/firefox-theme.json.tpl`).
2. A tiny local server (`bin/theme-server`) watches that file and serves
   it over a loopback-only long-poll HTTP endpoint.
3. A small Firefox WebExtension polls that endpoint and calls the
   standard `browser.theme.update()` API whenever it changes.

Nothing here needs native messaging, `userChrome.css` hacks, or any
unsupported/internal Firefox API -- everything is a normal, documented
WebExtension capability. See each file's header comment for the design
reasoning and edge cases handled (partial writes, server restarts, port
conflicts, malformed payloads, etc.).

## Install

```sh
git clone <this-repo> firefox-live-theme
cd firefox-live-theme
./install.sh
```

This is safe to re-run any time (e.g. after pulling an update) --
nothing it does will clobber a template you've customized yourself, and
every step degrades gracefully if e.g. systemd isn't reachable in your
current session.

What it does:
- Copies `bin/theme-server` and the extension source to
  `~/.local/share/firefox-live-theme/`
- Copies `templates/firefox-theme.json.tpl` to
  `~/.config/omarchy/themed/` (skips this if you already have a
  different file there -- see the warning it prints if so)
- Installs and starts a `systemd --user` unit
- Re-runs `omarchy-theme-set` on your current theme, so the new
  template applies immediately instead of waiting for your next theme
  switch

## The one manual step: signing the extension

Firefox requires every extension -- themes included, since 2019 -- to be
signed by Mozilla before it'll load, even for a purely personal,
single-machine install. There's no config flag or enterprise policy
that bypasses this on regular Firefox or Zen. This is a one-time step:

```sh
cd extension
npx web-ext sign \
  --api-key=$AMO_JWT_ISSUER \
  --api-secret=$AMO_JWT_SECRET \
  --channel=unlisted
```

(Get a free API key/secret at https://addons.mozilla.org/developers/addon/api/key/ --
`--channel=unlisted` means it's signed for self-distribution, not
published or reviewed publicly.)

Note: AMO's automated validator rejects any add-on name containing the
"Firefox" or "Mozilla" trademarks -- `manifest.json`'s `name` field here
is already trademark-safe ("Omarchy Live Theme"). If you rename it
yourself, keep those words out of it or signing will fail with a 400
and a `"cannot contain the Mozilla or Firefox trademarks"` error.

Drop the resulting file at `extension/firefox-live-theme.xpi`, then
install it the normal way any extension gets installed:

```sh
firefox extension/firefox-live-theme.xpi
```

Click "Add" when Firefox prompts. That's the whole step -- nothing else
in Firefox's config is touched, and you only need to re-do this when
the extension's own code changes, not per-theme.

## Uninstall

```sh
./uninstall.sh
```

Removes everything install.sh added, in reverse. Leaves your theme
template alone if you've customized it. Doesn't touch the extension
inside Firefox itself -- remove that from `about:addons` if you
installed it.

## Debugging

```sh
systemctl --user status firefox-live-theme.service
curl -s http://127.0.0.1:47732/health | python3 -m json.tool
curl -s http://127.0.0.1:47732/theme  | python3 -m json.tool
journalctl --user -u firefox-live-theme -f
```

In Firefox: `about:debugging#/runtime/this-firefox` -> find
"Omarchy Live Theme" -> **Inspect** for the background
script's console output (connection status, rejected payloads, etc.).

## Project layout

| Path | What it is |
|---|---|
| `templates/firefox-theme.json.tpl` | Maps `colors.toml` keys to Firefox's `theme.colors` schema |
| `bin/theme-server` | Watches the rendered file, serves it over long-poll |
| `systemd/firefox-live-theme.service.tpl` | Service unit template (install.sh fills in the real path) |
| `extension/theme-mapper.js` | Pure validation of incoming payloads -- no networking, no browser API calls |
| `extension/theme-transport.js` | Long-poll client with backoff -- the only file that knows the server's HTTP shape |
| `extension/background.js` | Wires the two above together, the only file that calls `browser.theme.update()` |

Each piece talks to its neighbor through a small interface documented in
that file's header, so any one of them can be swapped or rewritten
without the others needing to change.

## Known limitation

Updates land within a couple of seconds via long-poll, not instantly the
way Chromium's `--refresh-platform-policy` works -- there's no Firefox
equivalent of that flag. In practice this means the toolbar recolors
just after a theme switch rather than in the same frame.
