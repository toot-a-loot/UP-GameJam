shader_type canvas_item;

global uniform vec2 resolution;
global uniform float color_depth;

uniform float dither_amount: hint_range (0.0, 1.0, 0.01);

// Exact matrix from your file preserved
const mat4 bayer_matrix = (1.0 / 16.0) * mat4(
    vec4(0.0, 8.0, 2.0, 10.0),
    vec4(12.0, 4.0, 14.0, 6.0),
    vec4(3.0, 11.0, 1.0, 9.0),
    vec4(15.0, 7.0, 13.0, 9.0)
) - 0.5;

void fragment() {
    // 1. DOWNSAMPLING (Using SCREEN_UV to match your preference)
    vec2 uv = floor(SCREEN_UV * resolution) / resolution;
    ivec2 int_uv = ivec2(uv * resolution);
    
    // 2. SAMPLE THE UI (Modified)
    // We sample TEXTURE (the UI) instead of screen_texture (the background).
    // We sample at 'uv' to get the pixelated look.
    vec4 color = texture(TEXTURE, uv);
    
    // 3. TRANSPARENCY CHECK
    // If the pixel is transparent (no UI), we discard the shader logic
    // so the 3D world shows through cleanly.
    if (color.a > 0.01) {
        // 4. DITHERING (Your exact logic)
        vec3 dithered_color = color.rgb + bayer_matrix[int_uv.x % 4][int_uv.y % 4] / color_depth * dither_amount;
        vec3 quantized_color = round(dithered_color * color_depth) / color_depth;
        
        // Output the modified color with the original alpha
        COLOR = vec4(quantized_color, color.a);
    } else {
        // Output invisible pixel so the 3D camera shows through
        COLOR = vec4(0.0);
    }
}