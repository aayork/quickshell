-- Compositor for the login screen (greeter/start). One client, no binds.

local dir  = os.getenv("AAYORK_GREETER_DIR")  or "/etc/greetd/aayork-greeter"
local data = os.getenv("AAYORK_GREETER_DATA") or "/var/lib/aayork-greeter"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
-- The desktop's monitor layout, copied by bin/greeter-sync, so the scale matches.
do local path = data .. "/monitors.lua"; local f = io.open(path, "r"); if f then f:close(); dofile(path) end end

local cursorTheme, cursorSize = "Adwaita", "24"
do
  local f = io.open(data .. "/cursor", "r")
  if f then
    cursorTheme = f:read("l") or cursorTheme
    cursorSize = f:read("l") or cursorSize
    f:close()
  end
end
hl.env("XCURSOR_THEME", cursorTheme)
hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_SIZE", cursorSize)
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
hl.env("QT_SCALE_FACTOR", "1")

hl.config({
    animations = { enabled = false },
    cursor = { no_hardware_cursors = 2 },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_hyprland_guiutils_check = true,
        disable_xdg_env_checks = true,
        -- Launched directly, not via start-hyprland: its crash restart is a
        -- config-less "safe mode", where greeter/start should fall back to tuigreet.
        disable_watchdog_warning = true,
        force_default_wallpaper = 0,
    },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

hl.on("hyprland.start", function()
    hl.exec_cmd(dir .. "/run-shell")
end)
