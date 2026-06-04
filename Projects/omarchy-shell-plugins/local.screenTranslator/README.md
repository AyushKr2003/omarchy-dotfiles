# Local Screen Translator

`local.screenTranslator` is an Omarchy overlay plugin for translating visible
non-English screen text in place.

It captures the focused monitor, asks the backend for text bounding boxes and
translations, then draws only those translated regions over the live desktop.
The rest of the overlay stays transparent and the layer is input-passive, so
normal mouse and keyboard work can continue underneath it.

It is overlay-only. Enable it as a plugin and summon it with:

```bash
omarchy-shell shell summon local.screenTranslator
```

Optional target language payload:

```bash
omarchy-shell shell summon local.screenTranslator '{"targetLanguage":"hi"}'
```

Close or refresh it from your own keybinding/IPC command:

```bash
omarchy-shell shell hide local.screenTranslator
omarchy-shell shell toggle local.screenTranslator '{}'
```

## Backends

The helper script uses the first available option:

- `SCREEN_TRANSLATOR_COMMAND`, with `{image}` and `{target}` placeholders. It
  must print the JSON array format shown below.
- `GEMINI_API_KEY`, using `GEMINI_MODEL` or `gemini-2.5-flash`. This is the
  closest backend to the original `ii` behavior because it can return bounding
  boxes and translations together.
- `tesseract`, optionally piped through `trans` from translate-shell. This is a
  fallback and cannot accurately place each original paragraph, so it uses one
  coarse box.

Custom backend output:

```json
[
  {
    "x": 120,
    "y": 240,
    "width": 260,
    "height": 48,
    "text": "原文",
    "translation": "Translated text"
  }
]
```

Required for screenshots:

```bash
grim
```
