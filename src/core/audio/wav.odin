package audio_engine

@(private = "file")
read_u16le :: proc(data: []byte, offset: int) -> u16 {
	return u16(data[offset]) | u16(data[offset + 1]) << 8
}

@(private = "file")
read_u32le :: proc(data: []byte, offset: int) -> u32 {
	return(
		u32(data[offset]) |
		u32(data[offset + 1]) << 8 |
		u32(data[offset + 2]) << 16 |
		u32(data[offset + 3]) << 24 \
	)
}

decode_wav :: proc(data: []byte) -> (samples: []f32, channels: int, sample_rate: int, ok: bool) {
	if len(data) < 12 || string(data[0:4]) != "RIFF" || string(data[8:12]) != "WAVE" {
		return nil, 0, 0, false
	}

	format_tag: u16
	num_channels: u16
	sr: u32
	bits_per_sample: u16
	found_fmt := false

	data_offset := -1
	data_size := 0

	offset := 12
	for offset + 8 <= len(data) {
		chunk_id := string(data[offset:offset + 4])
		chunk_size := int(read_u32le(data, offset + 4))
		chunk_data_start := offset + 8

		if chunk_size < 0 || chunk_data_start + chunk_size > len(data) {
			chunk_size = max(len(data) - chunk_data_start, 0)
		}

		switch chunk_id {
		case "fmt ":
			if chunk_size < 16 {
				return nil, 0, 0, false
			}
			format_tag = read_u16le(data, chunk_data_start)
			num_channels = read_u16le(data, chunk_data_start + 2)
			sr = read_u32le(data, chunk_data_start + 4)
			bits_per_sample = read_u16le(data, chunk_data_start + 14)
			if format_tag == 0xFFFE && chunk_size >= 40 {
				format_tag = read_u16le(data, chunk_data_start + 24)
			}
			found_fmt = true
		case "data":
			data_offset = chunk_data_start
			data_size = chunk_size
		}

		offset = chunk_data_start + chunk_size
		if chunk_size % 2 == 1 {
			offset += 1
		}
	}

	if !found_fmt || data_offset < 0 || num_channels == 0 || bits_per_sample == 0 || sr == 0 {
		return nil, 0, 0, false
	}

	bytes_per_sample := int(bits_per_sample) / 8
	frame_size := bytes_per_sample * int(num_channels)
	if frame_size == 0 || (format_tag != 1 && format_tag != 3) {
		return nil, 0, 0, false
	}

	num_frames := data_size / frame_size
	total_samples := num_frames * int(num_channels)
	pcm := data[data_offset:data_offset + num_frames * frame_size]

	out := make([]f32, total_samples)

	switch {
	case format_tag == 1 && bits_per_sample == 8:
		for i in 0 ..< total_samples {
			out[i] = (f32(pcm[i]) - 128.0) / 128.0
		}
	case format_tag == 1 && bits_per_sample == 16:
		for i in 0 ..< total_samples {
			v := i16(read_u16le(pcm, i * 2))
			out[i] = f32(v) / 32768.0
		}
	case format_tag == 1 && bits_per_sample == 24:
		for i in 0 ..< total_samples {
			b0 := u32(pcm[i * 3])
			b1 := u32(pcm[i * 3 + 1])
			b2 := u32(pcm[i * 3 + 2])
			v := b0 | b1 << 8 | b2 << 16
			if v & 0x800000 != 0 {
				v |= 0xFF000000
			}
			out[i] = f32(i32(v)) / 8388608.0
		}
	case format_tag == 1 && bits_per_sample == 32:
		for i in 0 ..< total_samples {
			v := i32(read_u32le(pcm, i * 4))
			out[i] = f32(v) / 2147483648.0
		}
	case format_tag == 3 && bits_per_sample == 32:
		for i in 0 ..< total_samples {
			bits := read_u32le(pcm, i * 4)
			out[i] = transmute(f32)bits
		}
	case:
		delete(out)
		return nil, 0, 0, false
	}

	return out, int(num_channels), int(sr), true
}
