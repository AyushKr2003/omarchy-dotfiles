/*
 * background.js
 *
 * The only file that touches browser.theme.* directly. Depends on
 * theme-mapper.js (validation/parsing) and theme-transport.js
 * (networking) but knows nothing about their internals -- swap either
 * one out independently without touching this file, as long as the
 * small interfaces documented in each file are preserved.
 */
(function () {
  "use strict";

  const { parseThemePayload, fingerprint, ThemeValidationError } = OmarchyThemeMapper;

  let lastAppliedFingerprint = null;
  let applyInFlight = Promise.resolve();

  function setBadge(text, color) {
    // Best-effort UI signal for "is this thing actually working" --
    // deliberately not a full popup UI, so this stays lightweight, but
    // it means a disconnected server is visible without opening
    // about:debugging.
    try {
      if (browser.browserAction && browser.browserAction.setBadgeText) {
        browser.browserAction.setBadgeText({ text });
        if (color) browser.browserAction.setBadgeBackgroundColor({ color });
      }
    } catch (_err) {
      // browserAction may be absent if this extension ships without a
      // toolbar button; badge is a nicety, not a requirement.
    }
  }

  function applyPayload(rawJson) {
    // Serialize applications: browser.theme.update() calls racing each
    // other (e.g. a fast retry right after a slow one resolves) could
    // otherwise apply an older theme after a newer one.
    applyInFlight = applyInFlight.then(async () => {
      let theme;
      try {
        theme = parseThemePayload(rawJson);
      } catch (err) {
        if (err instanceof ThemeValidationError) {
          console.warn("[omarchy-live-theme] rejecting invalid theme payload:", err.message);
          setBadge("!", "#c0392b");
          return;
        }
        throw err;
      }

      const fp = fingerprint(theme);
      if (fp === lastAppliedFingerprint) {
        console.debug("[omarchy-live-theme] payload received, but colors are unchanged from last applied -- skipping");
        return;
      }

      try {
        await browser.theme.update(theme);
        lastAppliedFingerprint = fp;
        setBadge("", null);
        console.log("[omarchy-live-theme] theme applied:", theme.colors.frame);
      } catch (err) {
        console.error("[omarchy-live-theme] browser.theme.update() rejected:", err);
        setBadge("!", "#c0392b");
      }
    });
    return applyInFlight;
  }

  function onStatus(status, detail) {
    switch (status) {
      case "connected":
        setBadge("", null);
        console.debug("[omarchy-live-theme] connected to theme server");
        break;
      case "retrying":
        console.debug("[omarchy-live-theme] retrying:", detail);
        setBadge("\u22EF", "#7f8c8d"); // subtle "..." while reconnecting
        break;
      case "stopped":
        setBadge("", null);
        break;
    }
  }

  const transport = OmarchyThemeTransport.create({
    onPayload: applyPayload,
    onStatus,
  });

  // Apply immediately on both install and every browser startup rather
  // than waiting for the first server push -- otherwise a freshly
  // installed or freshly launched Firefox shows Firefox's own default
  // theme until the transport happens to reconnect.
  browser.runtime.onInstalled.addListener(() => transport.start());
  browser.runtime.onStartup.addListener(() => transport.start());

  // Fallback in case neither lifecycle event fires in some embedding
  // context (defensive; harmless if it's already running).
  transport.start();
})();
