-- mpv script for bin/screensaver: quit on mouse movement, but not on a twitch.
-- The first pointer position mpv sees becomes the anchor; the screensaver
-- quits once the pointer travels a few pixels from it. Keys and buttons still
-- quit straight away (screensaver-input.conf).
--
-- mpv reports the pointer in window coordinates, so the anchor is dropped
-- whenever the window changes size (it maps small, then goes fullscreen);
-- otherwise the resize alone looks like the mouse moved.

local threshold = 8  -- pixels of travel that count as someone being there

local anchor = nil
local log_path = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache"))
  .. "/aayork-quickshell/screensaver.log"

local function log(line)
  local file = io.open(log_path, "a")
  if not file then return end
  file:write(os.date("%Y-%m-%d %H:%M:%S ") .. line .. "\n")
  file:close()
end

mp.observe_property("osd-dimensions", "native", function()
  anchor = nil
end)

mp.add_forced_key_binding("MOUSE_MOVE", "screensaver-guard-move", function()
  local pos = mp.get_property_native("mouse-pos")
  if not pos then return end
  if not anchor then
    anchor = { x = pos.x, y = pos.y }
    return
  end
  local dx, dy = pos.x - anchor.x, pos.y - anchor.y
  if dx * dx + dy * dy >= threshold * threshold then
    log(string.format("quit: mouse moved (%d,%d) -> (%d,%d)", anchor.x, anchor.y, pos.x, pos.y))
    mp.command("quit")
  end
end)
