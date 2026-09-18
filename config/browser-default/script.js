// Omarchy Startpage - Fish / Bash Shell Emulator & Search Engine
(function () {
  "use strict";

  const STORAGE_ENGINE_KEY = "omarchy-shell-engine";
  const STORAGE_HISTORY_KEY = "omarchy-shell-history";

  const ENGINES = [
    { id: "duckduckgo", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
    { id: "google", name: "Google", url: "https://www.google.com/search?q=" },
    { id: "startpage", name: "Startpage", url: "https://www.startpage.com/sp/search?query=" },
    { id: "kagi", name: "Kagi", url: "https://kagi.com/search?q=" },
    { id: "github", name: "GitHub", url: "https://github.com/search?q=" },
    { id: "youtube", name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
    { id: "reddit", name: "Reddit", url: "https://www.reddit.com/search/?q=" },
    { id: "archwiki", name: "Arch Wiki", url: "https://wiki.archlinux.org/index.php?search=" },
  ];

  const BANGS = {
    "!g": { name: "Google", url: "https://www.google.com/search?q=" },
    "!d": { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
    "!ddg": { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
    "!sp": { name: "Startpage", url: "https://www.startpage.com/sp/search?query=" },
    "!k": { name: "Kagi", url: "https://kagi.com/search?q=" },
    "!gh": { name: "GitHub", url: "https://github.com/search?q=" },
    "!yt": { name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
    "!r": { name: "Reddit", url: "https://www.reddit.com/search/?q=" },
    "!w": { name: "Wikipedia", url: "https://en.wikipedia.org/wiki/Special:Search?search=" },
    "!aw": { name: "Arch Wiki", url: "https://wiki.archlinux.org/index.php?search=" },
  };

  const BUILTIN_COMMANDS = ["help", "ls", "cd", "open", "clear", "fastfetch", "fetch", "theme", "engine"];

  // DOM Elements
  const input = document.getElementById("terminal-input");
  const promptTyped = document.getElementById("prompt-typed");
  const promptGhost = document.getElementById("prompt-ghost");
  const promptPath = document.getElementById("prompt-path");
  const bookmarksSection = document.getElementById("bookmarks-section");
  const terminalView = document.getElementById("terminal-view");
  const terminalOutput = document.getElementById("terminal-output");
  const terminalCompletions = document.getElementById("terminal-completions");
  const completionsList = document.getElementById("completions-list");
  const promptContainer = document.getElementById("terminal-prompt");

  if (!input || !bookmarksSection || !terminalView || !completionsList) {
    return;
  }

  let currentDir = "~";
  let selectedIndex = 0;
  let currentItems = [];
  let currentGhostSuffix = "help";
  let debounceTimeout = null;
  let currentJsonpScript = null;

  // History
  function getHistory() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_HISTORY_KEY) || "[]");
    } catch (e) {
      return [];
    }
  }

  function addHistory(cmd) {
    if (!cmd || !cmd.trim()) return;
    const hist = getHistory().filter((c) => c !== cmd);
    hist.unshift(cmd);
    if (hist.length > 50) hist.pop();
    localStorage.setItem(STORAGE_HISTORY_KEY, JSON.stringify(hist));
  }

  let historyList = getHistory();
  let historyNavIndex = -1;

  // Active Engine
  function getActiveEngineIndex() {
    const saved = localStorage.getItem(STORAGE_ENGINE_KEY);
    const idx = ENGINES.findIndex((e) => e.id === saved);
    return idx === -1 ? 0 : idx;
  }

  let currentEngineIndex = getActiveEngineIndex();

  function getActiveEngine() {
    return ENGINES[currentEngineIndex];
  }

  function cycleEngine() {
    currentEngineIndex = (currentEngineIndex + 1) % ENGINES.length;
    localStorage.setItem(STORAGE_ENGINE_KEY, ENGINES[currentEngineIndex].id);
    if (input.value.trim()) {
      updateShell(input.value);
    }
  }

  // Extract bookmarks & categories from DOM
  function parseCategoriesAndBookmarks() {
    const categories = {};
    const flatBookmarks = [];

    document.querySelectorAll(".category").forEach((catEl) => {
      const titleEl = catEl.querySelector(".title");
      const catName = titleEl ? titleEl.textContent.trim().toLowerCase() : "";
      if (!catName) return;

      categories[catName] = [];

      catEl.querySelectorAll("li:not(.title) a").forEach((a) => {
        const name = a.textContent.trim();
        const url = a.href;
        if (name && url) {
          const item = { name, url, category: catName };
          categories[catName].push(item);
          flatBookmarks.push(item);
        }
      });
    });

    return { categories, flatBookmarks };
  }

  const { categories, flatBookmarks } = parseCategoriesAndBookmarks();
  const categoryNames = Object.keys(categories);

  // URL Helpers
  function isUrl(str) {
    const trimmed = str.trim();
    if (/^https?:\/\//i.test(trimmed)) return true;
    if (/^localhost(:\d+)?(\/.*)?$/i.test(trimmed)) return true;
    return /^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(:\d+)?(\/.*)?$/i.test(trimmed);
  }

  function normalizeUrl(str) {
    let trimmed = str.trim();
    if (!/^https?:\/\//i.test(trimmed)) {
      trimmed = "https://" + trimmed;
    }
    return trimmed;
  }

  function parseBang(query) {
    const trimmed = query.trim();
    const parts = trimmed.split(/\s+/);
    const prefix = parts[0].toLowerCase();
    if (BANGS[prefix]) {
      return {
        bang: BANGS[prefix],
        searchQuery: parts.slice(1).join(" "),
      };
    }
    return null;
  }

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // Fish-style Syntax Highlighting
  function renderSyntax(val) {
    if (!val) {
      promptTyped.innerHTML = "";
      return;
    }

    const trimmed = val.trim();
    const firstWord = trimmed.split(/\s+/)[0].toLowerCase();

    // Bang
    if (BANGS[firstWord]) {
      const remainder = val.slice(firstWord.length);
      promptTyped.innerHTML = `<span class="syn-bang">${escapeHtml(val.slice(0, firstWord.length))}</span>${escapeHtml(remainder)}`;
      return;
    }

    // Command
    if (BUILTIN_COMMANDS.includes(firstWord)) {
      const remainder = val.slice(firstWord.length);
      promptTyped.innerHTML = `<span class="syn-cmd">${escapeHtml(val.slice(0, firstWord.length))}</span><span class="syn-arg">${escapeHtml(remainder)}</span>`;
      return;
    }

    // URL
    if (isUrl(val)) {
      promptTyped.innerHTML = `<span class="syn-url">${escapeHtml(val)}</span>`;
      return;
    }

    promptTyped.innerHTML = escapeHtml(val);
  }

  function cancelPendingSuggestions() {
    clearTimeout(debounceTimeout);
    if (currentJsonpScript) {
      try {
        if (currentJsonpScript.parentNode) {
          currentJsonpScript.parentNode.removeChild(currentJsonpScript);
        }
      } catch (e) {}
      currentJsonpScript = null;
    }
  }

  // JSONP Google Suggestion
  function fetchSuggestions(query, callback) {
    cancelPendingSuggestions();

    const trimmed = query.trim();
    if (!trimmed) {
      callback([]);
      return;
    }

    const cbName = "fishSuggest_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

    window[cbName] = function (data) {
      if (data && Array.isArray(data[1])) {
        callback(data[1]);
      } else {
        callback([]);
      }
      delete window[cbName];
      if (currentJsonpScript && currentJsonpScript.parentNode) {
        currentJsonpScript.parentNode.removeChild(currentJsonpScript);
        currentJsonpScript = null;
      }
    };

    const s = document.createElement("script");
    s.src = `https://suggestqueries.google.com/complete/search?client=firefox&q=${encodeURIComponent(trimmed)}&callback=${cbName}`;
    currentJsonpScript = s;
    document.body.appendChild(s);
  }

  // Fish Ghost Autosuggestion Calculator
  function calculateGhostText(val) {
    if (!val || !val.trim()) return "help";
    const lower = val.toLowerCase();

    for (const cmd of BUILTIN_COMMANDS) {
      if (cmd.startsWith(lower) && cmd !== lower) {
        return cmd.slice(val.length);
      }
    }

    if (lower.startsWith("cd ")) {
      const arg = lower.slice(3).trim();
      for (const cat of categoryNames) {
        if (cat.startsWith(arg) && cat !== arg) {
          return cat.slice(arg.length);
        }
      }
    }

    if (lower.startsWith("ls ")) {
      const arg = lower.slice(3).trim();
      for (const cat of categoryNames) {
        if (cat.startsWith(arg) && cat !== arg) {
          return cat.slice(arg.length);
        }
      }
    }

    for (const bm of flatBookmarks) {
      if (bm.name.toLowerCase().startsWith(lower) && bm.name.toLowerCase() !== lower) {
        return bm.name.slice(val.length);
      }
    }

    for (const b of Object.keys(BANGS)) {
      if (b.startsWith(lower) && b !== lower) {
        return b.slice(val.length);
      }
    }

    for (const h of historyList) {
      if (h.toLowerCase().startsWith(lower) && h.toLowerCase() !== lower) {
        return h.slice(val.length);
      }
    }

    return "";
  }

  // Update Shell Interface
  function updateShell(rawVal) {
    cancelPendingSuggestions();
    renderSyntax(rawVal);

    if (!rawVal || !rawVal.trim()) {
      // Nothing input: Show dimmed 'help' inline suggestion, and keep previous bookmarks (work, dev, reddit, play) as they were!
      currentGhostSuffix = "help";
      promptGhost.textContent = "help";

      if (terminalOutput.style.display === "block") {
        // Output from a command is shown
        bookmarksSection.style.display = "none";
        terminalView.style.display = "block";
        terminalCompletions.style.display = "none";
      } else {
        // Default resting state: bookmarks are visible as they were
        bookmarksSection.style.display = "flex";
        terminalView.style.display = "none";
        terminalCompletions.style.display = "none";
      }

      currentItems = [];
      selectedIndex = 0;
      return;
    }

    // Active typing state: Hide bookmarks, display terminal completions
    bookmarksSection.style.display = "none";
    terminalView.style.display = "block";
    terminalCompletions.style.display = "block";
    terminalOutput.style.display = "none";

    currentGhostSuffix = calculateGhostText(rawVal);
    promptGhost.textContent = currentGhostSuffix;

    const query = rawVal.trim();
    const bangMatch = parseBang(query);
    const activeEngine = bangMatch ? bangMatch.bang : getActiveEngine();
    const effectiveQuery = bangMatch ? bangMatch.searchQuery : query;

    const items = [];

    // 1. Built-in shell commands match
    const lower = query.toLowerCase();
    const cmdWord = lower.split(/\s+/)[0];

    if (BUILTIN_COMMANDS.some((c) => c.startsWith(cmdWord))) {
      const matchedCmds = BUILTIN_COMMANDS.filter((c) => c.startsWith(cmdWord));
      matchedCmds.forEach((c) => {
        items.push({
          type: "cmd",
          label: c,
          cmd: c,
          desc: "builtin",
        });
      });
    }

    // 2. Direct URL
    if (isUrl(query)) {
      items.push({
        type: "url",
        label: normalizeUrl(query),
        url: normalizeUrl(query),
        desc: "url",
      });
    }

    // 3. Primary search action
    const searchTarget = effectiveQuery || query;
    items.push({
      type: "search",
      label: `search: "${searchTarget}"`,
      query: searchTarget,
      engine: activeEngine,
      desc: activeEngine.name,
    });

    // 4. Matching Bookmarks
    const matchedBookmarks = flatBookmarks.filter((b) => {
      return b.name.toLowerCase().includes(lower) || b.url.toLowerCase().includes(lower);
    });

    matchedBookmarks.slice(0, 4).forEach((b) => {
      items.push({
        type: "bookmark",
        label: b.name,
        url: b.url,
        desc: `${b.category} ➜ ${b.url.replace(/^https?:\/\//, "")}`,
      });
    });

    currentItems = items;
    renderCompletionsList();

    // 5. Asynchronous Google Suggestions
    debounceTimeout = setTimeout(() => {
      if (!effectiveQuery || BUILTIN_COMMANDS.includes(cmdWord)) return;
      fetchSuggestions(effectiveQuery, (suggestions) => {
        if (!input.value || !input.value.trim() || input.value.trim() !== query) {
          return;
        }

        const filtered = suggestions.filter((s) => s.toLowerCase() !== query.toLowerCase()).slice(0, 5);

        filtered.forEach((s) => {
          items.push({
            type: "suggestion",
            label: s,
            query: s,
            engine: activeEngine,
            desc: "suggest",
          });
        });

        if (!currentGhostSuffix && filtered.length > 0 && input.value.trim()) {
          const top = filtered[0];
          if (top.toLowerCase().startsWith(query.toLowerCase())) {
            currentGhostSuffix = top.slice(query.length);
            promptGhost.textContent = currentGhostSuffix;
          }
        }

        currentItems = items;
        renderCompletionsList();
      });
    }, 100);
  }

  function renderCompletionsList() {
    completionsList.innerHTML = "";
    if (selectedIndex >= currentItems.length) {
      selectedIndex = Math.max(0, currentItems.length - 1);
    }

    currentItems.forEach((item, idx) => {
      const li = document.createElement("li");
      const isSel = idx === selectedIndex;
      li.className = "completion-item" + (isSel ? " selected" : "");
      li.setAttribute("role", "option");
      li.setAttribute("aria-selected", isSel ? "true" : "false");

      const prefix = document.createElement("span");
      prefix.className = "comp-prefix";
      prefix.textContent = isSel ? "❯" : " ";
      li.appendChild(prefix);

      const name = document.createElement("span");
      name.className = "comp-name";
      name.textContent = item.label;
      li.appendChild(name);

      if (item.desc) {
        const desc = document.createElement("span");
        desc.className = "comp-desc";
        desc.textContent = item.desc;
        li.appendChild(desc);
      }

      li.addEventListener("click", () => {
        selectedIndex = idx;
        executeItem(item);
      });

      li.addEventListener("mouseenter", () => {
        selectedIndex = idx;
        updateHighlight();
      });

      completionsList.appendChild(li);
    });

    scrollSelectedItem();
  }

  function updateHighlight() {
    const listItems = completionsList.querySelectorAll(".completion-item");
    listItems.forEach((li, idx) => {
      const isSel = idx === selectedIndex;
      li.classList.toggle("selected", isSel);
      li.setAttribute("aria-selected", isSel ? "true" : "false");
      const prefix = li.querySelector(".comp-prefix");
      if (prefix) {
        prefix.textContent = isSel ? "❯" : " ";
      }
    });
    scrollSelectedItem();
  }

  function scrollSelectedItem() {
    const el = completionsList.children[selectedIndex];
    if (el) {
      el.scrollIntoView({ block: "nearest" });
    }
  }

  // Terminal command output
  function showOutput(htmlContent) {
    cancelPendingSuggestions();
    bookmarksSection.style.display = "none";
    terminalView.style.display = "block";
    terminalOutput.style.display = "block";
    terminalOutput.innerHTML = htmlContent;
    terminalCompletions.style.display = "none";
    input.value = "";
    currentGhostSuffix = "help";
    promptGhost.textContent = "help";
    renderSyntax("");
  }

  // Shell Command Execution
  function runShellCommand(rawCmd) {
    const parts = rawCmd.trim().split(/\s+/);
    const cmd = parts[0].toLowerCase();
    const args = parts.slice(1);

    addHistory(rawCmd);

    // clear command
    if (cmd === "clear") {
      cancelPendingSuggestions();
      input.value = "";
      currentGhostSuffix = "help";
      promptGhost.textContent = "help";
      renderSyntax("");
      terminalOutput.style.display = "none";
      terminalOutput.innerHTML = "";
      bookmarksSection.style.display = "flex";
      terminalView.style.display = "none";
      return;
    }

    // help command
    if (cmd === "help") {
      showOutput(
        `<span class="out-accent">Omarchy Fish Shell Startpage</span>\n\n` +
        `<span class="out-dir">Commands:</span>\n` +
        `  <span class="out-key">ls</span> [category]        List categories or links\n` +
        `  <span class="out-key">cd</span> [category]        Change category (work, dev, reddit, play, ~)\n` +
        `  <span class="out-key">open</span> &lt;site&gt;         Open bookmark or URL directly\n` +
        `  <span class="out-key">fastfetch</span>           Show Omarchy system banner\n` +
        `  <span class="out-key">theme</span> [name]         Show or switch Omarchy theme\n` +
        `  <span class="out-key">engine</span> [name]        Show or cycle search engine\n` +
        `  <span class="out-key">clear</span>               Reset terminal and return to bookmarks\n` +
        `  <span class="out-key">help</span>                Show this help text\n\n` +
        `<span class="out-dir">Shortcuts:</span>\n` +
        `  <span class="out-key">&rarr; (Right Arrow)</span>   Accept inline fish autosuggestion\n` +
        `  <span class="out-key">Tab</span>                 Complete selection or cycle search engines\n` +
        `  <span class="out-key">&uarr; / &darr;</span>               Navigate completions or command history\n` +
        `  <span class="out-key">Enter</span>               Execute command or web search\n` +
        `  <span class="out-key">Esc</span>                 Clear line / reset view`
      );
      return;
    }

    // ls command
    if (cmd === "ls") {
      const target = (args[0] || (currentDir === "~" ? "" : currentDir)).toLowerCase();
      if (target && categories[target]) {
        let out = `<span class="out-dir">${target}/</span>\n`;
        categories[target].forEach((b) => {
          out += `  <span class="out-file">${b.name.padEnd(14)}</span> <span class="out-link">➜  ${b.url}</span>\n`;
        });
        showOutput(out.trim());
      } else {
        let out = `<span class="out-dir">work/</span>   <span class="out-dir">dev/</span>   <span class="out-dir">reddit/</span>   <span class="out-dir">play/</span>   <span class="out-file">cat.gif</span>\n\n` +
          `<span class="out-link">Tip: Type 'cd dev' or 'ls work' to explore categories.</span>`;
        showOutput(out);
      }
      return;
    }

    // cd command
    if (cmd === "cd") {
      const target = (args[0] || "~").toLowerCase().replace(/\/$/, "");
      if (target === "~" || target === ".." || target === "") {
        currentDir = "~";
        promptPath.textContent = "~/";
        showOutput(`<span class="out-link">Returned to ~/</span>`);
      } else if (categories[target]) {
        currentDir = target;
        promptPath.textContent = `~/${target}/`;
        let out = `<span class="out-dir">~/${target}/</span>\n`;
        categories[target].forEach((b) => {
          out += `  <span class="out-file">${b.name.padEnd(14)}</span> <span class="out-link">➜  ${b.url}</span>\n`;
        });
        showOutput(out.trim());
      } else {
        showOutput(`<span class="syn-bang">cd: directory not found: ${escapeHtml(target)}</span>\nAvailable categories: ${categoryNames.join(", ")}`);
      }
      return;
    }

    // fastfetch / fetch command
    if (cmd === "fastfetch" || cmd === "fetch") {
      showOutput(
        `<span class="out-accent">       /\\ </span>        <span class="out-dir">shadow</span>@<span class="out-key">omarchy</span>\n` +
        `<span class="out-accent">      /  \\ </span>       ------------------------\n` +
        `<span class="out-accent">     /\\   \\</span>       <span class="out-key">OS:</span> Omarchy Linux (Arch Linux)\n` +
        `<span class="out-accent">    /      \\</span>      <span class="out-key">Host:</span> Hyprland Wayland Compositor\n` +
        `<span class="out-accent">   /   ,,   \\</span>     <span class="out-key">Shell:</span> fish 3.7.1\n` +
        `<span class="out-accent">  /   |  |  -\\</span>    <span class="out-key">Theme:</span> Catppuccin\n` +
        `<span class="out-accent"> /_-''    ''-_\\</span>   <span class="out-key">Font:</span> JetBrainsMono Nerd Font`
      );
      return;
    }

    // theme command
    if (cmd === "theme") {
      let themeName = getComputedStyle(document.documentElement).getPropertyValue("--theme-name").trim().replace(/^["']|["']$/g, "");
      showOutput(
        `<span class="out-key">Current Omarchy theme:</span> <span class="out-accent">${themeName || "Catppuccin"}</span>\n` +
        `<span class="out-link">Run 'omarchy theme set &lt;name&gt;' in your terminal to switch themes.</span>`
      );
      return;
    }

    // engine command
    if (cmd === "engine") {
      if (args[0]) {
        const found = ENGINES.find((e) => e.name.toLowerCase() === args[0].toLowerCase() || e.id === args[0].toLowerCase());
        if (found) {
          currentEngineIndex = ENGINES.indexOf(found);
          localStorage.setItem(STORAGE_ENGINE_KEY, found.id);
          showOutput(`<span class="out-key">Default search engine set to:</span> <span class="out-accent">${found.name}</span>`);
          return;
        }
      }
      cycleEngine();
      showOutput(`<span class="out-key">Switched search engine to:</span> <span class="out-accent">${getActiveEngine().name}</span>`);
      return;
    }

    // open command
    if (cmd === "open") {
      const target = args.join(" ").trim();
      if (!target) return;
      const found = flatBookmarks.find((b) => b.name.toLowerCase() === target.toLowerCase());
      if (found) {
        window.location.href = found.url;
      } else {
        window.location.href = normalizeUrl(target);
      }
      return;
    }

    // Direct bookmark name match
    const matchedBm = flatBookmarks.find((b) => b.name.toLowerCase() === cmd);
    if (matchedBm && args.length === 0) {
      window.location.href = matchedBm.url;
      return;
    }

    // URL Execution
    if (isUrl(rawCmd)) {
      window.location.href = normalizeUrl(rawCmd);
      return;
    }

    // Bang or Web Search
    const bangMatch = parseBang(rawCmd);
    const engine = bangMatch ? bangMatch.bang : getActiveEngine();
    const query = bangMatch ? bangMatch.searchQuery : rawCmd;
    window.location.href = engine.url + encodeURIComponent(query);
  }

  // Execute item from completions list
  function executeItem(item) {
    if (!item) return;

    if (item.type === "cmd") {
      input.value = item.cmd;
      runShellCommand(item.cmd);
    } else if (item.type === "bookmark" || item.type === "url") {
      addHistory(input.value);
      window.location.href = item.url;
    } else if (item.type === "search" || item.type === "suggestion") {
      addHistory(item.query);
      const engine = item.engine || getActiveEngine();
      window.location.href = engine.url + encodeURIComponent(item.query);
    }
  }

  // Event Listeners
  input.addEventListener("input", () => {
    historyNavIndex = -1;
    updateShell(input.value);
  });

  input.addEventListener("keydown", (e) => {
    // 1. Right Arrow or Ctrl+F: Accept inline Fish autosuggestion
    if (e.key === "ArrowRight" || (e.ctrlKey && e.key === "f")) {
      if (currentGhostSuffix) {
        e.preventDefault();
        input.value += currentGhostSuffix;
        currentGhostSuffix = "";
        updateShell(input.value);
        return;
      }
    }

    // 2. Tab: Accept ghost text, or move through completions, or cycle engine
    if (e.key === "Tab") {
      e.preventDefault();
      if (currentGhostSuffix) {
        input.value += currentGhostSuffix;
        currentGhostSuffix = "";
        updateShell(input.value);
        return;
      }

      if (currentItems.length > 0) {
        selectedIndex = (selectedIndex + 1) % currentItems.length;
        updateHighlight();
        const sel = currentItems[selectedIndex];
        if (input.value.trim()) {
          if (sel && (sel.type === "suggestion" || sel.type === "cmd")) {
            input.value = sel.query || sel.cmd || sel.label;
            renderSyntax(input.value);
          }
        }
      } else {
        cycleEngine();
      }
      return;
    }

    // 3. Arrow Down / Arrow Up: Navigate completions or command history
    if (e.key === "ArrowDown") {
      e.preventDefault();
      if (currentItems.length > 0) {
        selectedIndex = (selectedIndex + 1) % currentItems.length;
        updateHighlight();
      } else if (historyList.length > 0) {
        if (historyNavIndex > 0) {
          historyNavIndex--;
          input.value = historyList[historyNavIndex];
          updateShell(input.value);
        } else if (historyNavIndex === 0) {
          historyNavIndex = -1;
          input.value = "";
          updateShell("");
        }
      }
      return;
    }

    if (e.key === "ArrowUp") {
      e.preventDefault();
      if (currentItems.length > 0 && selectedIndex > 0) {
        selectedIndex = (selectedIndex - 1 + currentItems.length) % currentItems.length;
        updateHighlight();
      } else if (historyList.length > 0) {
        if (historyNavIndex < historyList.length - 1) {
          historyNavIndex++;
          input.value = historyList[historyNavIndex];
          updateShell(input.value);
        }
      }
      return;
    }

    // 4. Enter: Execute
    if (e.key === "Enter") {
      e.preventDefault();
      const val = input.value.trim();

      if (!val) {
        if (currentGhostSuffix) {
          runShellCommand(currentGhostSuffix);
        }
        return;
      }

      if (currentItems.length > 0 && selectedIndex > 0 && selectedIndex < currentItems.length) {
        executeItem(currentItems[selectedIndex]);
      } else {
        runShellCommand(val);
      }
      return;
    }

    // 5. Escape: Reset prompt and buffer
    if (e.key === "Escape") {
      e.preventDefault();
      cancelPendingSuggestions();
      input.value = "";
      currentGhostSuffix = "help";
      promptGhost.textContent = "help";
      terminalOutput.style.display = "none";
      terminalOutput.innerHTML = "";
      bookmarksSection.style.display = "flex";
      terminalView.style.display = "none";
      renderSyntax("");
      return;
    }
  });

  if (promptContainer) {
    promptContainer.addEventListener("click", () => {
      input.focus();
    });
  }

  // Global key grabber - type anywhere in window
  document.addEventListener("keydown", (e) => {
    if (document.activeElement === input) return;
    if (e.ctrlKey || e.altKey || e.metaKey || e.key.length > 1) return;
    input.focus();
  });

  // Clicking outside links focuses prompt
  document.addEventListener("click", (e) => {
    if (e.target.tagName !== "A" && e.target.tagName !== "BUTTON") {
      input.focus();
    }
  });

  function grabFocus() {
    input.focus();
  }

  // Initial load: show 'help' dimmed inline suggestion and keep bookmarks visible
  input.value = "";
  currentGhostSuffix = "help";
  promptGhost.textContent = "help";
  updateShell("");

  grabFocus();
  setTimeout(grabFocus, 50);
  setTimeout(grabFocus, 200);
})();
