local runtime = sucata._runtime
local pads = runtime.api.gamepads
local MAX = sucata._max_gamepads
local buttons = sucata._gamepad_buttons
local axes = sucata._gamepad_axes
local gamepad_name = sucata._gamepad_name
local lower = string.lower

local gamepad = {}

local function lookup(map, name, fn)
  local index = map[name]
  if index ~= nil then
    return index
  end
  if type(name) ~= "string" then
    error(fn .. ": name must be a string", 3)
  end
  index = map[lower(name)]
  if index == nil then
    index = false
  end
  map[name] = index
  return index
end

local function make_check(field, fn)
  return function(name, slot)
    local index = lookup(buttons, name, fn)
    if slot ~= nil then
      if slot < 0 or slot >= MAX then
        return false, -1
      end
      local pad = pads[slot]
      if pad.connected == 0 or not index then
        return false, -1
      end
      return pad[field][index], slot
    end
    if not index then
      return false, -1
    end
    for i = 0, MAX - 1 do
      local pad = pads[i]
      if pad.connected ~= 0 and pad[field][index] then
        return true, i
      end
    end
    return false, -1
  end
end

gamepad.is_held = make_check("held", "is_held")
gamepad.is_pressed = make_check("pressed", "is_pressed")
gamepad.is_released = make_check("released", "is_released")

function gamepad.get_axis(name, slot)
  local index = lookup(axes, name, "get_axis")
  if slot ~= nil then
    if slot < 0 or slot >= MAX or not index then
      return 0, slot
    end
    local pad = pads[slot]
    if pad.connected == 0 then
      return 0, slot
    end
    return pad.axes[index], slot
  end
  if not index then
    return 0, -1
  end
  for i = 0, MAX - 1 do
    local pad = pads[i]
    if pad.connected ~= 0 then
      local value = pad.axes[index]
      if value ~= 0 then
        return value, i
      end
    end
  end
  return 0, -1
end

function gamepad.get_count()
  local count = 0
  for i = 0, MAX - 1 do
    if pads[i].connected ~= 0 then
      count = count + 1
    end
  end
  return count
end

function gamepad.is_connected(slot)
  return slot >= 0 and slot < MAX and pads[slot].connected ~= 0
end

function gamepad.get_info(slot)
  return gamepad_name(slot)
end

return gamepad
