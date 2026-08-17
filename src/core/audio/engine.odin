package audio_engine

import "../../filesystem"
import "base:runtime"
import "core:c"
import "core:strings"
import "core:sync"
import saudio "shared:sokol/audio"

Sound :: struct {
	id:           u32,
	group:        string,
	is_valid:     bool,
	is_playing:   bool,
	is_looping:   bool,
	reached_end:  bool,
	volume:       f32,
	pitch:        f32,
	samples:      []f32,
	channels:     int,
	sample_rate:  int,
	frame_cursor: f64,
}

AudioGroup :: struct {
	volume: f32,
	pitch:  f32,
}

AudioMixer :: struct {
	groups:  map[string]AudioGroup,
	sounds:  [dynamic]Sound,
	next_id: u32,
	mutex:   sync.Mutex,
}

mixer := AudioMixer{}

device_channels: int
device_sample_rate: int

engine_context: runtime.Context

free_sound_data :: proc(s: ^Sound) {
	if s.samples != nil {
		delete(s.samples)
		s.samples = nil
	}
	delete(s.group)
	s.group = ""
}

sample_at :: proc(s: ^Sound, frame: int, out_ch: int) -> f32 {
	if s.channels == device_channels {
		return s.samples[frame * s.channels + out_ch]
	}
	if s.channels == 1 {
		return s.samples[frame]
	}
	if device_channels == 1 {
		sum: f32 = 0
		for ch in 0 ..< s.channels {
			sum += s.samples[frame * s.channels + ch]
		}
		return sum / f32(s.channels)
	}
	ch := min(out_ch, s.channels - 1)
	return s.samples[frame * s.channels + ch]
}

stream_callback :: proc "c" (
	buffer: ^f32,
	num_frames: c.int,
	num_channels: c.int,
	user_data: rawptr,
) {
	context = engine_context

	buf := ([^]f32)(buffer)
	num_samples := int(num_frames) * int(num_channels)
	for i in 0 ..< num_samples {
		buf[i] = 0.0
	}

	sync.mutex_lock(&mixer.mutex)

	for &s in mixer.sounds {
		if !s.is_valid || !s.is_playing || s.channels == 0 || len(s.samples) == 0 {
			continue
		}

		source_frame_count := len(s.samples) / s.channels
		if source_frame_count == 0 {
			continue
		}

		group_volume: f32 = 1.0
		group_pitch: f32 = 1.0
		if g, ok := mixer.groups[s.group]; ok {
			group_volume = g.volume
			group_pitch = g.pitch
		}

		final_volume := s.volume * group_volume
		rate_ratio := f64(s.sample_rate) / f64(device_sample_rate) * f64(s.pitch * group_pitch)

		for frame_idx in 0 ..< int(num_frames) {
			for s.frame_cursor >= f64(source_frame_count) {
				if s.is_looping {
					s.frame_cursor -= f64(source_frame_count)
				} else {
					s.is_playing = false
					s.reached_end = true
					break
				}
			}
			if !s.is_playing {
				break
			}

			frame0 := int(s.frame_cursor)
			frac := f32(s.frame_cursor - f64(frame0))
			frame1 := frame0 + 1
			if frame1 >= source_frame_count {
				frame1 = s.is_looping ? 0 : frame0
			}

			for out_ch in 0 ..< int(num_channels) {
				v0 := sample_at(&s, frame0, out_ch)
				v1 := sample_at(&s, frame1, out_ch)
				mixed := (v0 + (v1 - v0) * frac) * final_volume

				out_index := frame_idx * int(num_channels) + out_ch
				buf[out_index] += mixed
			}

			s.frame_cursor += rate_ratio
		}
	}

	sync.mutex_unlock(&mixer.mutex)

	for i in 0 ..< num_samples {
		if buf[i] > 1.0 {
			buf[i] = 1.0
		} else if buf[i] < -1.0 {
			buf[i] = -1.0
		}
	}
}

init :: proc() -> bool {
	engine_context = context

	saudio.setup(saudio.Desc{stream_userdata_cb = stream_callback, user_data = nil})

	if !saudio.isvalid() {
		return false
	}

	device_channels = int(saudio.channels())
	device_sample_rate = int(saudio.sample_rate())

	mixer.sounds = make([dynamic]Sound)
	create_audio_group("default")
	mixer.next_id = 1
	return true
}

create_audio_group :: proc(group: string) -> bool {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	if _, exists := mixer.groups[group]; exists {
		return true
	}

	audio_group := strings.clone(group)
	mixer.groups[audio_group] = AudioGroup {
		volume = 1.0,
		pitch  = 1.0,
	}

	return true
}

shutdown :: proc() {
	saudio.shutdown()

	for &s in mixer.sounds {
		if s.is_valid {
			free_sound_data(&s)
		}
	}
	delete(mixer.sounds)
	mixer.sounds = nil

	for key in mixer.groups {
		delete(key)
	}
	delete(mixer.groups)
	mixer.groups = {}
}

find_free_slot :: proc() -> (^Sound, bool) {
	for &s in mixer.sounds {
		if !s.is_valid {
			return &s, true
		}
		if s.is_valid && !s.is_playing && s.reached_end {
			free_sound_data(&s)
			s.is_valid = false
			s.reached_end = false
			return &s, true
		}
	}

	append(&mixer.sounds, Sound{})
	return &mixer.sounds[len(mixer.sounds) - 1], true
}

find_sound_by_id :: proc(id: u32) -> (^Sound, bool) {
	for &s in mixer.sounds {
		if s.is_valid && s.id == id {
			return &s, true
		}
	}
	return nil, false
}

update :: proc() {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	for &s in mixer.sounds {
		if s.is_valid && !s.is_playing && s.reached_end {
			free_sound_data(&s)
			s.is_valid = false
			s.reached_end = false
		}
	}
}

load_sound :: proc(sound_path: string, group: string = "default") -> (u32, bool) {
	context = engine_context

	asset_data, asset_ok := filesystem.get_asset(sound_path)
	if !asset_ok || len(asset_data) == 0 {
		return 0, false
	}

	samples, channels, sample_rate, decode_ok := decode_audio(asset_data)
	if !decode_ok {
		return 0, false
	}

	create_audio_group(group)

	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	slot, ok := find_free_slot()
	if !ok {
		delete(samples)
		return 0, false
	}

	slot.id = mixer.next_id
	slot.group = strings.clone(group)
	slot.is_valid = true
	slot.is_playing = false
	slot.is_looping = false
	slot.reached_end = false
	slot.volume = 1.0
	slot.pitch = 1.0
	slot.samples = samples
	slot.channels = channels
	slot.sample_rate = sample_rate
	slot.frame_cursor = 0

	mixer.next_id += 1

	return slot.id, true
}

play_sound :: proc(id: u32, volume: f32 = 1.0, pitch: f32 = 1.0, loop: b32 = false) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return
	}

	s.volume = volume
	s.pitch = pitch
	s.is_looping = bool(loop)
	s.frame_cursor = 0
	s.reached_end = false
	s.is_playing = true
}

unpause_sound :: proc(id: u32) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return
	}
	s.is_playing = true
}

pause_sound :: proc(id: u32) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return
	}
	s.is_playing = false
}

stop_sound :: proc(id: u32) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return
	}

	s.is_playing = false
	s.reached_end = false
	free_sound_data(s)
	s.is_valid = false
}

set_sound_volume :: proc(id: u32, volume: f32) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return
	}
	s.volume = volume
}

get_sound_volume :: proc(id: u32) -> f32 {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return 0.0
	}
	return s.volume
}

set_sound_pitch :: proc(id: u32, pitch: f32) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return
	}
	s.pitch = pitch
}

get_sound_pitch :: proc(id: u32) -> f32 {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	s, ok := find_sound_by_id(id)
	if !ok {
		return 0.0
	}
	return s.pitch
}

set_group_volume :: proc(group: string, volume: f32) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	g, ok := mixer.groups[group]
	if !ok {
		return
	}
	g.volume = volume
	mixer.groups[group] = g
}

get_group_volume :: proc(group: string) -> f32 {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	g, ok := mixer.groups[group]
	if !ok {
		return 0.0
	}
	return g.volume
}

set_group_pitch :: proc(group: string, pitch: f32) {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	g, ok := mixer.groups[group]
	if !ok {
		return
	}
	g.pitch = pitch
	mixer.groups[group] = g
}

get_group_pitch :: proc(group: string) -> f32 {
	sync.mutex_lock(&mixer.mutex)
	defer sync.mutex_unlock(&mixer.mutex)

	g, ok := mixer.groups[group]
	if !ok {
		return 0.0
	}
	return g.pitch
}
