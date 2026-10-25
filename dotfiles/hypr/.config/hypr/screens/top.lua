-- Top screen: two fixed halves, and more windows on a half become tabs instead of new tiles.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")

local T = {}

local function side_of(w)
  if U.has_tag(w, "col-right") then return "right" end
  return "left"
end

-- The side each app last took, by class, so windows reopened in any order after a restart return to their half.
local sides_file = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/hypr-screens/sides"

local function load_sides()
  local sides = {}
  local f = io.open(sides_file, "r")
  if not f then return sides end
  for line in f:lines() do
    local class, side = line:match("^(.-)\t(%a+)$")
    if class and (side == "left" or side == "right") then sides[class] = side end
  end
  f:close()
  return sides
end

local function remember_side(class, side)
  if not class or class == "" then return end
  local sides = load_sides()
  if sides[class] == side then return end
  sides[class] = side
  -- No mkdir here: blocking on a child process from inside the compositor can stall it. setup creates the directory.
  local f = io.open(sides_file, "w")
  if not f then return end
  for c, s in pairs(sides) do f:write(c, "\t", s, "\n") end
  f:close()
end

-- A lone window takes the full width. Windows on the same half end up tabbed by T.join.
hl.layout.register("columns", {
  recalculate = function(ctx)
    local used = {}
    for _, target in ipairs(ctx.targets) do
      if target.window then used[side_of(target.window)] = true end
    end
    local split = used.left and used.right
    for _, target in ipairs(ctx.targets) do
      local side = target.window and side_of(target.window) or "left"
      target:place(split and ctx:column(side == "left" and 1 or 2, 2) or ctx.area)
    end
  end,
})

local function tiled_on_top(except)
  local list = {}
  for _, w in ipairs(hl.get_workspace_windows(C.top_workspace)) do
    if w ~= except and not w.floating then list[#list + 1] = w end
  end
  return list
end

local function in_group(group, w)
  local members = group and group.members
  if type(members) ~= "table" then return members == w end
  for _, m in ipairs(members) do
    if m == w then return true end
  end
  return false
end

function T.pick_side(w)
  if U.has_tag(w, "col-left") then return "left" end
  if U.has_tag(w, "col-right") then return "right" end
  local stored = load_sides()[w.class]
  if stored then return stored end
  local taken = {}
  for _, other in ipairs(tiled_on_top(w)) do taken[side_of(other)] = true end
  if not taken.left then return "left" end
  if not taken.right then return "right" end
  local last = hl.get_workspace(C.top_workspace).last_window
  return last and last ~= w and side_of(last) or "left"
end

function T.join(w, side)
  remember_side(w.class, side)
  for _, other in ipairs(tiled_on_top(w)) do
    if side_of(other) == side then
      if in_group(other.group, w) then return end
      if w.group then hl.dispatch(hl.dsp.window.move({ out_of_group = true, window = w })) end
      hl.dispatch(hl.dsp.window.tag({ tag = "-col-" .. (side == "left" and "right" or "left"), window = w }))
      hl.dispatch(hl.dsp.window.tag({ tag = "+col-" .. side, window = w }))
      if not other.group then hl.dispatch(hl.dsp.group.toggle({ window = other })) end
      other.group:add(w)
      return
    end
  end
  if w.group then hl.dispatch(hl.dsp.window.move({ out_of_group = true, window = w })) end
  hl.dispatch(hl.dsp.window.tag({ tag = "-col-" .. (side == "left" and "right" or "left"), window = w }))
  hl.dispatch(hl.dsp.window.tag({ tag = "+col-" .. side, window = w }))
  -- A tag change does not re-run the layout, and no layout message does either; leaving and re-entering tiling does.
  hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
  hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
end

return T
