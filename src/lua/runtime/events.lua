local runtime = sucata._runtime
local traceback = runtime.traceback

local events = {}
local handlers = {}

local function owner_id(owner)
  if type(owner) == "table" then
    return owner.id or 0
  end
  if type(owner) == "number" then
    return owner
  end
  error("events: owner must be an entity state or an id", 3)
end

function events.on(owner, name, fn)
  local id = owner_id(owner)
  if type(name) ~= "string" then
    error("on: event name must be a string", 2)
  end
  if type(fn) ~= "function" then
    error("on: handler must be a function", 2)
  end
  local list = handlers[name]
  if not list then
    list = {}
    handlers[name] = list
  end
  list[#list + 1] = { owner = id, fn = fn }
end

function events.off(owner, name)
  local id = owner_id(owner)
  local function filter(key, list)
    local j = 0
    for i = 1, #list do
      local handler = list[i]
      if handler.owner ~= id then
        j = j + 1
        list[j] = handler
      end
    end
    for i = #list, j + 1, -1 do
      list[i] = nil
    end
    if j == 0 then
      handlers[key] = nil
    end
  end
  if name ~= nil then
    local list = handlers[name]
    if list then
      filter(name, list)
    end
    return
  end
  for key, list in pairs(handlers) do
    filter(key, list)
  end
end

function events.emit(name, data)
  if type(name) ~= "string" then
    error("emit: event name must be a string", 2)
  end
  local list = handlers[name]
  if not list then
    return
  end
  local n = #list
  local snapshot = {}
  for i = 1, n do
    snapshot[i] = list[i]
  end
  for i = 1, n do
    local handler = snapshot[i]
    local ok, err = xpcall(handler.fn, traceback, data)
    if not ok then
      runtime.report("[event " .. name .. "]", err)
    end
  end
end

events._remove_owner = function(id)
  events.off(id)
end

return events
