#version 330 core
// 3D LUT lookup. The table arrives as a strip of N slices side by side — red across a slice,
// green down it, one slice per blue step. Red and green are interpolated by the sampler; blue
// is interpolated here, between the two slices either side of the value. u_lutSize is 0 while
// no file is chosen, and the picture passes through untouched.
in vec2 v_texCoord; out vec4 fragColor;
uniform sampler2D u_currentTexture;
uniform sampler2D u_texture1;
uniform float u_lutSize;
uniform float intensity;

vec3 lookup(vec3 c) {
    float n = u_lutSize;
    float blue = c.b * (n - 1.0);
    float slice0 = floor(blue);
    float slice1 = min(slice0 + 1.0, n - 1.0);
    // Half-texel inset keeps the sampler from bleeding into the neighbouring slice.
    float x = (c.r * (n - 1.0) + 0.5) / (n * n);
    float y = (c.g * (n - 1.0) + 0.5) / n;
    vec3 a = texture(u_texture1, vec2(x + slice0 / n, y)).rgb;
    vec3 b = texture(u_texture1, vec2(x + slice1 / n, y)).rgb;
    return mix(a, b, blue - slice0);
}

void main() {
    vec4 src = texture(u_currentTexture, v_texCoord);
    if (u_lutSize < 2.0) {
        fragColor = src;
        return;
    }
    vec3 graded = lookup(clamp(src.rgb, 0.0, 1.0));
    fragColor = vec4(mix(src.rgb, graded, clamp(intensity, 0.0, 1.0)), src.a);
}
