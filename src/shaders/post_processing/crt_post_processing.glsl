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
    vec2 uv = texcoord;

    // Curvatura
    vec2 curved = uv - 0.5;
    float dist = dot(curved, curved);
    curved *= 1.0 + dist * 0.3;
    curved += 0.5;

    // Fora da tela = preto
    if (curved.x < 0.0 || curved.x > 1.0 || curved.y < 0.0 || curved.y > 1.0) {
        frag_color = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec4 color = texture(sampler2D(screen_tex, screen_smp), curved);

    // Scanlines hardcoded para 600 linhas — troca se sua resolução for diferente
    float scanline = sin(curved.y * 600.0 * 3.14159) * 0.5 + 0.5;
    scanline = pow(scanline, 0.4);
    color.rgb *= mix(0.6, 1.0, scanline);

    // Vinheta
    vec2 vig = curved - 0.5;
    float vignette = 1.0 - dot(vig, vig) * 2.5;
    color.rgb *= clamp(vignette, 0.0, 1.0);

    // Contraste
    color.rgb = (color.rgb - 0.5) * 1.1 + 0.5;

    frag_color = color;
}
@end

@program shader_post_processing vs fs