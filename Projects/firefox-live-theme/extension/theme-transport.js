/*
 * theme-transport.js
 *
 * Talks to omarchy-firefox-theme-server over HTTP long-poll. Exposes a
 * small, transport-agnostic interface:
 *
 *   const transport = OmarchyThemeTransport.create({
 *     onPayload(rawJson) { ... },   // called with a raw JSON string
 *     onStatus(status) { ... },     // "connected" | "retrying" | "stopped"
 *   });
 *   transport.start();
 *   transport.stop();
 *
 * If this ever needs to become a WebSocket, a native-messaging port,
 * or something else, only this file changes -- background.js only
 * knows about start()/stop()/onPayload/onStatus.
 */
(function (global) {
  "use strict";

  const PORTS = [47732, 47733, 47734, 47735];
  const REQUEST_TIMEOUT_MS = 30000; // a little above the server's 25s long-poll cap
  const MIN_BACKOFF_MS = 1000;
  const MAX_BACKOFF_MS = 30000;
  const HEALTHY_RETRY_RESET_MS = 60000; // sustained success clears backoff history

  function create({ onPayload, onStatus }) {
    let stopped = true;
    let activePort = null;
    let backoffMs = MIN_BACKOFF_MS;
    let retryTimer = null;
    let abortController = null;
    let lastEtag = "";

    function emitStatus(status, detail) {
      try {
        onStatus && onStatus(status, detail);
      } catch (err) {
        console.error("[omarchy-live-theme] onStatus handler threw", err);
      }
    }

    async function findServer() {
      // Ports are tried round-robin rather than always starting from
      // the first candidate, so a server that's on the second port
      // (because the first was busy at startup) is found quickly
      // instead of re-probing a dead port every cycle.
      const ordered = activePort
        ? [activePort, ...PORTS.filter((p) => p !== activePort)]
        : PORTS;

      for (const port of ordered) {
        try {
          const res = await fetchWithTimeout(
            `http://127.0.0.1:${port}/health`,
            2000
          );
          if (res.ok) return port;
        } catch (_err) {
          // try next candidate
        }
      }
      return null;
    }

    function fetchWithTimeout(url, timeoutMs) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      return fetch(url, { signal: controller.signal, cache: "no-store" }).finally(() =>
        clearTimeout(timer)
      );
    }

    async function pollOnce(port) {
      abortController = new AbortController();
      const timer = setTimeout(() => abortController.abort(), REQUEST_TIMEOUT_MS);
      try {
        const url = `http://127.0.0.1:${port}/theme/wait?since=${encodeURIComponent(lastEtag)}`;
        const res = await fetch(url, { signal: abortController.signal, cache: "no-store" });
        if (!res.ok) throw new Error(`unexpected status ${res.status}`);

        const changed = res.headers.get("X-Theme-Changed") === "true";
        const etag = res.headers.get("ETag") || "";
        const body = await res.text();

        if (changed && etag !== lastEtag) {
          lastEtag = etag;
          onPayload(body);
        }
        return true;
      } finally {
        clearTimeout(timer);
      }
    }

    function scheduleRetry(reason) {
      emitStatus("retrying", reason);
      retryTimer = setTimeout(() => {
        if (!stopped) loop();
      }, backoffMs);
      backoffMs = Math.min(backoffMs * 2, MAX_BACKOFF_MS);
    }

    let lastSuccessAt = 0;

    async function loop() {
      if (stopped) return;

      if (!activePort) {
        activePort = await findServer();
        if (stopped) return;
        if (!activePort) {
          scheduleRetry("no server found on any candidate port");
          return;
        }
      }

      try {
        await pollOnce(activePort);
        if (stopped) return;

        const now = Date.now();
        if (now - lastSuccessAt > HEALTHY_RETRY_RESET_MS) {
          backoffMs = MIN_BACKOFF_MS; // sustained health: forget past failures
        }
        lastSuccessAt = now;
        emitStatus("connected");
        // Immediately re-poll; the server's own long-poll timeout is
        // what paces this loop, so no extra delay is added here.
        loop();
      } catch (err) {
        if (stopped) return;
        activePort = null; // re-probe in case the server moved ports or restarted
        scheduleRetry(err && err.message ? err.message : String(err));
      }
    }

    return {
      start() {
        if (!stopped) return;
        stopped = false;
        backoffMs = MIN_BACKOFF_MS;
        loop();
      },
      stop() {
        stopped = true;
        if (retryTimer) clearTimeout(retryTimer);
        if (abortController) abortController.abort();
        emitStatus("stopped");
      },
    };
  }

  global.OmarchyThemeTransport = { create };
})(this);
