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
    const rawHours = now.getHours();
    const hours = rawHours % 12 || 12;
    const ampm = rawHours >= 12 ? "PM" : "AM";
    el.innerHTML = `${hours}:${pad(now.getMinutes())}<span class="clock__ampm">${ampm}</span>`;
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

  const DEFAULT_QUICKLINKS = [];

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
          fallback.className = "quicklink-fallback-dot";
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

  function renderThemeName() {
    const el = document.querySelector(".meta__theme");
    if (!el) return;
    let rawName = getComputedStyle(document.documentElement).getPropertyValue("--theme-name");
    rawName = rawName.trim().replace(/^["']|["']$/g, "");
    if (!rawName) return;

    let cleaned = rawName.replace(/-/g, " ");
    cleaned = cleaned.replace(/omarchy/gi, "");
    cleaned = cleaned.replace(/theme/gi, "");
    cleaned = cleaned.trim();

    const formatted = cleaned.split(/\s+/).map(word => {
      if (!word) return "";
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    }).join(" ");

    el.textContent = formatted;
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
    renderThemeName();
  });

  window.addEventListener("load", focusSearchInput);
  window.addEventListener("pageshow", focusSearchInput);
})();

