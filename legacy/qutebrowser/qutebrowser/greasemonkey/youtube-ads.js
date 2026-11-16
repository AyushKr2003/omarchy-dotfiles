// ==UserScript==
// @name         Omarchy — Skip YouTube Ads
// @description  Auto-clicks skip buttons and fast-forwards unskippable ads.
//               Works alongside the network-level blocking in config.py.
//               For ads that slip through the filter lists, this is the fallback.
// @version      2.0
// @author       omarchy
// @run-at       document-start
// @match        https://www.youtube.com/*
// @match        https://youtube.com/*
// @noframes
// ==/UserScript==

(function () {
  'use strict';

  // How often to check for ad elements (ms)
  const INTERVAL = 300;

  function skipAds() {
    const video = document.querySelector('video');

    // ── 1. Click any visible skip button ─────────────────────────────────────
    const skipSelectors = [
      '.ytp-ad-skip-button',
      '.ytp-ad-skip-button-modern',
      '.ytp-skip-ad-button',
      '[class*="skip-ad"]',
      '[id*="skip-button"]',
    ];
    for (const sel of skipSelectors) {
      const btn = document.querySelector(sel);
      if (btn) {
        btn.click();
        return;
      }
    }

    // ── 2. Fast-forward unskippable ads ──────────────────────────────────────
    // If the ad-showing class is present, the video element is playing an ad.
    const adShowing = document.querySelector('.ad-showing');
    if (adShowing && video) {
      // Setting duration to a very high value triggers the "ad ended" path.
      if (!video.paused && video.duration && isFinite(video.duration)) {
        video.currentTime = video.duration;
      }
      // Mute the ad while it plays (in case currentTime jump doesn't work)
      video.muted = true;
      video.playbackRate = 16;
      return;
    }

    // Restore normal playback once ad is gone
    if (video && video.playbackRate !== 1) {
      video.playbackRate = 1;
      video.muted = false;
    }

    // ── 3. Dismiss overlay / banner ads ──────────────────────────────────────
    const overlayClose = document.querySelector(
      '.ytp-ad-overlay-close-button, .ytp-ad-text-overlay-close-button'
    );
    if (overlayClose) overlayClose.click();

    // ── 4. Click "I understand" / confirm dialogs injected by YT ─────────────
    const confirmBtn = document.querySelector(
      '.yt-confirm-dialog-renderer button:last-child'
    );
    if (confirmBtn && document.querySelector('.yt-confirm-dialog-renderer')) {
      confirmBtn.click();
    }
  }

  // Run on a timer — MutationObserver alone misses timing-sensitive skips
  setInterval(skipAds, INTERVAL);

  // Also run immediately on each navigation (YouTube is a SPA)
  document.addEventListener('yt-navigate-finish', skipAds);
})();
