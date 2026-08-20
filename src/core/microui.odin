package core

import "../common"
import "core:unicode/utf8"
import sapp "shared:sokol/app"
import sg "shared:sokol/gfx"
import sgl "shared:sokol/gl"
import shelpers "shared:sokol/helpers"
import mu "vendor:microui"

mu_ctx: mu.Context

mu_root_open: bool
mu_open_container_depth: int

mu_bool_state: map[string]^bool
mu_real_state: map[string]^mu.Real

MU_TEXTBOX_CAPACITY :: 256
Mu_Textbox_State :: struct {
	buf: [MU_TEXTBOX_CAPACITY]u8,
	len: int,
}
mu_text_state: map[string]^Mu_Textbox_State

mu_atlas_image: sg.Image
mu_atlas_view: sg.View
mu_atlas_sampler: sg.Sampler
mu_pipeline: sgl.Pipeline

init_microui :: proc() {
	mu.init(&mu_ctx)
	mu_ctx.text_width = microui_text_width
	mu_ctx.text_height = microui_text_height

	sgl.setup(
		{
			logger = sgl.Logger(shelpers.logger(&DEFAULT_CONTEXT)),
			allocator = sgl.Allocator(shelpers.allocator(&DEFAULT_CONTEXT)),
		},
	)

	microui_upload_atlas()

	mu_pipeline = sgl.make_pipeline(
		{
			colors = {
				0 = {
					blend = {
						enabled = true,
						src_factor_rgb = .SRC_ALPHA,
						dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
						src_factor_alpha = .ONE,
						dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
						op_rgb = .ADD,
						op_alpha = .ADD,
					},
				},
			},
		},
	)
}

microui_upload_atlas :: proc() {
	pixel_count := mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT
	atlas_rgba := make([]u8, pixel_count * 4)
	defer delete(atlas_rgba)

	for alpha, i in mu.default_atlas_alpha {
		atlas_rgba[i * 4 + 0] = 255
		atlas_rgba[i * 4 + 1] = 255
		atlas_rgba[i * 4 + 2] = 255
		atlas_rgba[i * 4 + 3] = alpha
	}

	mu_atlas_image = sg.make_image(
		{
			width = mu.DEFAULT_ATLAS_WIDTH,
			height = mu.DEFAULT_ATLAS_HEIGHT,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = {ptr = &atlas_rgba[0], size = uint(len(atlas_rgba))}}},
		},
	)
	mu_atlas_view = sg.make_view({texture = {image = mu_atlas_image}})
	mu_atlas_sampler = sg.make_sampler(
		{
			min_filter = .NEAREST,
			mag_filter = .NEAREST,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
		},
	)
}

shutdown_microui :: proc() {
	for _, ptr in mu_bool_state do free(ptr)
	delete(mu_bool_state)

	for _, ptr in mu_real_state do free(ptr)
	delete(mu_real_state)

	for _, ptr in mu_text_state do free(ptr)
	delete(mu_text_state)

	sgl.destroy_pipeline(mu_pipeline)

	sg.destroy_sampler(mu_atlas_sampler)
	sg.destroy_view(mu_atlas_view)
	sg.destroy_image(mu_atlas_image)

	sgl.shutdown()
}

microui_begin_frame :: proc() {
	mu.begin(&mu_ctx)
}

microui_end_frame :: proc() {
	if mu_root_open {
		mu.end_window(&mu_ctx)
		mu_root_open = false
	}
	mu.end(&mu_ctx)
}

microui_guard_draw_step :: proc() -> bool {
	if !is_draw_step {
		common.print_error("sucata.ui: draw_* functions can only be called inside a behaviour's draw(state) function")
		return false
	}
	return true
}

microui_ensure_root :: proc() {
	if mu_open_container_depth > 0 || mu_root_open {
		return
	}
	if microui_root_begin() {
		mu_root_open = true
	}
}

microui_render :: proc(width, height: f32) {
	sgl.push_pipeline()
	sgl.load_pipeline(mu_pipeline)

	sgl.viewport(0, 0, i32(width), i32(height), true)
	sgl.matrix_mode_projection()
	sgl.load_identity()
	sgl.ortho(0, width, height, 0, -1, 1)
	sgl.matrix_mode_modelview()
	sgl.load_identity()

	sgl.enable_texture()
	sgl.texture(mu_atlas_view, mu_atlas_sampler)
	sgl.scissor_rect(0, 0, i32(width), i32(height), true)

	cmd: ^mu.Command
	for mu.next_command(&mu_ctx, &cmd) {
		#partial switch v in cmd.variant {
		case ^mu.Command_Rect:
			microui_draw_atlas_rect(v.rect, mu.default_atlas[mu.DEFAULT_ATLAS_WHITE], v.color)

		case ^mu.Command_Text:
			microui_draw_text(v.str, v.pos, v.color, microui_scale_from_font(v.font))

		case ^mu.Command_Icon:
			microui_draw_icon(v.id, v.rect, v.color)

		case ^mu.Command_Clip:
			sgl.scissor_rect(v.rect.x, v.rect.y, v.rect.w, v.rect.h, true)
		}
	}

	sgl.scissor_rect(0, 0, i32(width), i32(height), true)
	sgl.disable_texture()

	sgl.pop_pipeline()

	sgl.draw()
}

microui_draw_atlas_rect :: proc(dst: mu.Rect, src: mu.Rect, color: mu.Color) {
	u0 := f32(src.x) / mu.DEFAULT_ATLAS_WIDTH
	v0 := f32(src.y) / mu.DEFAULT_ATLAS_HEIGHT
	u1 := f32(src.x + src.w) / mu.DEFAULT_ATLAS_WIDTH
	v1 := f32(src.y + src.h) / mu.DEFAULT_ATLAS_HEIGHT

	x0 := f32(dst.x)
	y0 := f32(dst.y)
	x1 := f32(dst.x + dst.w)
	y1 := f32(dst.y + dst.h)

	sgl.begin_quads()
	sgl.v2f_t2f_c4b(x0, y0, u0, v0, color.r, color.g, color.b, color.a)
	sgl.v2f_t2f_c4b(x1, y0, u1, v0, color.r, color.g, color.b, color.a)
	sgl.v2f_t2f_c4b(x1, y1, u1, v1, color.r, color.g, color.b, color.a)
	sgl.v2f_t2f_c4b(x0, y1, u0, v1, color.r, color.g, color.b, color.a)
	sgl.end()
}

microui_draw_text :: proc(text: string, pos: mu.Vec2, color: mu.Color, scale: f32 = 1.0) {
	dst_pos := pos
	for ch in text {
		r := min(int(ch), 127)
		src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
		w := i32(f32(src.w) * scale)
		h := i32(f32(src.h) * scale)
		microui_draw_atlas_rect(mu.Rect{dst_pos.x, dst_pos.y, w, h}, src, color)
		dst_pos.x += w
	}
}

microui_draw_icon :: proc(id: mu.Icon, rect: mu.Rect, color: mu.Color) {
	src := mu.default_atlas[int(id)]
	x := rect.x + (rect.w - src.w) / 2
	y := rect.y + (rect.h - src.h) / 2
	microui_draw_atlas_rect(mu.Rect{x, y, src.w, src.h}, src, color)
}

microui_handle_event :: proc(event: ^sapp.Event) {
	#partial switch event.type {
	case .MOUSE_MOVE:
		mu.input_mouse_move(&mu_ctx, i32(event.mouse_x), i32(event.mouse_y))

	case .MOUSE_DOWN:
		btn := microui_mouse_button(event.mouse_button)
		if btn, ok := btn.?; ok {
			mu.input_mouse_down(&mu_ctx, i32(event.mouse_x), i32(event.mouse_y), btn)
		}

	case .MOUSE_UP:
		btn := microui_mouse_button(event.mouse_button)
		if btn, ok := btn.?; ok {
			mu.input_mouse_up(&mu_ctx, i32(event.mouse_x), i32(event.mouse_y), btn)
		}

	case .MOUSE_SCROLL:
		mu.input_scroll(&mu_ctx, i32(event.scroll_x), i32(-event.scroll_y))

	case .KEY_DOWN:
		key := microui_key(event.key_code)
		if key, ok := key.?; ok {
			mu.input_key_down(&mu_ctx, key)
		}

	case .KEY_UP:
		key := microui_key(event.key_code)
		if key, ok := key.?; ok {
			mu.input_key_up(&mu_ctx, key)
		}

	case .CHAR:
		buf, n := utf8.encode_rune(rune(event.char_code))
		mu.input_text(&mu_ctx, string(buf[:n]))
	}
}

microui_mouse_button :: proc(btn: sapp.Mousebutton) -> Maybe(mu.Mouse) {
	#partial switch btn {
	case .LEFT:
		return .LEFT
	case .RIGHT:
		return .RIGHT
	case .MIDDLE:
		return .MIDDLE
	}
	return nil
}

MU_DEFAULT_TEXT_HEIGHT :: 18 
MU_FONT_SCALE_FIXED_POINT :: 1000

Mu_Style :: struct {
	x, y, width, height: Maybe(f32),
	text_size:           Maybe(f32),
	color:               Maybe(mu.Color),
	background_color:    Maybe(mu.Color),
	border_color:        Maybe(mu.Color),
}

microui_font_for_scale :: proc(scale: f32) -> mu.Font {
	return mu.Font(uintptr(max(1, i32(scale * MU_FONT_SCALE_FIXED_POINT))))
}

microui_scale_from_font :: proc(font: mu.Font) -> f32 {
	v := uintptr(font)
	if v == 0 do return 1.0
	return f32(v) / MU_FONT_SCALE_FIXED_POINT
}

microui_text_width :: proc(font: mu.Font, text: string) -> i32 {
	scale := microui_scale_from_font(font)
	return i32(f32(mu.default_atlas_text_width(font, text)) * scale)
}

microui_text_height :: proc(font: mu.Font) -> i32 {
	scale := microui_scale_from_font(font)
	return i32(f32(MU_DEFAULT_TEXT_HEIGHT) * scale)
}

microui_lighten :: proc(c: mu.Color, amount: int) -> mu.Color {
	return mu.Color {
		u8(clamp(int(c.r) + amount, 0, 255)),
		u8(clamp(int(c.g) + amount, 0, 255)),
		u8(clamp(int(c.b) + amount, 0, 255)),
		c.a,
	}
}

microui_apply_style :: proc(style: Mu_Style) -> mu.Style {
	backup := mu_ctx.style^

	x, xok := style.x.?
	y, yok := style.y.?
	w, wok := style.width.?
	h, hok := style.height.?
	if xok && yok && wok && hok {
		mu.layout_set_next(&mu_ctx, mu.Rect{i32(x), i32(y), i32(w), i32(h)}, false)
	}

	if ts, ok := style.text_size.?; ok {
		mu_ctx.style.font = microui_font_for_scale(ts / MU_DEFAULT_TEXT_HEIGHT)
	}

	if c, ok := style.color.?; ok {
		mu_ctx.style.colors[.TEXT] = c
	}

	if bg, ok := style.background_color.?; ok {
		mu_ctx.style.colors[.BUTTON] = bg
		mu_ctx.style.colors[.BUTTON_HOVER] = microui_lighten(bg, 20)
		mu_ctx.style.colors[.BUTTON_FOCUS] = microui_lighten(bg, 40)
		mu_ctx.style.colors[.BASE] = bg
		mu_ctx.style.colors[.BASE_HOVER] = microui_lighten(bg, 5)
		mu_ctx.style.colors[.BASE_FOCUS] = microui_lighten(bg, 10)
	}

	if bc, ok := style.border_color.?; ok {
		mu_ctx.style.colors[.BORDER] = bc
	}

	return backup
}

microui_restore_style :: proc(backup: mu.Style) {
	mu_ctx.style^ = backup
}

microui_window_begin :: proc(
	title: string,
	x, y, width, height: f32,
	transparent := false,
	movable := true,
	resizable := true,
	color: Maybe(mu.Color) = nil,
	background_color: Maybe(mu.Color) = nil,
	border_color: Maybe(mu.Color) = nil,
) -> bool {
	if !microui_guard_draw_step() do return false

	opt: mu.Options = {}
	if transparent do opt += {.NO_FRAME}
	if !resizable do opt += {.NO_RESIZE}

	backup := mu_ctx.style^
	if c, ok := color.?; ok {
		mu_ctx.style.colors[.TEXT] = c
		mu_ctx.style.colors[.TITLE_TEXT] = c
	}
	if bg, ok := background_color.?; ok {
		mu_ctx.style.colors[.WINDOW_BG] = bg
	}
	if bc, ok := border_color.?; ok {
		mu_ctx.style.colors[.BORDER] = bc
	}

	open := mu.begin_window(&mu_ctx, title, mu.Rect{i32(x), i32(y), i32(width), i32(height)}, opt)
	mu_ctx.style^ = backup

	if open {
		mu_open_container_depth += 1

		if !movable {
			cnt := mu.get_current_container(&mu_ctx)
			cnt.rect.x = i32(x)
			cnt.rect.y = i32(y)
		}
	}

	return open
}

microui_window_end :: proc() {
	if !microui_guard_draw_step() do return

	mu.end_window(&mu_ctx)
	mu_open_container_depth -= 1
}

MU_ROOT_ID :: "__sucata_ui_root__"

microui_root_begin :: proc() -> bool {
	width := f32(sapp.width())
	height := f32(sapp.height())

	open := mu.begin_window(
		&mu_ctx,
		MU_ROOT_ID,
		mu.Rect{0, 0, i32(width), i32(height)},
		{.NO_TITLE, .NO_RESIZE, .NO_SCROLL, .NO_CLOSE, .NO_FRAME},
	)

	if open {
		cnt := mu.get_current_container(&mu_ctx)
		cnt.rect = mu.Rect{0, 0, i32(width), i32(height)}
		cnt.zindex = 0
	}

	return open
}

microui_popup_open :: proc(name: string) {
	if !microui_guard_draw_step() do return
	mu.open_popup(&mu_ctx, name)
}

microui_popup_begin :: proc(name: string) -> bool {
	if !microui_guard_draw_step() do return false

	open := mu.begin_popup(&mu_ctx, name)
	if open {
		mu_open_container_depth += 1
	}
	return open
}

microui_label :: proc(text: string, style: Mu_Style = {}) {
	if !microui_guard_draw_step() do return
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	mu.layout_row(&mu_ctx, {-1}, mu_ctx.text_height(mu_ctx.style.font))
	mu.label(&mu_ctx, text)
}

microui_text :: proc(text: string, style: Mu_Style = {}) {
	if !microui_guard_draw_step() do return
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	mu.text(&mu_ctx, text)
}

microui_button :: proc(text: string, style: Mu_Style = {}) -> bool {
	if !microui_guard_draw_step() do return false
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	return .SUBMIT in mu.button(&mu_ctx, text)
}

microui_checkbox :: proc(id: string, label: string, style: Mu_Style = {}) -> (changed: bool, state: bool) {
	if !microui_guard_draw_step() do return
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	ptr, ok := mu_bool_state[id]
	if !ok {
		ptr = new(bool)
		mu_bool_state[id] = ptr
	}

	res := mu.checkbox(&mu_ctx, label, ptr)
	changed = .CHANGE in res
	state = ptr^
	return
}

microui_slider :: proc(
	id: string,
	initial, low, high, step: f32,
	style: Mu_Style = {},
) -> (
	changed: bool,
	value: f32,
) {
	if !microui_guard_draw_step() do return
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	ptr, ok := mu_real_state[id]
	if !ok {
		ptr = new(mu.Real)
		ptr^ = initial
		mu_real_state[id] = ptr
	}

	res := mu.slider(&mu_ctx, ptr, low, high, step)
	changed = .CHANGE in res
	value = ptr^
	return
}

microui_textbox :: proc(
	id: string,
	initial: string,
	style: Mu_Style = {},
) -> (
	changed: bool,
	submitted: bool,
	text: string,
) {
	if !microui_guard_draw_step() do return
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	st, ok := mu_text_state[id]
	if !ok {
		st = new(Mu_Textbox_State)
		st.len = copy(st.buf[:], initial)
		mu_text_state[id] = st
	}

	res := mu.textbox(&mu_ctx, st.buf[:], &st.len)
	changed = .CHANGE in res
	submitted = .SUBMIT in res
	text = string(st.buf[:st.len])
	return
}

microui_header :: proc(text: string, expanded: bool = false, style: Mu_Style = {}) -> bool {
	if !microui_guard_draw_step() do return false
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	opt: mu.Options = {}
	if expanded do opt += {.EXPANDED}

	return .ACTIVE in mu.header(&mu_ctx, text, opt)
}

microui_treenode_begin :: proc(text: string, expanded: bool = false, style: Mu_Style = {}) -> bool {
	if !microui_guard_draw_step() do return false
	microui_ensure_root()

	backup := microui_apply_style(style)
	defer microui_restore_style(backup)

	opt: mu.Options = {}
	if expanded do opt += {.EXPANDED}

	return .ACTIVE in mu.begin_treenode(&mu_ctx, text, opt)
}

microui_treenode_end :: proc() {
	if !microui_guard_draw_step() do return
	mu.end_treenode(&mu_ctx)
}

microui_layout_row :: proc(widths: []i32, height: i32 = 0) {
	if !microui_guard_draw_step() do return
	microui_ensure_root()

	mu.layout_row(&mu_ctx, widths, height)
}

microui_layout_begin_column :: proc() {
	if !microui_guard_draw_step() do return
	microui_ensure_root()

	mu.layout_begin_column(&mu_ctx)
}

microui_layout_end_column :: proc() {
	if !microui_guard_draw_step() do return
	mu.layout_end_column(&mu_ctx)
}

microui_key :: proc(key: sapp.Keycode) -> Maybe(mu.Key) {
	#partial switch key {
	case .LEFT_SHIFT, .RIGHT_SHIFT:
		return .SHIFT
	case .LEFT_CONTROL, .RIGHT_CONTROL:
		return .CTRL
	case .LEFT_ALT, .RIGHT_ALT:
		return .ALT
	case .BACKSPACE:
		return .BACKSPACE
	case .DELETE:
		return .DELETE
	case .ENTER:
		return .RETURN
	case .LEFT:
		return .LEFT
	case .RIGHT:
		return .RIGHT
	case .HOME:
		return .HOME
	case .END:
		return .END
	case .A:
		return .A
	case .X:
		return .X
	case .C:
		return .C
	case .V:
		return .V
	}
	return nil
}
