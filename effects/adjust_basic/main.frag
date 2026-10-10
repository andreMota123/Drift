#version 330 core
// Colour adjust: every basic grading control in one pass, in a fixed order, so the result does
// not depend on the order sliders were touched. Each stage clamps to 0..1 and is skipped at
// its neutral value. Works on gamma-encoded values, like the single-purpose adjust.* effects.
in vec2 v_texCoord; out vec4 fragColor;
uniform sampler2D u_currentTexture;
uniform float brightness, contrast, saturation, highlights, shadows, whites, blacks;
uniform float temperature, tint, exposure, fade, vignette;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);
const float kPivot = 0.435;

vec3 sat3(vec3 c) { return clamp(c, 0.0, 1.0); }

// Brightness as a gamma hinged on white: lifts or lowers shadows and mids, leaves white alone.
vec3 applyBrightness(vec3 c, float amount) {
    float p = amount > 0.0 ? 1.0 + 2.0 * amount : 1.0 / (1.0 - 2.5 * amount);
    return 1.0 - pow(1.0 - c, vec3(p));
}

// Contrast around a pivot slightly below mid-grey. Lowering is a straight line; raising is an
// S-curve built from smoothstep halves, so the ends ease into black and white rather than clip.
vec3 applyContrast(vec3 c, float amount) {
    if (amount <= 0.0)
        return (1.0 + 0.4 * amount) * (c - kPivot) + kPivot;
    vec3 lo = kPivot * pow(c / kPivot, vec3(1.0 + 1.2 * amount));
    vec3 hi = 1.0 - (1.0 - kPivot) * pow((1.0 - c) / (1.0 - kPivot), vec3(1.0 + 1.2 * amount));
    return mix(lo, hi, step(kPivot, c));
}

// A power curve confined to one end of the range: the (a-1)(x^2-x^3) term gives the mid-tones
// back, so only the highlights (or only the shadows) move.
vec3 applyHighlights(vec3 c, float amount) {
    float a = 1.0 + 0.5 * amount + 0.18 * amount * amount;
    vec3 t = 1.0 - c;
    return 1.0 - pow(t, vec3(a)) - (a - 1.0) * (t * t - t * t * t);
}

vec3 applyShadows(vec3 c, float amount) {
    float a = 1.0 - 0.5 * amount + 0.18 * amount * amount;
    return pow(c, vec3(a)) + (a - 1.0) * (c * c - c * c * c);
}

// Levels: move the white point and the black point, then pass a straight line through them.
vec3 applyLevels(vec3 c, float w, float b) {
    vec2 white = w >= 0.0 ? vec2(1.0 - 0.5 * w, 1.0) : vec2(1.0, 1.0 + 0.5 * w);
    vec2 black = b >= 0.0 ? vec2(0.0, 0.5 * b) : vec2(-0.5 * b, 0.0);
    white = max(white, vec2(0.005));
    black = min(black, white - 0.005);
    float slope = (white.y - black.y) / (white.x - black.x);
    return slope * (c - black.x) + black.y;
}

// White balance as channel gains, renormalised so the overall luminance holds. Positive
// temperature warms (red up, blue down); positive tint leans magenta (green down).
vec3 applyWhiteBalance(vec3 c, float temp, float tintAmount) {
    vec3 gain = vec3(1.0 + 0.30 * temp, 1.0 - 0.22 * tintAmount, 1.0 - 0.30 * temp);
    gain.rb *= 1.0 + 0.08 * tintAmount;
    gain /= dot(gain, kLuma);
    return c * gain;
}

// Exposure in stops with a soft shoulder, so pushing it up rolls highlights off instead of
// slamming them into white.
vec3 applyExposure(vec3 c, float amount) {
    vec3 y = c * pow(2.0, 1.5 * amount);
    const float knee = 0.8;
    vec3 over = max(y - knee, 0.0);
    return min(y, vec3(knee)) + (1.0 - knee) * (1.0 - exp(-over / (1.0 - knee)));
}

void main() {
    vec4 src = texture(u_currentTexture, v_texCoord);
    vec3 c = src.rgb;

    if (abs(brightness) > 0.00001) c = sat3(applyBrightness(c, brightness));
    if (abs(contrast) > 0.00001) c = sat3(applyContrast(c, contrast));
    if (abs(saturation) > 0.00001) {
        float l = dot(c, kLuma);
        c = sat3(l + (1.0 + saturation) * (c - l));
    }
    if (abs(highlights) > 0.00001) c = sat3(applyHighlights(c, highlights));
    if (abs(shadows) > 0.00001) c = sat3(applyShadows(c, shadows));
    if (abs(whites) > 0.00001 || abs(blacks) > 0.00001) c = sat3(applyLevels(c, whites, blacks));
    if (abs(temperature) > 0.00001 || abs(tint) > 0.00001)
        c = sat3(applyWhiteBalance(c, temperature, tint));
    if (fade > 0.00001) {
        // Lifted blacks, slightly lowered whites and a touch less colour: the washed film look.
        vec3 faded = c * 0.78 + 0.13;
        float l = dot(faded, kLuma);
        c = sat3(mix(c, mix(vec3(l), faded, 0.85), fade));
    }
    if (abs(exposure) > 0.00001) c = sat3(applyExposure(c, exposure));
    if (abs(vignette) > 0.00001) {
        // Elliptical on purpose: it follows the frame, so the corners fall off evenly.
        float d = length(2.0 * v_texCoord - 1.0);
        float w = smoothstep(mix(1.2, 0.35, abs(vignette)), 1.5, d);
        c = mix(c, vignette > 0.0 ? vec3(0.0) : vec3(1.0), w * abs(vignette));
    }

    fragColor = vec4(c, src.a);
}
