-- Pure rules for an app's real window and its remembered frame; no hl, so plain lua can test them.
local D = {}

function D.role(win, others, multi)
  if multi then return "main" end
  for _, other in ipairs(others) do
    if other.address ~= win.address and other.class == win.class and not other.transient
      and other.stable_id < win.stable_id then
      return "extra"
    end
  end
  return "main"
end

function D.title_key(class, title)
  if not title or title == "" then return nil end
  return class .. "|" .. title
end

function D.app_key(class)
  return class .. "|"
end

function D.frame(row)
  if not row then return nil end
  local x, y, w, h = tonumber(row[1]), tonumber(row[2]), tonumber(row[3]), tonumber(row[4])
  if x and y and w and h then return { x = x, y = y, w = w, h = h } end
end

function D.row(frame, now)
  return { tostring(frame.x), tostring(frame.y), tostring(frame.w), tostring(frame.h), tostring(now) }
end

function D.app_frame_allowed(role, multi)
  return role == "main" and not multi
end

function D.may_save_app(role, multi, lived_ms, remember_after_ms)
  return D.app_frame_allowed(role, multi) and (lived_ms or 0) >= remember_after_ms
end

function D.fits(frame, area)
  local cx, cy = frame.x + frame.w / 2, frame.y + frame.h / 2
  return cx >= area.x and cx < area.x + area.w and cy >= area.y and cy < area.y + area.h
end

function D.drifted(frame, x, y, w, h)
  local function off(a, b) return math.abs(a - b) > 2 end
  return off(frame.x, x) or off(frame.y, y) or off(frame.w, w) or off(frame.h, h)
end

-- Rows written before timestamps existed count as used now rather than as expired.
function D.prune(rows, now, max_age_s)
  local kept = {}
  for key, fields in pairs(rows) do
    local used = tonumber(fields[5])
    if not used then
      fields[5] = tostring(now)
      kept[key] = fields
    elseif now - used <= max_age_s then
      kept[key] = fields
    end
  end
  return kept
end

return D
