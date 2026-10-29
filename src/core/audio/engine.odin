package audio_engine

import "../../filesystem"
import "base:runtime"
import "core:c"
import "core:strings"
import ma "vendor:miniaudio"

Sound :: struct {
	id:      u32,
	group:   string,
	decoder: ma.decoder,
	sound:   ma.sound,
	volume:  f32,
	pitch:   f32,
	looping: bool,
	paused:  bool,
}

AudioGroup :: struct {
	handle: ^ma.sound_group,
	volume: f32,
	pitch:  f32,
}

engine: ma.engine
engine_ready: bool
groups: map[string]AudioGroup
sounds: map[u32]^Sound
next_id: u32 = 1

engine_context: runtime.Context

init :: proc() -> bool {
	engine_context = context

	if ma.engine_init(nil, &engine) != .SUCCESS {
		return false
	}

	engine_ready = true
	create_audio_group("default")
	return true
}

create_audio_group :: proc(group: string) -> (^AudioGroup, bool) {
	if g, exists := &groups[group]; exists {
		return g, true
	}

	handle := new(ma.sound_group)
	if ma.sound_group_init(&engine, {}, nil, handle) != .SUCCESS {
		free(handle)
		return nil, false
	}

	key := strings.clone(group)
	groups[key] = AudioGroup {
		handle = handle,
		volume = 1.0,
		pitch  = 1.0,
	}
	return &groups[key], true
}

destroy_sound :: proc(s: ^Sound) {
	ma.sound_uninit(&s.sound)
	ma.decoder_uninit(&s.decoder)
	delete(s.group)
	free(s)
}

shutdown :: proc() {
	if !engine_ready {
		return
	}

	for _, s in sounds {
		destroy_sound(s)
	}
	delete(sounds)
	sounds = {}

	for key, g in groups {
		ma.sound_group_uninit(g.handle)
		free(g.handle)
		delete(key)
	}
	delete(groups)
	groups = {}

	ma.engine_uninit(&engine)
	engine_ready = false
}

update :: proc() {
	finished := make([dynamic]u32, context.temp_allocator)

	for id, s in sounds {
		if !s.paused && !s.looping && bool(ma.sound_at_end(&s.sound)) {
			append(&finished, id)
		}
	}

	for id in finished {
		destroy_sound(sounds[id])
		delete_key(&sounds, id)
	}
}

group_pitch :: proc(group: string) -> f32 {
	if g, ok := groups[group]; ok {
		return g.pitch
	}
	return 1.0
}

apply_pitch :: proc(s: ^Sound) {
	ma.sound_set_pitch(&s.sound, s.pitch * group_pitch(s.group))
}

load_sound :: proc(sound_path: string, group: string = "default") -> (u32, bool) {
	if !engine_ready {
		return 0, false
	}

	asset_data, asset_ok := filesystem.get_asset(sound_path)
	if !asset_ok || len(asset_data) == 0 {
		return 0, false
	}

	audio_group, group_ok := create_audio_group(group)
	if !group_ok {
		return 0, false
	}

	s := new(Sound)

	if ma.decoder_init_memory(raw_data(asset_data), c.size_t(len(asset_data)), nil, &s.decoder) != .SUCCESS {
		free(s)
		return 0, false
	}

	if ma.sound_init_from_data_source(
		   &engine,
		   (^ma.data_source)(&s.decoder),
		   {.NO_SPATIALIZATION},
		   audio_group.handle,
		   &s.sound,
	   ) !=
	   .SUCCESS {
		ma.decoder_uninit(&s.decoder)
		free(s)
		return 0, false
	}

	s.id = next_id
	s.group = strings.clone(group)
	s.volume = 1.0
	s.pitch = 1.0
	next_id += 1

	sounds[s.id] = s
	return s.id, true
}

find_sound :: proc(id: u32) -> (^Sound, bool) {
	s, ok := sounds[id]
	return s, ok
}

play_sound :: proc(id: u32, volume: f32 = 1.0, pitch: f32 = 1.0, loop: b32 = false) {
	s, ok := find_sound(id)
	if !ok {
		return
	}

	s.volume = volume
	s.pitch = pitch
	s.looping = bool(loop)
	s.paused = false

	ma.sound_set_volume(&s.sound, volume)
	apply_pitch(s)
	ma.sound_set_looping(&s.sound, loop)
	ma.sound_seek_to_pcm_frame(&s.sound, 0)
	ma.sound_start(&s.sound)
}

unpause_sound :: proc(id: u32) {
	s, ok := find_sound(id)
	if !ok {
		return
	}
	s.paused = false
	ma.sound_start(&s.sound)
}

pause_sound :: proc(id: u32) {
	s, ok := find_sound(id)
	if !ok {
		return
	}
	s.paused = true
	ma.sound_stop(&s.sound)
}

stop_sound :: proc(id: u32) {
	s, ok := find_sound(id)
	if !ok {
		return
	}
	destroy_sound(s)
	delete_key(&sounds, id)
}

set_sound_volume :: proc(id: u32, volume: f32) {
	s, ok := find_sound(id)
	if !ok {
		return
	}
	s.volume = volume
	ma.sound_set_volume(&s.sound, volume)
}

get_sound_volume :: proc(id: u32) -> f32 {
	s, ok := find_sound(id)
	if !ok {
		return 0.0
	}
	return s.volume
}

set_sound_pitch :: proc(id: u32, pitch: f32) {
	s, ok := find_sound(id)
	if !ok {
		return
	}
	s.pitch = pitch
	apply_pitch(s)
}

get_sound_pitch :: proc(id: u32) -> f32 {
	s, ok := find_sound(id)
	if !ok {
		return 0.0
	}
	return s.pitch
}

set_group_volume :: proc(group: string, volume: f32) {
	g, ok := &groups[group]
	if !ok {
		return
	}
	g.volume = volume
	ma.sound_group_set_volume(g.handle, volume)
}

get_group_volume :: proc(group: string) -> f32 {
	g, ok := groups[group]
	if !ok {
		return 0.0
	}
	return g.volume
}

set_group_pitch :: proc(group: string, pitch: f32) {
	g, ok := &groups[group]
	if !ok {
		return
	}
	g.pitch = pitch

	for _, s in sounds {
		if s.group == group {
			apply_pitch(s)
		}
	}
}

get_group_pitch :: proc(group: string) -> f32 {
	g, ok := groups[group]
	if !ok {
		return 0.0
	}
	return g.pitch
}
