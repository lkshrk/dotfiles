-- Portrait app slots.
local C = require("hypr.screens.config")
local U = require("hypr.screens.util")

local S = {}

function S.place(w)
  local side = hl.get_monitor(C.side)
  if not side then return end
  local slot = C.slots[U.app(w)] or { row = C.MID }
  U.frame(w, U.cell(U.area(side), slot.row, slot.rows or 1, slot.col or 0, slot.cols or 3))
  if slot.above then hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w })) end
end

return S
