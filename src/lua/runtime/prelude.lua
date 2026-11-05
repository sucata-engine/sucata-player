local ffi = require("ffi")

table.unpack = table.unpack or unpack
table.pack = table.pack or function(...)
  return { n = select("#", ...), ... }
end
math.tointeger = math.tointeger or function(x)
  if type(x) == "number" and x == math.floor(x) and x >= -2 ^ 53 and x <= 2 ^ 53 then
    return x
  end
  return nil
end
math.type = math.type or function(x)
  if type(x) ~= "number" then
    return nil
  end
  if x == math.floor(x) and x >= -2 ^ 53 and x <= 2 ^ 53 then
    return "integer"
  end
  return "float"
end
math.maxinteger = math.maxinteger or 2 ^ 53
math.mininteger = math.mininteger or -2 ^ 53

ffi.cdef [[
typedef struct {
  double delta;
  double raw_delta;
  double time_scale;
  double fps;
} sucata_time;

typedef struct {
  double width;
  double height;
} sucata_screen;

typedef struct {
  bool keys_down[512];
  bool keys_pressed[512];
  bool keys_released[512];
  uint32_t mods;
  float mouse_pos[2];
  float mouse_delta[2];
  float scroll[2];
  bool btn_down[3];
  bool btn_pressed[3];
  bool btn_released[3];
  uint32_t last_char;
} sucata_input;

typedef struct {
  uint32_t tex;
  int32_t z;
  float x, y, w, h;
  float rotation;
  float scale_x, scale_y;
  float origin_x, origin_y;
  int32_t fixed;
  int32_t tiled;
  uint32_t shader;
  float tile_w, tile_h;
} sucata_quad;

typedef struct {
  uint32_t font;
  int32_t z;
  float x, y;
  float size;
  float rotation;
  float scale_x, scale_y;
  float origin_x, origin_y;
  float color[4];
  float opacity;
  int32_t fixed;
  int32_t align;
  float max_width;
  uint32_t shader;
} sucata_text;

typedef struct {
  int32_t connected;
  bool held[32];
  bool pressed[32];
  bool released[32];
  float axes[8];
} sucata_gamepad;

typedef struct {
  float x, y;
} sucata_mouse;

typedef struct {
  float position[2];
  float zoom;
  float rotation;
} sucata_camera;

typedef struct {
  sucata_time *time;
  sucata_input *input;
  sucata_screen *screen;
  void (*rect)(uint32_t, float, float, float, float, int32_t);
  void (*rect_ex)(sucata_quad *);
  void (*text)(const char *, size_t, float, float, float, int32_t);
  void (*text_ex)(const char *, size_t, sucata_text *);
  sucata_mouse *mouse;
  sucata_camera *camera;
  sucata_gamepad *gamepads;
  int32_t (*is_hover)(const char *, size_t, float, float, float, float, int32_t, int32_t);
} sucata_api;
]]

local sizes = sucata._sizes
assert(ffi.sizeof("sucata_time") == sizes.time, "sucata: sucata_time layout mismatch")
assert(ffi.sizeof("sucata_screen") == sizes.screen, "sucata: sucata_screen layout mismatch")
assert(ffi.sizeof("sucata_input") == sizes.input, "sucata: sucata_input layout mismatch")
assert(ffi.sizeof("sucata_api") == sizes.api, "sucata: sucata_api layout mismatch")
assert(ffi.sizeof("sucata_quad") == sizes.quad, "sucata: sucata_quad layout mismatch")
assert(ffi.sizeof("sucata_text") == sizes.text, "sucata: sucata_text layout mismatch")
assert(ffi.sizeof("sucata_gamepad") == sizes.gamepad, "sucata: sucata_gamepad layout mismatch")
assert(ffi.sizeof("sucata_mouse") == sizes.mouse, "sucata: sucata_mouse layout mismatch")
assert(ffi.sizeof("sucata_camera") == sizes.camera, "sucata: sucata_camera layout mismatch")

local resolve_path = sucata._resolve_path
local raw_load = ffi.load
local LIB_EXT = ffi.os == "Windows" and ".dll" or ffi.os == "OSX" and ".dylib" or ".so"

ffi.load = function(name, global)
  if type(name) ~= "string" then
    error("ffi.load: name must be a string", 2)
  end
  if not name:find("://", 1, true) then
    return raw_load(name, global)
  end
  local path = resolve_path(name)
  local ok, lib = pcall(raw_load, path, global)
  if ok then
    return lib
  end
  if path:sub(-#LIB_EXT) ~= LIB_EXT then
    local ok_ext, lib_ext = pcall(raw_load, path .. LIB_EXT, global)
    if ok_ext then
      return lib_ext
    end
  end
  error(lib, 2)
end

local api = ffi.cast("sucata_api *", sucata._ffi)
local T = api.time
local c_rect = api.rect
local c_rect_ex = api.rect_ex
local c_text = api.text
local c_text_ex = api.text_ex

local traceback = debug.traceback
local report_error = sucata._error

local runtime = {
  api = api,
  traceback = traceback,
  report = function(where, err)
    report_error(where .. " " .. tostring(err))
  end,
}
sucata._runtime = runtime

local graphic = sucata.graphic
local make_sprite = graphic._sprite
local load_font = graphic.load_font
local rect_table = graphic._rect_table
local text_table = graphic._text_table
graphic._sprite = nil
graphic._rect_table = nil
graphic._text_table = nil

graphic.load_texture = function(path, r, g, b, a)
  if type(path) ~= "string" then
    error("load_texture: path must be a string", 2)
  end
  return make_sprite(path, r, g, b, a)
end

graphic.color = function(r, g, b, a)
  return make_sprite("", r, g, b, a)
end

graphic.load_atlas = function(path, cell_w, cell_h, spacing, margin, r, g, b, a)
  if type(path) ~= "string" then
    error("load_atlas: path must be a string", 2)
  end
  if type(cell_w) ~= "number" or cell_w <= 0 then
    error("load_atlas: cell width must be a positive number", 2)
  end
  cell_h = cell_h or cell_w
  spacing = spacing or 0
  margin = margin or 0
  return setmetatable({}, {
    __index = function(frames, index)
      if type(index) ~= "number" or index < 1 or index % 1 ~= 0 then
        return nil
      end
      local handle = make_sprite(path, r, g, b, a, cell_w, cell_h, spacing, margin, index - 1)
      rawset(frames, index, handle)
      return handle
    end,
  })
end

local textures = {}
local fonts = {}

local function texture_of(value)
  if value == nil then
    return 0
  end
  local handle = textures[value]
  if handle then
    return handle
  end
  if type(value) ~= "string" then
    error("texture must be a handle from load_texture, load_atlas or color, or a path", 3)
  end
  handle = make_sprite(value)
  textures[value] = handle
  return handle
end

local function font_of(value)
  if value == nil then
    return 0
  end
  if type(value) == "number" then
    return value
  end
  local handle = fonts[value]
  if handle then
    return handle
  end
  if type(value) ~= "string" then
    error("font must be a handle from load_font or a path", 3)
  end
  handle = load_font(value)
  fonts[value] = handle
  return handle
end

local quad = ffi.new("sucata_quad")
local rect_args = {}

graphic.rect = function(tex, x, y, w, h, z, rotation, scale_x, scale_y, origin_x, origin_y, fixed,
                        tiled, tile_w, tile_h, shader, shader_args)
  if type(tex) ~= "number" then
    tex = texture_of(tex)
  end
  if rotation == nil and scale_x == nil and origin_x == nil and fixed == nil and tiled == nil and shader == nil then
    c_rect(tex, x, y, w, h, z or 0)
    return
  end
  scale_x = scale_x or 1
  origin_x = origin_x or 0
  if shader_args ~= nil then
    local t = rect_args
    t.texture, t.x, t.y, t.width, t.height, t.z_index = tex, x, y, w, h, z or 0
    t.rotation, t.scale_x, t.scale_y = rotation or 0, scale_x, scale_y or scale_x
    t.origin_x, t.origin_y = origin_x, origin_y or origin_x
    t.fixed, t.tiled, t.shader = fixed == true, tiled == true, shader or 0
    t.tile_width, t.tile_height = tile_w or 0, tile_h or tile_w or 0
    t.shader_args = shader_args
    rect_table(t)
    t.shader_args = nil
    return
  end
  local q = quad
  q.tex = tex
  q.x, q.y, q.w, q.h = x, y, w, h
  q.z = z or 0
  q.rotation = rotation or 0
  q.scale_x, q.scale_y = scale_x, scale_y or scale_x
  q.origin_x, q.origin_y = origin_x, origin_y or origin_x
  q.fixed = fixed and 1 or 0
  q.tiled = tiled and 1 or 0
  q.tile_w, q.tile_h = tile_w or 0, tile_h or tile_w or 0
  q.shader = shader or 0
  c_rect_ex(q)
end

local ALIGN = { left = 0, center = 1, right = 2 }
local text_struct = ffi.new("sucata_text")
local text_args = {}

graphic.text = function(str, x, y, size, z, r, g, b, a, fixed, font, align, max_width,
                        rotation, scale_x, scale_y, origin_x, origin_y, shader, shader_args)
  if type(str) ~= "string" then
    str = tostring(str)
  end
  size = size or 16
  if r == nil and fixed == nil and font == nil and align == nil and max_width == nil and rotation == nil
    and scale_x == nil and origin_x == nil and shader == nil then
    c_text(str, #str, x, y, size, z or 0)
    return
  end
  scale_x = scale_x or 1
  origin_x = origin_x or 0
  if shader_args ~= nil then
    local t = text_args
    t.text, t.x, t.y, t.size, t.z_index = str, x, y, size, z or 0
    t.color = { r or 1, g or 1, b or 1, a or 1 }
    t.fixed = fixed == true
    t.font = font ~= nil and font_of(font) or nil
    t.align, t.max_width = align or "left", max_width or 0
    t.rotation, t.scale_x, t.scale_y = rotation or 0, scale_x, scale_y or scale_x
    t.origin_x, t.origin_y = origin_x, origin_y or origin_x
    t.shader, t.shader_args = shader or 0, shader_args
    text_table(t)
    t.shader_args = nil
    return
  end
  local t = text_struct
  t.font = font_of(font)
  t.x, t.y, t.size, t.z = x, y, size, z or 0
  t.color[0], t.color[1], t.color[2], t.color[3] = r or 1, g or 1, b or 1, a or 1
  t.opacity = -1
  t.fixed = fixed and 1 or 0
  t.align = ALIGN[align] or 0
  t.max_width = max_width or 0
  t.rotation = rotation or 0
  t.scale_x, t.scale_y = scale_x, scale_y or scale_x
  t.origin_x, t.origin_y = origin_x, origin_y or origin_x
  t.shader = shader or 0
  c_text_ex(str, #str, t)
end

local PHASES = { "init", "tick", "draw", "late", "free" }
local LAZY = { scene = "sucata.scene", events = "sucata.events", time = "sucata.time", math = "sucata.math",
  input = "sucata.input", gamepad = "sucata.gamepad" }
local SHORT = {}
for short, module in pairs(LAZY) do
  SHORT[module] = short
end

local units = {}
local registered = {}
local lists = {}
for _, phase in ipairs(PHASES) do
  lists[phase] = {}
end
local next_seq = 0

local function rebuild()
  table.sort(units, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.seq < b.seq
  end)
  for _, phase in ipairs(PHASES) do
    local fns = {}
    for i = 1, #units do
      local fn = units[i].addon[phase]
      if type(fn) == "function" then
        fns[#fns + 1] = { fn = fn, name = units[i].name, unit = units[i].addon }
      end
    end
    lists[phase] = fns
  end
end

local booted = false
local init_started = false
local inited = {}

local function call_init(entry)
  if inited[entry.unit] then
    return false
  end
  inited[entry.unit] = true
  local ok, err = xpcall(entry.fn, traceback, T.delta)
  if not ok then
    runtime.report("[" .. entry.name .. "][init]", err)
  end
  return true
end

local function load_module(name)
  local module = require(name)
  local short = SHORT[name]
  if short then
    rawset(sucata, short, module)
  end
  return module
end

local function use(addon, name)
  if type(addon) == "string" then
    name = name or addon
    addon = load_module(addon)
  end
  if type(addon) ~= "table" then
    error("sucata.use expects an addon table or module name", 2)
  end
  local unit_table = rawget(addon, "_addon") or addon
  if registered[unit_table] then
    return addon
  end
  registered[unit_table] = true
  next_seq = next_seq + 1
  local unit_name = name or unit_table.name or "addon"
  units[#units + 1] = {
    addon = unit_table,
    order = unit_table.order or 0,
    seq = next_seq,
    name = unit_name,
  }
  if booted then
    rebuild()
  end
  if init_started and type(unit_table.init) == "function" then
    call_init({ fn = unit_table.init, name = unit_name, unit = unit_table })
  end
  return addon
end

sucata.use = use

setmetatable(sucata, {
  __index = function(t, key)
    local module = LAZY[key]
    if module then
      local loaded = load_module(module)
      use(loaded, module)
      return loaded
    end
  end,
})

local function init_runner()
  init_started = true
  local fns = lists.init
  for i = 1, #fns do
    call_init(fns[i])
  end
end

local function runner(phase)
  if phase == "init" then
    return init_runner
  end
  local where = "[" .. phase .. "]"
  return function()
    local fns = lists[phase]
    local dt = T.delta
    for i = 1, #fns do
      local entry = fns[i]
      local ok, err = xpcall(entry.fn, traceback, dt)
      if not ok then
        runtime.report("[" .. entry.name .. "]" .. where, err)
      end
    end
  end
end

sucata._boot = function(root)
  if type(root) == "table" then
    use(root, "root")
  end
  booted = true
  rebuild()
  local phases = {}
  for _, phase in ipairs(PHASES) do
    phases[phase] = runner(phase)
  end
  return phases
end
