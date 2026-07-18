// Omarchy browser homepage
// No dependencies, no analytics, no network calls other than the
// search form submission itself. Everything here is local to the
// machine (localStorage), never sent anywhere.

(function () {
  "use strict";

  const NAME_KEY = "omarchy-homepage-name";
  const ENGINE_KEY = "omarchy-homepage-engine";

  const ENGINES = [
    { name: "DuckDuckGo", action: "https://duckduckgo.com/", param: "q" },
    { name: "Google", action: "https://www.google.com/search", param: "q" },
    { name: "Kagi", action: "https://kagi.com/search", param: "q" },
    { name: "Startpage", action: "https://www.startpage.com/sp/search", param: "query" },
  ];

  // ---- clock ---------------------------------------------------------

  function pad(n) {
    return String(n).padStart(2, "0");
  }

  function updateClock() {
    const el = document.getElementById("clock");
    if (!el) return;
    const now = new Date();
    el.textContent = `${pad(now.getHours())}:${pad(now.getMinutes())}`;
  }

  function updateDate() {
    const el = document.getElementById("date");
    if (!el) return;
    const now = new Date();
    el.textContent = now.toLocaleDateString(undefined, {
      weekday: "long",
      month: "long",
      day: "numeric",
    });
  }

  // Align the clock's own tick to the start of the next minute, rather
  // than a naive setInterval(1000) that would otherwise drift and
  // occasionally double-render the same minute.
  function scheduleClock() {
    updateClock();
    updateDate();
    const now = new Date();
    const msToNextMinute = 60000 - (now.getSeconds() * 1000 + now.getMilliseconds());
    setTimeout(function tick() {
      updateClock();
      updateDate();
      setTimeout(tick, 60000);
    }, msToNextMinute);
  }

  // ---- greeting, with an optional click-to-set name -------------------
  // No default fake name -- an empty personal homepage shouldn't
  // pretend to know you. Click the greeting once to set it; stored
  // only in this browser's localStorage, never transmitted anywhere.

  function timeOfDayGreeting() {
    const hour = new Date().getHours();
    if (hour < 5) return "Good night";
    if (hour < 12) return "Good morning";
    if (hour < 18) return "Good afternoon";
    return "Good evening";
  }

  function renderGreeting() {
    const el = document.getElementById("greeting");
    if (!el) return;
    const name = localStorage.getItem(NAME_KEY);
    el.textContent = name ? `${timeOfDayGreeting()}, ${name}` : timeOfDayGreeting();
  }

  function initGreeting() {
    renderGreeting();
    const el = document.getElementById("greeting");
    if (!el) return;
    el.style.cursor = "pointer";
    el.title = "Click to set your name";
    el.addEventListener("click", function () {
      const current = localStorage.getItem(NAME_KEY) || "";
      const next = window.prompt("What should the homepage call you? (leave blank to remove)", current);
      if (next === null) return;
      const trimmed = next.trim();
      if (trimmed) {
        localStorage.setItem(NAME_KEY, trimmed);
      } else {
        localStorage.removeItem(NAME_KEY);
      }
      renderGreeting();
    });
  }

  // ---- search engine switcher ------------------------------------------

  function currentEngineIndex() {
    const saved = localStorage.getItem(ENGINE_KEY);
    const idx = ENGINES.findIndex((e) => e.name === saved);
    return idx === -1 ? 0 : idx;
  }

  function applyEngine(index) {
    const engine = ENGINES[index];
    const form = document.getElementById("search-form");
    const input = document.getElementById("search-input");
    const toggle = document.getElementById("engine-toggle");
    if (!form || !input || !toggle) return;

    form.action = engine.action;
    input.name = engine.param;
    toggle.textContent = engine.name;
    localStorage.setItem(ENGINE_KEY, engine.name);
  }

  function initEngineToggle() {
    let index = currentEngineIndex();
    applyEngine(index);

    const toggle = document.getElementById("engine-toggle");
    if (!toggle) return;
    toggle.addEventListener("click", function () {
      index = (index + 1) % ENGINES.length;
      applyEngine(index);
      document.getElementById("search-input").focus();
    });
  }

  // ---- quicklinks / website pins --------------------------------------
  const QUICKLINKS_KEY = "omarchy-homepage-quicklinks";

  const DEFAULT_QUICKLINKS = [
    {
      id: "youtube",
      name: "YouTube",
      url: "https://www.youtube.com",
      svg: `<svg viewBox="0 0 32 32"><path d="M31.3 9.3c-.4-1.5-1.6-2.7-3-3C25.8 5.7 16 5.7 16 5.7s-9.8 0-12.3.6c-1.5.3-2.7 1.5-3 3C.1 11.8 0 16 0 16s.1 4.2.7 6.7c.4 1.5 1.6 2.7 3 3 2.5.6 12.3.6 12.3.6s9.8 0 12.3-.6c1.5-.3 2.7-1.5 3-3 .6-2.5.7-6.7.7-6.7s0-4.2-.7-6.7zM12.8 20.8V11.2L21.2 16l-8.4 4.8z" fill="currentColor"/></svg>`
    },
    {
      id: "github",
      name: "GitHub",
      url: "https://github.com/basecamp/omarchy",
      svg: `<svg viewBox="0 0 32 32"><path d="m16 0c8.84 0 16 7.16 16 16-.0009 3.3524-1.053 6.6201-3.0083 9.3432-1.9553 2.7232-4.7154 4.7645-7.8917 5.8368-.8.16-1.1-.34-1.1-.76 0-.54.02-2.26.02-4.4 0-1.5-.5-2.46-1.08-2.96 3.56-.4 7.3-1.76 7.3-7.9 0-1.76-.62-3.18-1.64-4.3.16-.4.72-2.04-.16-4.24 0 0-1.34-.44-4.4 1.64-1.28-.36-2.64-.54-4-.54s-2.72.18-4 .54c-3.06-2.06-4.4-1.64-4.4-1.64-.88 2.2-.32 3.84-.16 4.24-1.02 1.12-1.64 2.56-1.64 4.3 0 6.12 3.72 7.5 7.28 7.9-.46.4-.88 1.1-1.02 2.14-.92.42-3.22 1.1-4.66-1.32-.3-.48-1.2-1.66-2.46-1.64-1.34.02-.54.76.02 1.06.68.38 1.46 1.8 1.64 2.26.32.9 1.36 2.62 5.38 1.88 0 1.34.02 2.6.02 2.98 0 .42-.3.9-1.1.76-3.18672-1.0607-5.95853-3.098-7.92222-5.8227-1.96369-2.7248-3.01954096-5.9987-3.0177778-9.3573 0-8.84 7.1599978-16 15.9999978-16z" fill="currentColor"/></svg>`
    },
    {
      id: "iso",
      name: "ISO",
      url: "https://iso.omarchy.org",
      svg: `<svg viewBox="0 0 32 32"><path d="m9.47363 4.01687c.77167.00015 1.39727.62585 1.39747 1.39747 0 .7718-.6257 1.39829-1.39747 1.39843h-4.625c-.66518.00006-1.17367.17068-1.52539.5127-.34225.34225-.51364.86071-.51367 1.55469v14.24194c0 .694.17139 1.2124.51367 1.5547.35173.3517.86001.5282 1.52539.5283h22.28807c.6561 0 1.1599-.1766 1.5117-.5283.3613-.3423.542-.8607.542-1.5547v-14.24194c0-.69398-.1807-1.21244-.542-1.55469-.3517-.34214-.8558-.5127-1.5117-.5127h-4.624c-.7719 0-1.3984-.62654-1.3984-1.39843.0002-.77171.6266-1.39747 1.3984-1.39747h4.8096c1.5402.00002 2.705.3903 3.4941 1.16993.789.77963 1.1836 1.93518 1.1836 3.46582v14.71258c0 1.5305-.3947 2.6853-1.1836 3.4649-.7891.7796-1.9539 1.1699-3.4941 1.1699h-22.64457c-1.54021 0-2.70501-.3903-3.49414-1.1699-.788897-.7796-1.18354196-1.9344-1.18359-3.4649v-14.71258c0-1.53064.394563-2.68619 1.18359-3.46582.78913-.77963 1.95393-1.16991 3.49414-1.16993z"/><path d="m16.0078 0c.3832.00005683.7111.136008.9834.408203.2825.27241.4238.590889.4238.954097v14.2481l-.1211 2.2548.8018-.9687 2.1494-2.2998c.2522-.2825.5652-.4238.9385-.4238.3429 0 .6358.1156.8779.3476.2522.2321.378.5203.378.8633-.0001.3328-.1314.6359-.3936.9082l-4.9785 4.7969c-.1816.1715-.3588.2926-.5303.3632-.1714.0706-.3478.1065-.5293.1065-.1816 0-.3587-.0358-.5303-.1065-.1714-.0706-.3533-.1918-.5449-.3632l-4.96385-4.7969c-.27233-.2723-.40812-.5754-.4082-.9082 0-.343.12114-.6312.36328-.8633.24207-.2319.53497-.3476.87797-.3476.3933 0 .711.1413.9531.4238l2.164 2.2998.8028.9687-.1211-2.2548v-14.2481c0-.363208.1358-.681687.4082-.954097.2824-.27226.6157-.408203.999-.408203z" fill="currentColor"/></svg>`
    },
    {
      id: "discord",
      name: "Discord",
      url: "https://discord.gg/tXFUdasqhY",
      svg: `<svg viewBox="0 0 32 32"><path d="m20.5047 3.87149c-.3126.55521-.5935 1.12957-.8487 1.71668-2.4251-.36375-4.8948-.36375-7.3263 0-.2488-.58711-.536-1.16147-.8488-1.71668-2.2782.38929-4.4991 1.07213-6.60504 2.03577-4.173678 6.18384-5.30323 12.20824-4.741638 18.14964 2.444238 1.8061 5.181988 3.1846 8.098458 4.0652.65728-.8806 1.23806-1.8188 1.73585-2.7952-.94455-.351-1.85714-.7913-2.73143-1.3018.22975-.166.45309-.3383.6701-.5042 5.1246 2.4122 11.0595 2.4122 16.1904 0 .217.1787.4404.351.6701.5042-.8743.5168-1.7869.9508-2.7377 1.3082.4978.9764 1.0785 1.9145 1.7358 2.7952 2.9165-.8807 5.6542-2.2528 8.0985-4.0588.6637-6.8923-1.136-12.8656-4.7545-18.15603-2.0995-.96366-4.3204-1.64651-6.5987-2.02942zm-9.8215 16.52871c-1.57623 0-2.88455-1.4295-2.88455-3.1972 0-1.7678 1.25721-3.2037 2.87815-3.2037 1.621 0 2.9101 1.4423 2.8846 3.2037-.0255 1.7613-1.2699 3.1972-2.8782 3.1972zm10.6321 0c-1.5827 0-2.8782-1.4295-2.8782-3.1972 0-1.7678 1.2572-3.2037 2.8782-3.2037 1.6208 0 2.9036 1.4423 2.878 3.2037-.0254 1.7613-1.2699 3.1972-2.878 3.1972z" fill="currentColor"/></svg>`
    }
  ];

  function getDomain(url) {
    try {
      let cleanUrl = url.trim();
      if (!/^https?:\/\//i.test(cleanUrl)) {
        cleanUrl = "https://" + cleanUrl;
      }
      return new URL(cleanUrl).hostname;
    } catch (e) {
      return "";
    }
  }

  function loadQuicklinks() {
    const data = localStorage.getItem(QUICKLINKS_KEY);
    if (!data) {
      localStorage.setItem(QUICKLINKS_KEY, JSON.stringify(DEFAULT_QUICKLINKS));
      return DEFAULT_QUICKLINKS;
    }
    try {
      return JSON.parse(data);
    } catch (e) {
      return DEFAULT_QUICKLINKS;
    }
  }

  function saveQuicklinks(links) {
    localStorage.setItem(QUICKLINKS_KEY, JSON.stringify(links));
  }

  function renderQuicklinks() {
    const container = document.getElementById("quicklinks");
    if (!container) return;

    const links = loadQuicklinks();

    // Clear container
    container.innerHTML = "";

    links.forEach((link) => {
      const a = document.createElement("a");
      a.href = link.url;
      a.className = "quicklink-item";
      a.setAttribute("aria-label", link.name);

      if (link.svg) {
        a.innerHTML = link.svg;
      } else {
        const domain = getDomain(link.url);
        const img = document.createElement("img");
        img.className = "quicklink-icon";
        img.src = `https://www.google.com/s2/favicons?sz=64&domain=${domain}`;
        img.alt = "";
        
        img.onerror = function() {
          img.style.display = "none";
          const fallback = document.createElement("span");
          fallback.style.marginRight = "4px";
          fallback.style.color = "var(--accent)";
          fallback.textContent = "•";
          a.insertBefore(fallback, a.firstChild);
        };
        a.appendChild(img);
      }

      const label = document.createElement("span");
      label.textContent = link.name;
      a.appendChild(label);

      // Create Delete Button
      const delBtn = document.createElement("button");
      delBtn.type = "button";
      delBtn.className = "quicklink-delete-btn";
      delBtn.setAttribute("aria-label", `Delete ${link.name}`);
      delBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>`;
      
      delBtn.addEventListener("click", function (e) {
        e.preventDefault();
        e.stopPropagation();
        deleteQuicklink(link.id);
      });

      a.appendChild(delBtn);
      container.appendChild(a);
    });

    // Append Add Button
    const addBtn = document.createElement("button");
    addBtn.type = "button";
    addBtn.className = "quicklink-add";
    addBtn.id = "quicklink-add-btn";
    addBtn.setAttribute("aria-label", "Add website pin");
    addBtn.innerHTML = `<svg viewBox="0 0 32 32"><path d="M15 5h2v10h10v2H17v10h-2V17H5v-2h10V5z" fill="currentColor"/></svg><span>Add Pin</span>`;
    
    container.appendChild(addBtn);
    
    // Wire up events for the freshly created Add button
    initQuicklinkModalEvents(addBtn);
  }

  function deleteQuicklink(id) {
    const links = loadQuicklinks();
    const filtered = links.filter((link) => link.id !== id);
    saveQuicklinks(filtered);
    renderQuicklinks();
  }

  let modalEventsWired = false;

  function initQuicklinkModalEvents(addBtn) {
    const modal = document.getElementById("add-pin-modal");
    const closeBtn = document.getElementById("close-modal-btn");
    const cancelBtn = document.getElementById("cancel-modal-btn");
    const backdrop = document.getElementById("modal-backdrop");
    const form = document.getElementById("add-pin-form");
    const urlInput = document.getElementById("pin-url");
    const nameInput = document.getElementById("pin-name");

    if (!modal || !addBtn || !form) return;

    let isNameManuallyEdited = false;

    function openModal() {
      modal.classList.add("active");
      modal.setAttribute("aria-hidden", "false");
      urlInput.focus();
      isNameManuallyEdited = false;
    }

    function closeModal() {
      modal.classList.remove("active");
      modal.setAttribute("aria-hidden", "true");
      form.reset();
      isNameManuallyEdited = false;
    }

    // Always attach event to new addBtn since container is rerendered
    addBtn.addEventListener("click", openModal);

    // Only wire modal elements once
    if (modalEventsWired) return;
    modalEventsWired = true;

    closeBtn.addEventListener("click", closeModal);
    cancelBtn.addEventListener("click", closeModal);
    backdrop.addEventListener("click", closeModal);

    // Escape key closes modal
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && modal.classList.contains("active")) {
        closeModal();
      }
    });

    // Auto-fill name based on domain

    urlInput.addEventListener("input", function () {
      if (!isNameManuallyEdited) {
        const domain = getDomain(urlInput.value);
        if (domain) {
          const parts = domain.split(".");
          let name = parts[0];
          if (name === "www" && parts.length > 1) {
            name = parts[1];
          }
          if (name) {
            nameInput.value = name.charAt(0).toUpperCase() + name.slice(1);
          }
        }
      }
    });

    nameInput.addEventListener("input", function () {
      if (nameInput.value.trim() === "") {
        isNameManuallyEdited = false;
      } else {
        isNameManuallyEdited = true;
      }
    });

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      let url = urlInput.value.trim();
      const name = nameInput.value.trim();

      if (!url || !name) return;

      // Automatically prepend protocol if missing
      if (!/^https?:\/\//i.test(url)) {
        url = "https://" + url;
      }

      const links = loadQuicklinks();
      const newPin = {
        id: "pin-" + Date.now(),
        name: name,
        url: url
      };

      links.push(newPin);
      saveQuicklinks(links);
      renderQuicklinks();
      closeModal();
    });
  }

  function focusSearchInput() {
    const searchInput = document.getElementById("search-input");
    if (!searchInput) return;

    const grabFocus = () => {
      if (document.activeElement !== searchInput) {
        searchInput.focus();
      }
    };

    // Multi-stage grab to beat browser rendering/transition delays
    grabFocus();
    setTimeout(grabFocus, 30);
    setTimeout(grabFocus, 100);
    setTimeout(grabFocus, 250);
    setTimeout(grabFocus, 500);
    setTimeout(grabFocus, 1000);
  }

  // ---- search suggestions autocomplete --------------------------------
  let currentJsonpScript = null;

  function fetchSuggestions(query, callback) {
    if (currentJsonpScript) {
      try {
        document.body.removeChild(currentJsonpScript);
      } catch (e) {}
      currentJsonpScript = null;
    }

    const trimmed = query.trim();
    if (!trimmed) {
      callback([]);
      return;
    }

    const callbackName = "googleSuggestCallback_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

    window[callbackName] = function (data) {
      if (data && data[1]) {
        callback(data[1]);
      } else {
        callback([]);
      }
      delete window[callbackName];
      if (currentJsonpScript && currentJsonpScript.parentNode) {
        currentJsonpScript.parentNode.removeChild(currentJsonpScript);
        currentJsonpScript = null;
      }
    };

    const script = document.createElement("script");
    script.src = `https://suggestqueries.google.com/complete/search?client=firefox&q=${encodeURIComponent(trimmed)}&callback=${callbackName}`;
    currentJsonpScript = script;
    document.body.appendChild(script);
  }

  function initSearchSuggestions() {
    const input = document.getElementById("search-input");
    const container = document.getElementById("search-suggestions");
    const form = document.getElementById("search-form");
    if (!input || !container || !form) return;

    let debounceTimeout = null;
    let selectedIndex = -1;
    let suggestionsList = [];
    let originalInputValue = "";

    function renderSuggestions(suggestions) {
      suggestionsList = suggestions;
      container.innerHTML = "";
      selectedIndex = -1;

      if (suggestions.length === 0) {
        container.classList.remove("active");
        return;
      }

      suggestions.forEach((suggestion, index) => {
        const li = document.createElement("li");
        li.className = "suggestion-item";
        li.setAttribute("role", "option");
        li.setAttribute("id", `suggestion-${index}`);

        const searchIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>`;
        li.innerHTML = `${searchIcon}<span>${suggestion}</span>`;

        li.addEventListener("click", () => {
          input.value = suggestion;
          form.submit();
        });

        container.appendChild(li);
      });

      container.classList.add("active");
    }

    function updateSelection() {
      const items = container.querySelectorAll(".suggestion-item");
      items.forEach((item, index) => {
        if (index === selectedIndex) {
          item.classList.add("selected");
          input.value = suggestionsList[index];
        } else {
          item.classList.remove("selected");
        }
      });

      if (selectedIndex === -1) {
        input.value = originalInputValue;
      }
    }

    input.addEventListener("input", () => {
      clearTimeout(debounceTimeout);
      const query = input.value;
      originalInputValue = query;
      if (!query.trim()) {
        container.classList.remove("active");
        container.innerHTML = "";
        return;
      }

      debounceTimeout = setTimeout(() => {
        fetchSuggestions(query, renderSuggestions);
      }, 150);
    });

    input.addEventListener("keydown", (e) => {
      const items = container.querySelectorAll(".suggestion-item");
      if (items.length === 0) return;

      if (e.key === "ArrowDown") {
        e.preventDefault();
        selectedIndex = selectedIndex + 1;
        if (selectedIndex >= items.length) {
          selectedIndex = -1;
        }
        updateSelection();
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        selectedIndex = selectedIndex - 1;
        if (selectedIndex < -1) {
          selectedIndex = items.length - 1;
        }
        updateSelection();
      } else if (e.key === "Escape") {
        container.classList.remove("active");
      }
    });

    // Close suggestions on click outside
    document.addEventListener("click", (e) => {
      if (e.target !== input && e.target !== container && !container.contains(e.target)) {
        container.classList.remove("active");
      }
    });

    // Show suggestions on focus if not empty
    input.addEventListener("focus", () => {
      if (input.value.trim() && container.children.length > 0) {
        container.classList.add("active");
      }
    });
  }

  function initQuicklinks() {
    renderQuicklinks();
  }

  document.addEventListener("DOMContentLoaded", function () {
    scheduleClock();
    initGreeting();
    initEngineToggle();
    initQuicklinks();
    initSearchSuggestions();
    focusSearchInput();
  });

  window.addEventListener("load", focusSearchInput);
  window.addEventListener("pageshow", focusSearchInput);
})();

