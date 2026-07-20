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
