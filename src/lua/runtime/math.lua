local runtime = sucata._runtime
local screen = runtime.api.screen

local sqrt, floor, abs, min, max = math.sqrt, math.floor, math.abs, math.min, math.max

local smath = {}

function smath.clamp(value, low, high)
  if value < low then
    return low
  end
  if value > high then
    return high
  end
  return value
end

function smath.lerp(a, b, t)
  return a + (b - a) * t
end

function smath.distance(a, b)
  local dx = (b.x or 0) - (a.x or 0)
  local dy = (b.y or 0) - (a.y or 0)
  return sqrt(dx * dx + dy * dy)
end

function smath.move_towards(x, target, step)
  local difference = target - x
  if abs(difference) <= step then
    return target
  end
  if difference > 0 then
    return min(x + step, target)
  end
  return max(x - step, target)
end

local function normalize_rest(length, v, ...)
  if v == nil then
    return
  end
  return v / length, normalize_rest(length, ...)
end

local function zeros(v, ...)
  if v == nil then
    return
  end
  return 0, zeros(...)
end

function smath.normalize(...)
  local sum = 0
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) ~= "number" then
      error("normalize: all arguments must be numbers", 2)
    end
    sum = sum + v * v
  end
  local length = sqrt(sum)
  if length == 0 then
    return zeros(...)
  end
  return normalize_rest(length, ...)
end

function smath.overlapping(a, b)
  local left1, top1 = a.x or 0, a.y or 0
  local right1, bottom1 = left1 + (a.width or 1), top1 + (a.height or 1)
  local left2, top2 = b.x or 0, b.y or 0
  local right2, bottom2 = left2 + (b.width or 1), top2 + (b.height or 1)
  if right1 <= left2 or right2 <= left1 or bottom1 <= top2 or bottom2 <= top1 then
    return false, nil
  end
  local left, right = max(left1, left2), min(right1, right2)
  local top, bottom = max(top1, top2), min(bottom1, bottom2)
  return true, { x = left, y = top, width = right - left, height = bottom - top }
end

function smath.screen_relative(rect)
  local left, top = rect.left or 0, rect.top or 0
  local right, bottom = rect.right or 0, rect.bottom or 0
  local w, h = screen.width, screen.height
  return left * w, top * h, (right - left) * w, (bottom - top) * h
end

function smath.smooth_index(a, b, c)
  c = floor(c)
  local v = floor(a / b)
  if c > 0 then
    while v > c do
      v = v - c
    end
  end
  return v
end

return smath
