#version 330 core
// HSL by colour band: shift the hue, saturation and lightness of eight ranges of colour
// independently. Each band is a smooth bump around its centre hue, wide enough to meet its
// neighbours half way, so adjacent bands blend instead of leaving seams. Greys are left alone:
// the whole adjustment is scaled by how saturated the pixel is.
in vec2 v_texCoord; out vec4 fragColor;
uniform sampler2D u_currentTexture;
uniform float redHue, redSat, redLum;
uniform float orangeHue, orangeSat, orangeLum;
uniform float yellowHue, yellowSat, yellowLum;
uniform float greenHue, greenSat, greenLum;
uniform float cyanHue, cyanSat, cyanLum;
uniform float blueHue, blueSat, blueLum;
uniform float purpleHue, purpleSat, purpleLum;
uniform float magentaHue, magentaSat, magentaLum;

vec3 rgbToHsl(vec3 c) {
    float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
    float l = 0.5 * (mx + mn), d = mx - mn, h = 0.0, s = 0.0;
    if (d > 0.00001) {
        s = d / (1.0 - abs(2.0 * l - 1.0) + 0.00001);
        if (mx == c.r) h = mod((c.g - c.b) / d, 6.0);
        else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
        else h = (c.r - c.g) / d + 4.0;
        h *= 60.0;
    }
    return vec3(h, clamp(s, 0.0, 1.0), l);
}

vec3 hslToRgb(vec3 hsl) {
    float c = (1.0 - abs(2.0 * hsl.z - 1.0)) * hsl.y;
    float hp = mod(hsl.x, 360.0) / 60.0;
    float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
    vec3 rgb = hp < 1.0 ? vec3(c, x, 0.0) : hp < 2.0 ? vec3(x, c, 0.0) : hp < 3.0 ? vec3(0.0, c, x)
             : hp < 4.0 ? vec3(0.0, x, c) : hp < 5.0 ? vec3(x, 0.0, c) : vec3(c, 0.0, x);
    return rgb + (hsl.z - 0.5 * c);
}

// 1 at the band centre, easing to 0 at `width` degrees away, wrapping around the hue circle.
float bandWeight(float hue, float centre, float width) {
    float d = abs(mod(hue - centre + 180.0, 360.0) - 180.0);
    float t = clamp(1.0 - d / width, 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

void main() {
    vec4 src = texture(u_currentTexture, v_texCoord);
    vec3 hsl = rgbToHsl(src.rgb);
    vec3 shift = vec3(0.0);
    float w;
    w = bandWeight(hsl.x, 0.0, 30.0); shift += w * vec3(redHue, redSat, redLum);
    w = bandWeight(hsl.x, 30.0, 30.0); shift += w * vec3(orangeHue, orangeSat, orangeLum);
    w = bandWeight(hsl.x, 60.0, 45.0); shift += w * vec3(yellowHue, yellowSat, yellowLum);
    w = bandWeight(hsl.x, 120.0, 60.0); shift += w * vec3(greenHue, greenSat, greenLum);
    w = bandWeight(hsl.x, 180.0, 60.0); shift += w * vec3(cyanHue, cyanSat, cyanLum);
    w = bandWeight(hsl.x, 240.0, 50.0); shift += w * vec3(blueHue, blueSat, blueLum);
    w = bandWeight(hsl.x, 280.0, 40.0); shift += w * vec3(purpleHue, purpleSat, purpleLum);
    w = bandWeight(hsl.x, 320.0, 40.0); shift += w * vec3(magentaHue, magentaSat, magentaLum);
    // Fade the effect out towards grey, where hue is undefined and noise would flicker.
    float chroma = smoothstep(0.02, 0.2, hsl.y);
    hsl.x = mod(hsl.x + 30.0 * shift.x * chroma + 360.0, 360.0);
    hsl.y = clamp(hsl.y * (1.0 + shift.y * chroma), 0.0, 1.0);
    hsl.z = clamp(hsl.z + 0.25 * shift.z * chroma, 0.0, 1.0);
    fragColor = vec4(clamp(hslToRgb(hsl), 0.0, 1.0), src.a);
}
