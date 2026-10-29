package audio_engine

import "core:c"
import "core:c/libc"
import stbv "vendor:stb/vorbis"

decode_audio :: proc(data: []byte) -> (samples: []f32, channels: int, sample_rate: int, ok: bool) {
	if len(data) >= 12 && string(data[0:4]) == "RIFF" && string(data[8:12]) == "WAVE" {
		return decode_wav(data)
	}
	if len(data) >= 4 && string(data[0:4]) == "OggS" {
		return decode_ogg(data)
	}
	return nil, 0, 0, false
}

decode_ogg :: proc(data: []byte) -> (samples: []f32, channels: int, sample_rate: int, ok: bool) {
	if len(data) == 0 {
		return nil, 0, 0, false
	}

	c_channels: c.int
	c_sample_rate: c.int
	output: [^]c.short

	num_frames := stbv.decode_memory(
		([^]byte)(raw_data(data)),
		c.int(len(data)),
		&c_channels,
		&c_sample_rate,
		&output,
	)
	if num_frames <= 0 || output == nil || c_channels <= 0 {
		return nil, 0, 0, false
	}
	defer libc.free(output)

	total_samples := int(num_frames) * int(c_channels)
	out := make([]f32, total_samples)
	for i in 0 ..< total_samples {
		out[i] = f32(output[i]) / 32768.0
	}

	return out, int(c_channels), int(c_sample_rate), true
}
