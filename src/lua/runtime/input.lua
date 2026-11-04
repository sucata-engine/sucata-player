local runtime = sucata._runtime
local api = runtime.api
local I = api.input
local M = api.mouse
local C = api.camera
local c_is_hover = api.is_hover

local keys = sucata._keys
local MOUSE = sucata._mouse_offset
local lower = string.lower

local input = {}

local function resolve(name)
  if type(name) ~= "string" then
    error("input functions expect all arguments to be strings", 3)
  end
  local code = keys[lower(name)]
  if code == nil then
    code = false
  end
  keys[name] = code
  return code
end

local function make_check(key_states, button_states)
  local function check(name, ...)
    local code = keys[name]
    if code == nil then
      code = resolve(name)
    end
    if code then
      if code < MOUSE then
        if key_states[code] then
          return true
        end
      elseif button_states[code - MOUSE] then
        return true
      end
    end
    if (...) ~= nil then
      return check(...)
    end
    return false
  end
  return check
end

input.is_held = make_check(I.keys_down, I.btn_down)
input.is_pressed = make_check(I.keys_pressed, I.btn_pressed)
input.is_released = make_check(I.keys_released, I.btn_released)

function input.get_mouse_position()
  return M.x, M.y
end

function input.get_relative_mouse_position()
  local zoom = C.zoom
  return (M.x + C.position[0]) / zoom, (M.y + C.position[1]) / zoom
end

function input.get_mouse_scroll()
  return I.scroll[0], I.scroll[1]
end

function input.get_key()
  return I.last_char
end

function input.is_hover(id, x, y, w, h, z, fixed)
  if type(id) ~= "string" then
    error("is_hover: id must be a string", 2)
  end
  return c_is_hover(id, #id, x or 0, y or 0, w or 0, h or 0, z or 0, fixed and 1 or 0) ~= 0
end

return input
