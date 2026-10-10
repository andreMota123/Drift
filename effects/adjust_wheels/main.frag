#version 330 core
// Primary colour wheels as sliders: lift, gamma, gain and offset, each with a red/green/blue
// balance and an overall level. Lift moves the blacks and leaves white alone, gain scales from
// black so it moves the whites, gamma bends the middle with both ends pinned, and offset slides
// everything. Applied in that order — the usual lift/gamma/gain arrangement.
in vec2 v_texCoord; out vec4 fragColor;
uniform sampler2D u_currentTexture;
uniform float liftR, liftG, liftB, liftY;
uniform float gammaR, gammaG, gammaB, gammaY;
uniform float gainR, gainG, gainB, gainY;
uniform float offsetR, offsetG, offsetB, offsetY;
uniform float saturation;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

// A colour balance with its own brightness taken out, so pushing one channel tints without
// also lightening; the level slider is what changes brightness.
vec3 balance(float r, float g, float b, float level) {
    vec3 tint = vec3(r, g, b);
    return tint - dot(tint, kLuma) + level;
}

void main() {
    vec4 src = texture(u_currentTexture, v_texCoord);
    vec3 c = src.rgb;

    vec3 lift = 0.25 * balance(liftR, liftG, liftB, liftY);
    vec3 gain = 1.0 + 0.5 * balance(gainR, gainG, gainB, gainY);
    vec3 gamma = exp2(-balance(gammaR, gammaG, gammaB, gammaY));
    vec3 offset = 0.2 * balance(offsetR, offsetG, offsetB, offsetY);

    c = c + lift * (1.0 - c);
    c = c * gain;
    c = pow(clamp(c, 0.0, 1.0), gamma);
    c = c + offset;

    float l = dot(c, kLuma);
    c = l + (1.0 + saturation) * (c - l);
    fragColor = vec4(clamp(c, 0.0, 1.0), src.a);
}
