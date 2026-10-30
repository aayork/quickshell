-- Hyprland config for aayork-quickshell, written by its installer.
-- Edit freely; re-running the installer keeps a backup before replacing it
-- (and only replaces it with --overwrite-config).
--
-- Keybindings are modelled on Omarchy's defaults (github.com/basecamp/omarchy).
-- SUPER+Space opens the launcher, SUPER+SHIFT+Space Settings, SUPER+Escape
-- the session menu.

------------------
---- MONITORS ----
------------------

-- Every screen at its preferred mode, placed automatically, scale picked by
-- Hyprland. Change resolution and scale from the launcher (type "displays";
-- what you keep there is saved to hyprmoncfg-monitors.lua, loaded at the
-- bottom of this file) or add rules here, e.g.:
-- hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = "1" })
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "@TERMINAL@"
local fileManager = "@FILE_MANAGER@"

-- The shell: bar, launcher, notifications, OSD, lock screen.
local shellPath = "@SHELL_DIR@"
-- Its state: the current theme and background, and the cursor and window
-- style files loaded further down. Written by the scripts in its bin/.
local shellState = os.getenv("HOME") .. "/.local/state/aayork-quickshell"

-- The default browser (xdg-settings), whichever it is.
local browser = shellPath .. "/bin/launch-browser"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- The shell. systemd-cat keeps its log in the journal:
    --   journalctl --user -t aayork-quickshell
    -- It is also the polkit agent, so no separate agent is started.
    hl.exec_cmd("systemd-cat -t aayork-quickshell quickshell -p " .. shellPath)
    -- Feeds a DPI hint to Xwayland apps, which xwayland.force_zero_scaling
    -- otherwise leaves at the 96 dpi default.
    hl.exec_cmd("xsettingsd")
    hl.exec_cmd("sh -c '[ -f \"$HOME/.Xresources\" ] && xrdb -merge \"$HOME/.Xresources\"'")
    -- Unlocks the keyring the calendar login is stored in.
    hl.exec_cmd("sh -c 'command -v gnome-keyring-daemon >/dev/null && gnome-keyring-daemon --start --components=secrets'")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- The cursor theme and size chosen in Settings (bin/cursor-set) override the defaults above.
do local path = shellState .. "/cursor.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end

-- Hyprland starts with a bare PATH (no login-shell profile), so without this
-- nothing it spawns, the shell included, finds what is in ~/.local/bin.
hl.env("PATH", os.getenv("HOME") .. "/.local/bin:/usr/local/bin:" .. (os.getenv("PATH") or "/usr/bin"))

-- Qt apps under Xwayland: with xwayland.force_zero_scaling below they get the
-- full-size buffer, and their own auto-scaling would double it.
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Flat, thin borders that follow the theme, one quick workspace animation.

-- Border colors follow the active theme. bin/theme-set runs `hyprctl reload`
-- after swapping the theme, which re-reads colors.toml here.
local function theme_color(key, fallback)
    local f = io.open(shellState .. "/current/theme/colors.toml", "r")
    if not f then return fallback end
    local text = f:read("*a")
    f:close()
    local hex = text:match("\n%s*" .. key .. "%s*=%s*[\"']?#(%x%x%x%x%x%x)")
        or text:match("^%s*" .. key .. "%s*=%s*[\"']?#(%x%x%x%x%x%x)")
    return hex and ("rgba(" .. hex .. "ff)") or fallback
end

hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 4,
        border_size = 1,
        col = {
            active_border   = theme_color("accent", "rgba(d4d4d4ff)"),
            inactive_border = theme_color("lighter_background", "rgba(3a3a3aff)"),
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },
        -- Blur for anything translucent (the launcher card, terminals).
        blur = { enabled = true, size = 10, passes = 3 },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,    -- the shell draws the wallpaper
        disable_hyprland_logo   = true,
    },

    xwayland = {
        -- On fractionally scaled screens, let Xwayland apps render at full
        -- resolution instead of 1x and upscaled (blurry).
        force_zero_scaling   = true,
        use_nearest_neighbor = false,
    },
})

-- Animations: everything off except a quick slide+fade on workspace switch.
hl.curve("wsOut", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.animation({ leaf = "global",     enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.5, bezier = "wsOut", style = "slidefade 15%" })

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = { natural_scroll = false },
    },
})
-- Pointer speed and acceleration from the shell's mouse settings override the above.
do local path = shellState .. "/mouse.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-------- Apps --------

hl.bind(mainMod .. " + Return",         hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SHIFT + F",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + CTRL + T",       hl.dsp.exec_cmd(terminal .. " -e btop"))

-------- Shell panels --------

local function shellIpc(target, method, arg)
    local cmd = "qs -p " .. shellPath .. " ipc call " .. target .. " " .. method
    if arg then cmd = cmd .. " " .. arg end
    return hl.dsp.exec_cmd(cmd)
end

hl.bind(mainMod .. " + Space",         shellIpc("launcher", "toggle"))
hl.bind(mainMod .. " + SHIFT + Space", shellIpc("settings", "toggle"))
hl.bind(mainMod .. " + Escape",        shellIpc("session", "toggle"))
-- Jot, the scratchpad under the bar's note button.
hl.bind("ALT + A",                     shellIpc("bar", "toggle", "jot"))
hl.bind("XF86PowerOff",                shellIpc("session", "toggle"), { locked = true })
hl.bind(mainMod .. " + L",             shellIpc("lock", "lock"))
hl.bind(mainMod .. " + CTRL + L",      shellIpc("lock", "lock"))

-------- Screenshots --------
-- Run by Hyprland directly, never through the shell, so the screen freeze
-- and area picker work. Each capture goes to the shell's quick-access stack.
local screenshot = shellPath .. "/bin/screenshot"

hl.bind("PRINT",           hl.dsp.exec_cmd(screenshot .. " smart"))
hl.bind("ALT + SHIFT + 3", hl.dsp.exec_cmd(screenshot .. " fullscreen"))
hl.bind("ALT + SHIFT + 4", hl.dsp.exec_cmd(screenshot .. " smart"))
hl.bind("F12",             hl.dsp.exec_cmd(screenshot .. " region"))
-- All-In-One: every capture mode, and recording, from one key.
hl.bind("ALT + SHIFT + 5", hl.dsp.exec_cmd(screenshot .. " allinone"))

hl.bind(mainMod .. " + comma",         shellIpc("notifications", "dismissAll"))
hl.bind(mainMod .. " + SHIFT + comma", shellIpc("notifications", "clear"))
hl.bind(mainMod .. " + CTRL + comma",  shellIpc("notifications", "toggleDnd"))

-------- Window management --------

hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- Pop out: float the window as a centred card instead of at its tiled size.
hl.bind(mainMod .. " + T", function()
    local w = hl.get_active_window()
    if not w then return end
    local wasFloating = w.floating
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    if wasFloating then return end
    local m = hl.get_active_monitor()
    local width  = math.floor(m.width  / m.scale * 0.6)
    local height = math.floor(m.height / m.scale * 0.65)
    hl.dispatch(hl.dsp.window.resize({ x = width, y = height }))
    hl.dispatch(hl.dsp.window.center())
end)
hl.bind(mainMod .. " + F",       hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

hl.bind(mainMod .. " + G",                 hl.dsp.group.toggle())
hl.bind(mainMod .. " + ALT + Tab",         hl.dsp.group.next())
hl.bind(mainMod .. " + ALT + SHIFT + Tab", hl.dsp.group.prev())

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }))

-- Workspaces: SUPER+[0-9] to switch, +SHIFT to move a window there,
-- +SHIFT+ALT to move it without following.
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,               hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,       hl.dsp.window.move({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mainMod .. " + Tab",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad
hl.bind(mainMod .. " + S",             hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mainMod .. " + grave",         hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mainMod .. " + SHIFT + S",     hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Resize the active window
hl.bind(mainMod .. " + minus",         hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mainMod .. " + equal",         hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Floating windows can't stay behind the bar: one whose top is above the
-- bar's bottom edge is put back flush under it once it stops moving.
-- Hyprland has no "window moved" event, so a short timer checks instead.
local function xy(v)
    if type(v) ~= "table" then return 0, 0 end
    return v.x or v[1] or 0, v.y or v[2] or 0
end
local lastSeen = {}
hl.timer(function()
    local w = hl.get_active_window()
    if not w or not w.floating or (w.fullscreen or 0) ~= 0 or not w.monitor then return end
    local r = w.monitor.reserved
    local top = type(r) == "table" and (r.top or r[2] or 0) or 0
    local _, monY = xy(w.monitor.position)
    local wx, wy = xy(w.at)
    local minY = monY + top + 1
    local key = w.address .. ":" .. wx .. "," .. wy
    if wy < minY and lastSeen.key == key then
        hl.dispatch(hl.dsp.window.move({ x = wx, y = minY }))
    end
    lastSeen.key = key
end, { timeout = 120, type = "repeat" })

-------- Media keys --------

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
-- Play/pause/next/previous go to the shell's Now Playing player;
-- playerctl is the fallback when the shell is not running.
local function mediaKey(method, fallback)
    return hl.dsp.exec_cmd("qs -p " .. shellPath .. " ipc call media " .. method .. " || playerctl " .. fallback)
end
hl.bind("XF86AudioNext",  mediaKey("next", "next"),         { locked = true })
hl.bind("XF86AudioPause", mediaKey("toggle", "play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  mediaKey("toggle", "play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  mediaKey("previous", "previous"), { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Steam games on Proton's Wayland driver drop fullscreen when they regain
-- focus; once a game is fullscreen, ignore its own requests (SUPER+F still works).
hl.window_rule({
    name  = "steam-game-keep-fullscreen",
    match = { class = "^steam_app_\\d+$", fullscreen = true },
    suppress_event = "fullscreen",
})

-- The shell's Settings window: floating, centred, the rest dimmed, and
-- pinned so it follows you between workspaces.
hl.window_rule({
    name  = "shell-settings",
    match = { class = "^org\\.quickshell$", title = "^Settings$" },
    float      = true,
    center     = true,
    size       = "760 620",
    dim_around = true,
    pin        = true,
})

-- File chooser dialogs float over whatever asked for them.
hl.window_rule({
    name  = "file-chooser",
    match = { title = "^(Open File|Save File|Open Files|Select a File|Choose Files?)(.*)$" },
    float  = true,
    center = true,
    size   = "700 540",
})

-- The launcher's card is translucent; blur what shows through it.
hl.layer_rule({ name = "shell-launcher-blur", match = { namespace = "^aayork-launcher$" }, blur = true, blur_popups = true, ignore_alpha = 0.3 })
-- Jot's note fades in by itself, so no compositor animation on top.
hl.layer_rule({ name = "shell-jot", match = { namespace = "^aayork-jot$" }, no_anim = true })

-- The video screensaver (bin/screensaver), started by the shell when idle.
hl.window_rule({
    name  = "aerial-screensaver",
    match = { class = "^org.aayork.screensaver$" },
    fullscreen = true,
    immediate  = true,
    no_anim    = true,
    no_shadow  = true,
    no_dim     = true,
    decorate   = false,
})

-- Window appearance from Settings (bin/window-style); overrides LOOK AND FEEL above.
do local path = shellState .. "/window-style.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
-- A theme can restyle windows; its hyprland.lua loads last, only while it is the current theme.
do local path = shellState .. "/current/theme/hyprland.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
-- Your own additions, kept across installer runs.
do local path = os.getenv("HOME") .. "/.config/hypr/local.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
-- Monitor settings kept from the launcher's Displays view (type "displays").
-- Loaded last so they win over the catch-all monitor rule at the top.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
