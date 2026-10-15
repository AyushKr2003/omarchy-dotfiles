-- ╭─────────────────────────────────────────────────────────────────────────╮
-- │  Custom bindings — loaded after omarchy defaults.                       │
-- │  Uses helpers from default/hypr/helpers.lua:                            │
-- │    o.bind(keys, description, dispatcher, opts?)                         │
-- │    o.launch(cmd)                  → "uwsm-app -- cmd"                   │
-- │    o.launch_sole(match, cmd)      → focus if open, else launch          │
-- │    o.launch_webapp(url)           → omarchy-launch-webapp               │
-- │    o.launch_webapp_sole(n,url)    → focus webapp if open                │
-- │    o.bind_toggle(keys,desc,t)     → omarchy-toggle-<t>                  │
-- │    { omarchy = "x" }              → omarchy-launch-x (handles uwsm-app) │
-- │    { launch = "x" }               → uwsm-app -- x                       │
-- │    { tui = "x" }                  → omarchy-launch-tui 'x'              │
-- │    { webapp = "url" }             → omarchy-launch-webapp               │
-- │    { webapp = "url", focus=true } → focus or launch                     │
-- ╰─────────────────────────────────────────────────────────────────────────╯


function o.rebind(keys, description, dispatcher, options)
  hl.unbind(keys)
  o.bind(keys, description, dispatcher, options)
end


-- ── 1. Terminals & Editors ───────────────────────────────────────────────────

hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Tmux (Work)", { launch = "omarchy-launch-terminal-tmux" })


hl.unbind("SUPER + T")
o.bind("SUPER + T", "Terminal", { omarchy = "terminal" })

hl.unbind("SUPER + SHIFT + T")
o.bind("SUPER + SHIFT + T", "Floating Terminal", { launch = "omarchy-launch-float-terminal" })


hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + CTRL + L", "Terminal Launcher", { launch = "omarchy-launch-float-terminal a -a" })

o.bind("SUPER + PAUSE", "Full System Info", hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size = "1220 680" }))
o.bind("SUPER + KP_Prior", "Full System Info", hl.dsp.exec_cmd("xdg-terminal-exec fish -c full_sys", { float = true, size = "1220 680" }))

hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "VS Code", { launch = "code" })


-- ── 2. Browsers & Web Applications ──────────────────────────────────────────

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Default Browser", { omarchy = "browser" })

hl.unbind("SUPER + ALT + B")
o.bind("SUPER + ALT + B", "QuteBrowser", { launch = "qutebrowser" })

hl.unbind("SUPER + B")
o.bind("SUPER + B", "Zen Browser", { launch = "zen-browser" })

hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "QuteBrowser (Incognito)", { launch = "bash -c 'd=$(mktemp -d /dev/shm/qb-incognito.XXXXXX); mkdir -p \"$d/config\"; cp ~/.config/qutebrowser/{config.py,theme.py,startpage.html} \"$d/config/\" 2>/dev/null; qutebrowser --basedir \"$d\" -s content.private_browsing true file://$HOME/.config/qutebrowser/startpage.html; rm -rf \"$d\"'" })

hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "WhatsApp Web", { webapp = "https://web.whatsapp.com/", focus = true })


-- ── 3. File Managers ────────────────────────────────────────────────────────

o.bind("SUPER + E", "Nautilus File Manager", { omarchy = "nautilus" })

o.bind("SUPER + ALT + E", "File manager (cwd)", { omarchy = "nautilus-cwd" })

hl.unbind("SUPER + SHIFT + E")
-- o.bind("SUPER + SHIFT + E", "Flea", { launch = "flea" })
o.bind("SUPER + SHIFT + E", "Flea", { launch = "strata" })

-- ── 4. Window Management & Workspaces ───────────────────────────────────────

hl.unbind("SUPER + Q")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

o.bind("SUPER + SHIFT + Q", "Force kill window", hl.dsp.exec_cmd("hyprctl kill"))

hl.unbind("SUPER + Z")
o.bind("SUPER + Z", "Resize window", hl.dsp.window.resize(), { mouse = true })

hl.unbind("SUPER + SHIFT + O")
o.bind("SUPER + SHIFT + O", "Toggle floating / tiling", hl.dsp.window.float({ action = "toggle" }))

hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

-- o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
-- o.bind("SUPER + CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
--

-- ===== Smart next/prev workspace (skip repeated empty workspaces) =====
-- Omarchy binds these to "Move grouped window focus"; without the unbind
-- both actions fire on every press.
hl.unbind("SUPER + CTRL + RIGHT")
hl.unbind("SUPER + CTRL + LEFT")

local TOTAL_WORKSPACES = 10

local function wrap_id(n)
    return ((n - 1) % TOTAL_WORKSPACES) + 1
end

local function occupied_set()
    local occ = {}
    local workspaces = hl.get_workspaces()
    if workspaces ~= nil then
        for _, ws in ipairs(workspaces) do
            if ws ~= nil and ws.id ~= nil and ws.windows ~= nil and ws.windows > 0 then
                occ[ws.id] = true
            end
        end
    end
    return occ
end

local function next_workspace(direction)
    local cur = hl.get_active_workspace()
    if cur == nil or cur.id == nil then
        return nil
    end

    local occ = occupied_set()
    local pos = wrap_id(cur.id + direction)

    if occ[cur.id] then
        return pos
    else
        local steps = 0
        while not occ[pos] and steps < TOTAL_WORKSPACES do
            pos = wrap_id(pos + direction)
            steps = steps + 1
        end
        return pos
    end
end

_G.SmartWorkspace = { next = next_workspace }

o.bind("SUPER + CTRL + RIGHT", "Next workspace",
    function()
        local target = next_workspace(1)
        if target ~= nil then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        end
    end)

o.bind("SUPER + CTRL + LEFT", "Previous workspace",
    function()
        local target = next_workspace(-1)
        if target ~= nil then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        end
    end)


hl.unbind("SUPER + S")
o.bind("SUPER + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratch"))
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

-- ── 5. Shell Plugins & Custom Menus ─────────────────────────────────────────


hl.unbind("SUPER + M")
o.bind("SUPER + M", "Manga Reader", "omarchy-shell shell toggle local.manga")

hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Shaders", "omarchy-menu-shaders")


-- ── 6. Hardware & Mouse Controls ────────────────────────────────────────────

o.bind("XF86Launch6", "Mute microphone", "omarchy-audio-input-mute", { locked = true })
o.bind("SUPER + Prior", "Brightness +5%", "omarchy-brightness-display +5%", { locked = true, repeating = true })
o.bind("SUPER + Next", "Brightness -5%", "omarchy-brightness-display 5%-", { locked = true, repeating = true })

o.bind("mouse:275", "Orbit Press", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-press.sh --button 275", { locked = true })
o.bind("mouse:275", "Orbit Release", "~/.config/omarchy/plugins/local.orbit/scripts/orbit-release.sh", { locked = true, release = true })


-- ── 7. Keyboard Mouse Control ─────────────────────────────────────────────

-- Handled by fievel (~/.config/fievel/fievel.config), not Hyprland:
-- SUPER + CTRL + M toggles mouse mode. fievel reads the keyboard directly.

-- ── 8. Window Rules ─────────────────────────────────────────────────────────

-- Flea 
o.window("com.thisisgm.flea", { tag = "+floating-window" })
o.window("io.github.lgse.Strata", { tag = "+floating-window" })
