@header package shader_post_processing
@header import sg "shared:sokol/gfx"

@vs vs
in vec2 position;
in vec2 uv;

out vec2 texcoord;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    texcoord    = uv;
}
@end

@fs fs
layout(binding=0) uniform texture2D screen_tex;
layout(binding=0) uniform sampler   screen_smp;

in  vec2 texcoord;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(screen_tex, screen_smp), texcoord);
}
@end

@program shader_post_processing vs fs