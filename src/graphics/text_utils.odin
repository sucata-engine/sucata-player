package graphics

import "../common"
import "core:unicode/utf8"

calculate_text_width :: proc(text: string, font: ^Font, scale: [2]f32) -> f32 {
	width: f32 = 0
	i := 0
	if font == nil {
		return 0
	}

	for i < len(text) {
		r, size := utf8.decode_rune(text[i:])
		i += size

		if r < 32 || r > 255 {
			continue
		}

		char_index := int(r) - 32
		if char_index < 0 || char_index >= len(font.char_data) {
			continue
		}
		baked_char := font.char_data[char_index]
		width += f32(baked_char.xadvance) * scale[0]
	}
	return width
}

calculate_alignment_offset :: proc(
	line_width: f32,
	max_width: f32,
	align: common.TextAlign,
) -> f32 {

	if max_width <= 0 {
		switch align {
		case .Left:
			return 0
		case .Center:
			return -line_width / 2
		case .Right:
			return -line_width
		}
		return 0
	}

	switch align {
	case .Left:
		return 0
	case .Center:
		return (max_width * 0.5) - (line_width * 0.5)
	case .Right:
		return max_width - line_width
	}

	return 0
}

wrap_text :: proc(text: string, font: ^Font, scale: [2]f32, max_width: f32) -> [dynamic]string {
	lines := make([dynamic]string)

	if max_width <= 0 {
		append(&lines, text)
		return lines
	}

	current_line: string
	current_width: f32 = 0
	word_start := 0
	i := 0

	for i < len(text) {
		r, size := utf8.decode_rune(text[i:])
		current_byte := i
		i += size

		if r == '\n' {
			if i > word_start {
				line_text := text[word_start:i]
				append(&lines, line_text)
			} else if len(current_line) > 0 {
				append(&lines, current_line)
			}
			current_line = ""
			current_width = 0
			word_start = i + 1
			continue
		}

		if r < 32 || r > 255 {
			continue
		}

		char_index := int(r) - 32
		if char_index < 0 || char_index >= len(font.char_data) {
			continue
		}
		baked_char := font.char_data[char_index]
		char_width := f32(baked_char.xadvance) * scale[0]

		if current_width + char_width > max_width && current_width > 0 {
			last_space := -1
			for j := i - 1; j >= word_start; j -= 1 {
				if text[j] == ' ' {
					last_space = j
					break
				}
			}

			if last_space >= word_start {
				append(&lines, text[word_start:last_space])
				word_start = last_space + 1
				current_width = 0

				for k in word_start ..< i + 1 {
					c := text[k]
					if c >= 32 && c < 128 {
						c_idx := int(c) - 32
						if c_idx >= 0 && c_idx < len(font.char_data) {
							bc := font.char_data[c_idx]
							current_width += f32(bc.xadvance) * scale[0]
						}
					}
				}
			} else {
				append(&lines, text[word_start:i])
				word_start = i
				current_width = char_width
			}
		} else {
			current_width += char_width
		}
	}

	if word_start < len(text) {
		append(&lines, text[word_start:len(text)])
	}

	return lines
}
