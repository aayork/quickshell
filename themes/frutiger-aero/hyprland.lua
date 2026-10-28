-- Frutiger Aero windows, loaded by hyprland.lua after window-style when this
-- theme is current: a touch of rounding, a thin smoked-glass frame and a soft
-- black drop shadow like Windows Vista's. Kept subtle on purpose.
hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 6,
    border_size = 1,
    col = {
      active_border = { colors = { "rgba(8aa3b8cc)", "rgba(2a3a48cc)" }, angle = 90 },
      inactive_border = "rgba(1a242ecc)",
    },
  },
  decoration = {
    rounding = 4,
    -- A light blur, so the glass stays see-through.
    blur = { enabled = true, size = 4, passes = 2 },
    shadow = { enabled = true, range = 22, render_power = 2, offset = { 0, 6 }, color = "rgba(00000080)", color_inactive = "rgba(00000048)" },
  },
})
-- Blur behind the shell's translucent panels and their popups.
hl.layer_rule({ name = "aero-glass", match = { namespace = "^aayork-(bar|launcher|session|osd|notifications)$" }, blur = true, blur_popups = true, ignore_alpha = 0.5 })
