/*
 * theme-mapper.js
 *
 * Pure functions only: parsing and validating the JSON payload served
 * by omarchy-firefox-theme-server into the shape browser.theme.update()
 * expects. No fetch, no browser.theme calls, no state here -- this
 * module can be unit-tested by feeding it strings and checking output,
 * and it's the one place to touch if the server's schema changes.
 */
(function (global) {
  "use strict";

  // Keys the Firefox theme API actually understands. Anything outside
  // this set in an incoming payload is dropped rather than passed
  // through blind, so a future server bug (or a stale server sending
  // an old schema) can't feed browser.theme.update() arbitrary keys.
  const KNOWN_COLOR_KEYS = new Set([
    "frame", "frame_inactive",
    "tab_background_text", "tab_selected", "tab_text",
    "tab_line", "tab_loading",
    "icons", "icons_attention",
    "toolbar", "toolbar_text",
    "toolbar_field", "toolbar_field_text", "toolbar_field_border",
    "toolbar_field_focus", "toolbar_field_text_focus", "toolbar_field_border_focus",
    "toolbar_top_separator", "toolbar_bottom_separator", "toolbar_vertical_separator",
    "button_background_hover", "button_background_active",
    "popup", "popup_text", "popup_border",
    "popup_highlight", "popup_highlight_text",
    "sidebar", "sidebar_text", "sidebar_border",
    "ntp_background", "ntp_text",
  ]);

  // Firefox will refuse the whole theme.update() call if these core
  // keys are missing, so we require them up front and fail fast with
  // a clear reason instead of a rejected promise deep in the caller.
  const REQUIRED_KEYS = ["frame", "tab_background_text"];

  const HEX_COLOR_RE = /^#[0-9a-fA-F]{3,8}$/;

  class ThemeValidationError extends Error {}

  /**
   * @param {string} rawJson
   * @returns {{colors: Object}} a theme object safe to pass to
   *   browser.theme.update()
   * @throws {ThemeValidationError}
   */
  function parseThemePayload(rawJson) {
    let parsed;
    try {
      parsed = JSON.parse(rawJson);
    } catch (err) {
      throw new ThemeValidationError(`invalid JSON: ${err.message}`);
    }

    if (typeof parsed !== "object" || parsed === null || typeof parsed.colors !== "object" || parsed.colors === null) {
      throw new ThemeValidationError("payload missing a 'colors' object");
    }

    const colors = {};
    for (const [key, value] of Object.entries(parsed.colors)) {
      if (!KNOWN_COLOR_KEYS.has(key)) continue; // silently ignore unknown keys
      if (typeof value !== "string" || !HEX_COLOR_RE.test(value)) {
        // Skip just this one bad key rather than rejecting the whole
        // theme -- a single malformed value in a large payload
        // shouldn't blank out an otherwise-good theme.
        continue;
      }
      colors[key] = value;
    }

    for (const required of REQUIRED_KEYS) {
      if (!(required in colors)) {
        throw new ThemeValidationError(`missing or invalid required color '${required}'`);
      }
    }

    return { colors };
  }

  /**
   * Cheap structural fingerprint so callers can avoid redundant
   * browser.theme.update() calls when the mapped output didn't
   * actually change (e.g. server sent the same theme twice).
   */
  function fingerprint(themeObject) {
    return JSON.stringify(themeObject.colors, Object.keys(themeObject.colors).sort());
  }

  global.OmarchyThemeMapper = { parseThemePayload, fingerprint, ThemeValidationError };
})(this);
