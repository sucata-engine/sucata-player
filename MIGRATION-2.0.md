# Sucata 2.0 — LuaJIT, FFI e cenas como addon

## O que mudou no core

- Lua 5.4 foi trocado por **LuaJIT 2.1** (`src/luajit/`, binding derivado de `vendor:lua/5.1`).
- Removidos do Odin: cenas, entidades, behaviours, tags, globals, fila de destruição e eventos
  (`src/lua/scene`, `src/lua/events`, `core/entity|behaviour|game_object|tags|events|root.odin`).
- O core agora chama **uma função Lua por fase por frame**: `init`, `tick`, `draw`, `late`, `free`
  (`core/phases.odin`).
- Runtime Lua embutido no binário com `#load` (`src/lua/runtime/`):
  - `prelude.lua`: camada FFI, compositor de addons, `sucata.use`, polyfills 5.2+/5.4.
  - `scene.lua`: `sucata.scene` (mesma API de antes), registrado como addon `order = 100`.
  - `events.lua`: `sucata.events` (`on`, `emit`, novo `off`).
  - `time.lua`: `sucata.time` (delta, fps, time scale e timers, com `resume_timer` novo), addon `order = -1000`.
  - `math.lua`: `sucata.math` (mesmas funções de antes, em Lua puro).
  - `input.lua`: `sucata.input`, todo via FFI (teclado, mouse, scroll, `get_key`, `is_hover`).
  - `gamepad.lua`: `sucata.gamepad`, todo via FFI (botões, eixos, contagem; `get_info` continua pela API C).
- `sucata.scene`, `sucata.events`, `sucata.time`, `sucata.math`, `sucata.input` e `sucata.gamepad` são carregados sob demanda no primeiro acesso.
- `sucata.dynlib` foi removido: use `ffi.load` e `ffi.cdef` do LuaJIT. O `ffi.load` aceita `src://`, `data://` e `build://` e completa a extensão (`.so`, `.dylib`, `.dll`) se faltar.
- O painel de debug não mostra mais a contagem de entidades (use `sucata.scene.count()`).

## FFI

O Odin expõe uma struct `Ffi_Api` (`core/ffi.odin`) como lightuserdata em `sucata._ffi`.
O prelude faz `ffi.cast` nela e valida o layout comparando `ffi.sizeof` com `size_of` do Odin.

| Caminho quente | Como funciona agora |
|---|---|
| `sucata.time.get_delta()` | leitura direta de `Ffi_Time.delta` |
| `sucata.input.*` | leitura direta de `InputState` e `Ffi_Mouse`; mouse relativo usa a câmera compartilhada |
| `sucata.gamepad.*` | leitura direta de `Ffi_Gamepad` (8 slots), sincronizado uma vez por frame |
| `sucata.graphic.rect(...)` | chamada FFI, sem tabela; substitui `draw_rect` |
| `sucata.graphic.text(...)` | chamada FFI, sem tabela; substitui `draw_text` |
| `sucata.graphic.load_texture(path)` / `load_font(path)` | devolvem um handle inteiro |

`draw_rect` e `draw_text` foram removidos. Tudo é por parâmetro, e os parâmetros finais são opcionais:

```lua
sucata.graphic.rect(tex, x, y, w, h, z,
  rotation, scale_x, scale_y, origin_x, origin_y,
  r, g, b, a, fixed,
  atlas_x, atlas_y, atlas_w, atlas_h, atlas_spacing, atlas_margin,
  tiled, tile_w, tile_h,
  shader, shader_args)

sucata.graphic.text(str, x, y, size, z,
  r, g, b, a, fixed,
  font, align, max_width,
  rotation, scale_x, scale_y, origin_x, origin_y,
  shader, shader_args)
```

- `tex` e `font` aceitam handle, caminho (`"src://..."`, guardado em cache) ou `nil` (sem textura / fonte padrão).
- Padrões: `z = 0`, `rotation = 0`, `scale_y = scale_x = 1`, `origin_y = origin_x = 0`, cor branca, `atlas_h = atlas_w`,
  `tile_h = tile_w`, `size = 16`, `align = "left"`.
- Só com os 6 primeiros parâmetros (`rect`) ou 5 (`text`), a chamada vai direto pro C. Com mais, os valores são
  copiados para uma struct FFI reaproveitada, também sem lixo.
- `shader_args` é o único parâmetro que é tabela; quando presente, a chamada usa o caminho antigo pela API C.

## Addons

```lua
return {
  addons = { "sucata.scene", require("addons.tween") },
  init = function() end,
  tick = function(dt) end,
  draw = function() end,
  late = function() end,
  free = function() end,
}
```

- Um addon é uma tabela com `order` (padrão `0`) e as fases que quiser.
- Ordem: `order` menor primeiro, empate pela ordem de registro. O root tem `order = 0`, o scene `100`.
- `sucata.use(addon)` registra um addon a qualquer momento.
- Erros são isolados por addon e, no scene, por entidade (o loop continua na entidade seguinte).

## Mudanças que podem quebrar jogos

- `sucata.input.is_hover` agora é posicional: `is_hover(id, x, y, w, h, z, fixed)` (antes recebia uma tabela).
- `sucata.gamepad.is_connected(slot)` é novo.
- Behaviours recebem `tick(state, dt)`; o root recebe `tick(dt)`. Código antigo continua funcionando.
- Sintaxe só do Lua 5.3/5.4 não existe no LuaJIT: `//`, `&`, `|`, `~`, `<<`, `>>`, `<const>`, `<close>`.
  Use `math.floor(a / b)` e a lib `bit`. `goto` continua funcionando.
- Não há subtipo inteiro: todo número é double.
- Polyfills incluídos: `table.unpack`, `table.pack`, `math.type`, `math.tointeger`, `math.maxinteger`, `math.mininteger`.
- `sucata.dynlib` não existe mais; troque por `local lib = ffi.load("caminho")` + `ffi.cdef`.
- Use o `sucata-cli` da branch `feat/luajit-2.0`: ele gera bytecode do LuaJIT e distribui `lua51.dll` no Windows.

## Setup

```sh
./scripts/install-shared/unix.sh
./scripts/install-luajit/unix.sh
./scripts/build-release/unix.sh
```

No Windows, rode `scripts\install-luajit\win.cmd` num "x64 Native Tools Command Prompt for VS".
Ele gera `src\luajit\lib\windows\lua51.lib` e copia `lua51.dll` para a raiz.

## Benchmark (Linux x86_64, Xvfb + llvmpipe, mediana de 150 frames)

| Entidades | Versão | tick (ms) | draw Lua (ms) | frame (ms) |
|---|---|---|---|---|
| 10.000 | 1.3.0 (Lua 5.4, `draw_rect`) | 2,52 | 12,99 | 36,4 |
| 10.000 | 2.0.0 (`draw_rect`, antes de ser removido) | 0,69 | 6,21 | 30,0 |
| 10.000 | 2.0.0 (`rect`) | 1,15 | 1,12 | 21,8 |
| 20.000 | 1.3.0 (Lua 5.4, `draw_rect`) | 5,55 | 28,75 | 59,3 |
| 20.000 | 2.0.0 (`rect`) | 2,16 | 2,23 | 24,6 |

O frame inclui renderização por software (llvmpipe), que não mudou; numa GPU real a parte Lua pesa mais
no total. RSS máximo ficou praticamente igual (~161–165 MB em 20k entidades).
