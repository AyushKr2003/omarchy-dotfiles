# Local Weather Omarchy Plugin

Third-party copy of Omarchy's weather widget with one extra inline setting:
`location`.

Install it at:

```text
~/.config/omarchy/plugins/local.weather/
```

Then run:

```bash
omarchy plugin rescan
omarchy plugin enable local.weather
omarchy plugin bar add local.weather
```

Example `~/.config/omarchy/shell.json` bar entry:

```json
{
  "id": "local.weather",
  "location": "London",
  "unit": "metric",
  "refreshMinutes": 15
}
```

When `location` is empty, the widget keeps the original wttr.in auto-location
behavior and requests:

```text
https://wttr.in/?format=j1
```

When `location` is set, it requests:

```text
https://wttr.in/<location>?format=j1
```
