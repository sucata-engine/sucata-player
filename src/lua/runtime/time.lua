local runtime = sucata._runtime
local traceback = runtime.traceback
local T = runtime.api.time

local time = {}

local timers = {}
local order = {}
local next_id = 0

function time.get_delta()
  return T.delta
end

function time.get_raw_delta()
  return T.raw_delta
end

function time.get_fps()
  return T.fps
end

function time.get_time_scale()
  return T.time_scale
end

function time.set_time_scale(scale)
  if type(scale) ~= "number" then
    error("set_time_scale: scale must be a number", 2)
  end
  T.time_scale = scale
  T.delta = T.raw_delta * scale
end

function time.create_timer(callback, options)
  if type(callback) ~= "function" then
    error("create_timer: callback must be a function", 2)
  end
  local duration, auto_start, one_shot, loop = 1, true, true, false
  if type(options) == "number" then
    duration = options
  elseif type(options) == "table" then
    duration = options.time or 1
    if options.auto_start ~= nil then auto_start = options.auto_start end
    if options.one_shot ~= nil then one_shot = options.one_shot end
    if options.loop ~= nil then loop = options.loop end
  else
    error("create_timer: second argument must be a table or a number", 2)
  end
  next_id = next_id + 1
  timers[next_id] = {
    callback = callback,
    time = duration,
    left = duration,
    running = auto_start,
    one_shot = one_shot,
    loop = loop,
  }
  order[#order + 1] = next_id
  return next_id
end

function time.pause_timer(id)
  local timer = timers[id]
  if timer then
    timer.running = false
  end
end

function time.resume_timer(id)
  local timer = timers[id]
  if timer then
    timer.running = true
  end
end

function time.stop_timer(id)
  timers[id] = nil
end

local addon = { order = -1000, name = "sucata.time" }

function addon.tick()
  local dt = T.raw_delta
  local n = #order
  for i = 1, n do
    local id = order[i]
    local timer = timers[id]
    if timer and timer.running then
      timer.left = timer.left - dt
      if timer.left <= 0 then
        local ok, err = xpcall(timer.callback, traceback)
        if not ok then
          runtime.report("[timer #" .. id .. "]", err)
        end
        if timer.loop then
          timer.left = timer.time
        elseif timer.one_shot then
          if timers[id] == timer then
            timers[id] = nil
          end
        else
          timer.running = false
        end
      end
    end
  end
  local j = 0
  for i = 1, #order do
    local id = order[i]
    if timers[id] then
      j = j + 1
      order[j] = id
    end
  end
  for i = #order, j + 1, -1 do
    order[i] = nil
  end
end

function addon.free()
  timers = {}
  order = {}
end

time._addon = addon

return time
