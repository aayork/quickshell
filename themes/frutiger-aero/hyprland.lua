-- Frutiger Aero windows, loaded by hyprland.lua after window-style when this
-- theme is current: a touch of rounding, a thin sky-blue frame and a soft
-- blue drop shadow. Kept subtle on purpose.
hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
    border_size = 1,
    col = {
      active_border = { colors = { "rgba(bfe6ffdd)", "rgba(4aa6eadd)" }, angle = 90 },
      inactive_border = "rgba(c9def099)",
    },
  },
  decoration = {
    rounding = 4,
    shadow = { enabled = true, range = 18, render_power = 3, offset = { 0, 3 }, color = "rgba(0b4a8a40)", color_inactive = "rgba(0b4a8a20)" },
  },
})
-- Blur behind the shell's translucent panels and their popups.
hl.layer_rule({ name = "aero-glass", match = { namespace = "^aayork-(bar|launcher|session|osd|notifications)$" }, blur = true, blur_popups = true, ignore_alpha = 0.5 })
