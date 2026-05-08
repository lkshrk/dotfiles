local M = { history = {} }

function M.record(winID)
  if not winID then return end
  M.history[winID] = hs.timer.absoluteTime()
end

function M.lastFocused(winID)
  return M.history[winID] or 0
end

function M.start()
  M.filter = hs.window.filter.new(true)
  M.filter:subscribe(hs.window.filter.windowFocused, function(w)
    if w then M.record(w:id()) end
  end)
end

return M
