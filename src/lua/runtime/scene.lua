local runtime = sucata._runtime
local traceback = runtime.traceback
local report = runtime.report

local scene = {}

local list = {}
local globals = {}
local global_by_key = {}
local by_id = {}
local doomed = {}
local tags = {}
local next_id = 0
local started = false

local EMPTY = {}

local function entity_id(value)
  local kind = type(value)
  if kind == "table" then
    return value.id or 0
  end
  if kind == "number" then
    return value
  end
  return 0
end

local function live(id)
  local rec = by_id[id]
  if rec and not rec.destroyed then
    return rec
  end
  return nil
end

local function copy_state(source, id)
  local state = {}
  if type(source) == "table" then
    for k, v in pairs(source) do
      state[k] = v
    end
    local mt = getmetatable(source)
    if mt then
      setmetatable(state, mt)
    end
  end
  state.id = id
  return state
end

local function collect(behaviours, phase)
  local fns
  for i = 1, #behaviours do
    local fn = behaviours[i][phase]
    if type(fn) == "function" then
      fns = fns or {}
      fns[#fns + 1] = fn
    end
  end
  return fns or EMPTY
end

local KIND = {}
local kinds = setmetatable({}, { __mode = "k" })
local empty_kind = { behaviours = EMPTY, ticks = EMPTY, draws = EMPTY }

local function kind_of(source)
  if type(source) ~= "table" then
    return empty_kind
  end
  local node = kinds
  local n = table.maxn(source)
  local count = 0
  for i = 1, n do
    local b = source[i]
    if type(b) == "table" then
      count = count + 1
      local child = node[b]
      if not child then
        child = setmetatable({}, { __mode = "k" })
        node[b] = child
      end
      node = child
    end
  end
  if count == 0 then
    return empty_kind
  end
  local kind = node[KIND]
  if kind then
    return kind
  end
  local behaviours = {}
  for i = 1, n do
    local b = source[i]
    if type(b) == "table" then
      behaviours[#behaviours + 1] = b
    end
  end
  kind = {
    behaviours = behaviours,
    ticks = collect(behaviours, "tick"),
    draws = collect(behaviours, "draw"),
  }
  node[KIND] = kind
  return kind
end

local function make_record(def)
  if type(def) ~= "table" then
    error("spawn: entity must be a table", 3)
  end
  next_id = next_id + 1
  local kind = kind_of(def.behaviours)
  return {
    id = next_id,
    state = copy_state(def.state, next_id),
    kind = kind,
    ticks = kind.ticks,
    draws = kind.draws,
    initiated = false,
    destroyed = false,
    index = 0,
  }
end

local function call_each(rec, phase)
  local behaviours = rec.kind.behaviours
  local state = rec.state
  for i = 1, #behaviours do
    local fn = behaviours[i][phase]
    if type(fn) == "function" then
      local ok, err = xpcall(fn, traceback, state)
      if not ok then
        report("[entity #" .. rec.id .. "][" .. phase .. "]", err)
      end
    end
  end
end

local function init_record(rec)
  if rec.initiated then
    return
  end
  rec.initiated = true
  call_each(rec, "init")
end

local function remove_tags(rec)
  local own = rec.tags
  if not own then
    return
  end
  for tag in pairs(own) do
    local ids = tags[tag]
    if ids then
      for i = #ids, 1, -1 do
        if ids[i] == rec.id then
          table.remove(ids, i)
        end
      end
      if #ids == 0 then
        tags[tag] = nil
      end
    end
  end
  rec.tags = nil
end

local function free_record(rec)
  call_each(rec, "free")
  local events = package.loaded["sucata.events"]
  if type(events) == "table" then
    events._remove_owner(rec.id)
  end
  remove_tags(rec)
  by_id[rec.id] = nil
end

local function remove_from_list(rec)
  local index = rec.index
  if list[index] ~= rec then
    return false
  end
  local last = #list
  local moved = list[last]
  list[index] = moved
  moved.index = index
  list[last] = nil
  return true
end

local function remove_global(rec)
  for i = 1, #globals do
    if globals[i] == rec then
      table.remove(globals, i)
      for j = i, #globals do
        globals[j].index = j
      end
      break
    end
  end
  if rec.global_key and global_by_key[rec.global_key] == rec then
    global_by_key[rec.global_key] = nil
  end
  free_record(rec)
end

local function queue_destroy(rec)
  rec.destroyed = true
  doomed[#doomed + 1] = rec
end

function scene.spawn(def)
  local rec = make_record(def)
  by_id[rec.id] = rec
  local index = #list + 1
  rec.index = index
  list[index] = rec
  if started then
    init_record(rec)
  end
  return rec.id
end

function scene.spawns(defs)
  if type(defs) ~= "table" then
    error("spawns: expects a list of entities", 2)
  end
  local ids = {}
  for i = 1, #defs do
    if type(defs[i]) == "table" then
      ids[i] = scene.spawn(defs[i])
    end
  end
  return ids
end

function scene.find_by_id(id)
  local rec = live(id)
  return rec and rec.state or nil
end

function scene.destroy(entity)
  local rec = live(entity_id(entity))
  if not rec then
    return false
  end
  queue_destroy(rec)
  return true
end

function scene.destroys(entities)
  if type(entities) ~= "table" then
    error("destroys: expects a list of entities", 2)
  end
  local missing = {}
  for i = 1, #entities do
    local id = entity_id(entities[i])
    local rec = live(id)
    if rec then
      queue_destroy(rec)
    else
      missing[i] = id
    end
  end
  return missing
end

function scene.add_tag(entity, tag)
  local rec = live(entity_id(entity))
  if not rec then
    return false
  end
  local own = rec.tags
  if not own then
    own = {}
    rec.tags = own
  end
  if own[tag] then
    return true
  end
  own[tag] = true
  local ids = tags[tag]
  if not ids then
    ids = {}
    tags[tag] = ids
  end
  ids[#ids + 1] = rec.id
  return true
end

function scene.remove_tag(entity, tag)
  local rec = live(entity_id(entity))
  if not rec then
    return false
  end
  if rec.tags and rec.tags[tag] then
    rec.tags[tag] = nil
    local ids = tags[tag]
    if ids then
      for i = #ids, 1, -1 do
        if ids[i] == rec.id then
          table.remove(ids, i)
        end
      end
      if #ids == 0 then
        tags[tag] = nil
      end
    end
  end
  return true
end

function scene.has_tag(entity, tag)
  local rec = live(entity_id(entity))
  return rec ~= nil and rec.tags ~= nil and rec.tags[tag] == true
end

function scene.get_entities_by_tag(tag)
  local ids = tags[tag]
  local result = {}
  if ids then
    for i = 1, #ids do
      result[i] = ids[i]
    end
  end
  return result
end

function scene.get_entities()
  local result = {}
  for i = 1, #list do
    result[i] = list[i].id
  end
  return result
end

function scene.count()
  return #list
end

function scene.clear_entities()
  if not started then
    for i = #list, 1, -1 do
      local rec = list[i]
      list[i] = nil
      free_record(rec)
    end
    return
  end
  for i = 1, #list do
    local rec = list[i]
    if not rec.destroyed then
      queue_destroy(rec)
    end
  end
end

function scene.load_global(key, def)
  if type(key) ~= "string" then
    error("load_global: key must be a string", 2)
  end
  local old = global_by_key[key]
  if old then
    remove_global(old)
  end
  local rec = make_record(def)
  rec.global_key = key
  by_id[rec.id] = rec
  global_by_key[key] = rec
  globals[#globals + 1] = rec
  rec.index = #globals
  if started then
    init_record(rec)
  end
  return rec.id
end

function scene.get_global(key)
  local rec = global_by_key[key]
  return rec and rec.state or nil
end

function scene.unload_global(key)
  local rec = global_by_key[key]
  if rec then
    remove_global(rec)
  end
end

local stage, pos, current = 1, 0, nil

local function tick_range(arr, from, dt)
  for i = from, 1, -1 do
    pos = i
    local rec = arr[i]
    if rec and rec.initiated and not rec.destroyed then
      current = rec
      local fns = rec.ticks
      local state = rec.state
      for j = 1, #fns do
        fns[j](state, dt)
      end
    end
  end
end

local function tick_body(dt)
  if stage == 1 then
    tick_range(globals, pos, dt)
    stage = 2
    pos = #list
  end
  tick_range(list, pos, dt)
end

local function draw_range(arr, from)
  for i = from, #arr do
    pos = i
    local rec = arr[i]
    if rec and rec.initiated and not rec.destroyed then
      current = rec
      local fns = rec.draws
      local state = rec.state
      for j = 1, #fns do
        fns[j](state)
      end
    end
  end
end

local function draw_body()
  if stage == 1 then
    draw_range(globals, pos)
    stage = 2
    pos = 1
  end
  draw_range(list, pos)
end

local function fail(phase, err)
  local id = current and current.id or "?"
  report("[entity #" .. id .. "][" .. phase .. "]", err)
end

local addon = { order = 100, name = "sucata.scene" }

function addon.init()
  started = true
  for i = 1, #globals do
    init_record(globals[i])
  end
  for i = 1, #list do
    init_record(list[i])
  end
end

function addon.tick(dt)
  stage, pos, current = 1, #globals, nil
  while true do
    local ok, err = xpcall(tick_body, traceback, dt)
    if ok then
      break
    end
    fail("tick", err)
    pos = pos - 1
  end
  current = nil
end

function addon.draw()
  stage, pos, current = 1, 1, nil
  while true do
    local ok, err = xpcall(draw_body, traceback)
    if ok then
      break
    end
    fail("draw", err)
    pos = pos + 1
  end
  current = nil
end

function addon.late()
  if #doomed > 0 then
    local queue = doomed
    doomed = {}
    for i = 1, #queue do
      local rec = queue[i]
      if rec.global_key then
        if by_id[rec.id] then
          remove_global(rec)
        end
      elseif remove_from_list(rec) then
        free_record(rec)
      end
    end
  end
end

function addon.free()
  for i = #list, 1, -1 do
    local rec = list[i]
    list[i] = nil
    free_record(rec)
  end
  for i = #globals, 1, -1 do
    local rec = globals[i]
    globals[i] = nil
    free_record(rec)
  end
  global_by_key = {}
  doomed = {}
  started = false
end

scene._addon = addon

return scene
