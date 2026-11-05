local W, H = 960, 540
local N = tonumber(os.getenv("N") or "10000")
local FRAMES = tonumber(os.getenv("FRAMES") or "600")
local TEX = "src://../../assets/sucata.png"
local graphic = sucata.graphic
local NEW = graphic.rect ~= nil
local HANDLE = NEW and graphic.load_texture(TEX) or nil

sucata.window.set_vsync(0)
sucata.window.set_max_fps(0)

local fall = { tick = function(s)
  local dt = sucata.time.get_delta()
  s.y = s.y + s.speed * dt
  if s.y > H then s.y = -16 end
end }

local draw
if NEW then
  draw = { draw = function(s) graphic.rect(HANDLE, s.x, s.y, 16, 16, 1) end }
else
  draw = { draw = function(s)
    graphic.draw_rect({ texture = TEX, x = s.x, y = s.y, width = 16, height = 16, z_index = 1 })
  end }
end

local clock = os.clock
local CLOCK = "cpu"
if jit and os.getenv("BENCH_CLOCK") ~= "cpu" then
  local ffi = require("ffi")
  ffi.cdef [[
    typedef struct { long tv_sec; long tv_nsec; } bench_timespec;
    int clock_gettime(int clk_id, bench_timespec *tp);
  ]]
  local MONOTONIC = ffi.os == "OSX" and 6 or 1
  local ts = ffi.new("bench_timespec")
  if ffi.os ~= "Windows" then
    clock = function()
      ffi.C.clock_gettime(MONOTONIC, ts)
      return tonumber(ts.tv_sec) + tonumber(ts.tv_nsec) * 1e-9
    end
    CLOCK = "wall"
  end
end
local jit_info = "off"
local traces, aborts, abort_at = 0, 0, {}
if jit then
  local status = { jit.status() }
  jit_info = (status[1] and "on" or "off") .. " " .. jit.arch .. " " .. table.concat(status, " ", 2)
  if os.getenv("BENCH_JIT") == "1" then
    local util = require("jit.util")
    jit.attach(function(what, tr, func, pc, otr, oex)
      if what == "stop" then
        traces = traces + 1
      elseif what == "abort" then
        aborts = aborts + 1
        local info = util.funcinfo(func, pc)
        local key = tostring(info.loc) .. " erro=" .. tostring(otr)
        abort_at[key] = (abort_at[key] or 0) + 1
      end
    end, "trace")
  end
end

local tick_start, draw_start = 0, 0
local ticks, draws, frame_times = {}, {}, {}
local probe_first = {
  tick = function() ticks[#ticks + 1] = clock() - tick_start end,
  draw = function() draw_start = clock() end,
}
local probe_last = {
  tick = function() tick_start = clock() end,
  draw = function() draws[#draws + 1] = clock() - draw_start end,
}

sucata.scene.spawn({ state = {}, behaviours = { probe_first } })
for i = 1, N do
  sucata.scene.spawn({
    state = { x = math.random(0, W), y = math.random(0, H), speed = math.random(60, 140) },
    behaviours = { fall, draw },
  })
end
sucata.scene.spawn({ state = {}, behaviours = { probe_last } })

local frames, last, lua_peak = 0, nil, 0

local function median(t)
  table.sort(t)
  return t[math.floor(#t / 2) + 1] * 1000
end

return {
  tick = function()
    local now = os.clock()
    if last and frames > 30 then frame_times[#frame_times + 1] = now - last end
    last = now
    frames = frames + 1
    if frames == FRAMES then
      print(string.format("RESULT versao=%s relogio=%s entidades=%d tick_ms=%.3f draw_ms=%.3f frame_ms=%.3f lua_kb_pico=%.0f",
        sucata.meta.VERSION, CLOCK, N, median(ticks), median(draws), median(frame_times), lua_peak))
      print("JIT " .. jit_info)
      if os.getenv("BENCH_JIT") == "1" then
        print(string.format("JIT traces=%d aborts=%d", traces, aborts))
        local list = {}
        for key, count in pairs(abort_at) do list[#list + 1] = { key, count } end
        table.sort(list, function(x, y) return x[2] > y[2] end)
        for i = 1, math.min(8, #list) do print("JIT abort " .. list[i][2] .. "x " .. list[i][1]) end
      end
      sucata.window.quit()
    end
  end,
  draw = function()
    local kb = collectgarbage("count")
    if kb > lua_peak then lua_peak = kb end
  end,
}
