#version 330 core
// Curves: one tone curve for overall brightness and one each for red, green and blue. A curve
// is five points at inputs 0, 0.25, 0.5, 0.75 and 1; each slider lifts or lowers its point by up
// to a quarter of the range, and a smooth spline runs through them. The brightness curve moves
// luminance only (colour is carried along by the same ratio), so it does not shift hues; the
// channel curves act on their channel directly, which is what makes them a colour tool.
in vec2 v_texCoord; out vec4 fragColor;
uniform sampler2D u_currentTexture;
uniform float lumaBlacks, lumaShadows, lumaMids, lumaLights, lumaWhites;
uniform float redBlacks, redShadows, redMids, redLights, redWhites;
uniform float greenBlacks, greenShadows, greenMids, greenLights, greenWhites;
uniform float blueBlacks, blueShadows, blueMids, blueLights, blueWhites;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

// Catmull-Rom through five evenly spaced points, with the end tangents taken one-sided so the
// curve does not overshoot past the first and last point.
float curve(float x, float p0, float p1, float p2, float p3, float p4) {
    float y[5] = float[5](p0 * 0.25, 0.25 + p1 * 0.25, 0.5 + p2 * 0.25, 0.75 + p3 * 0.25, 1.0 + p4 * 0.25);
    float t = clamp(x, 0.0, 1.0) * 4.0;
    int i = int(min(floor(t), 3.0));
    float f = t - float(i);
    float a = y[i], b = y[i + 1];
    float ta = i == 0 ? (b - a) : 0.5 * (b - y[i - 1]);
    float tb = i == 3 ? (b - a) : 0.5 * (y[i + 2] - a);
    float f2 = f * f, f3 = f2 * f;
    return clamp((2.0 * f3 - 3.0 * f2 + 1.0) * a + (f3 - 2.0 * f2 + f) * ta
               + (-2.0 * f3 + 3.0 * f2) * b + (f3 - f2) * tb, 0.0, 1.0);
}

void main() {
    vec4 src = texture(u_currentTexture, v_texCoord);
    vec3 c = clamp(src.rgb, 0.0, 1.0);

    float l = dot(c, kLuma);
    float mapped = curve(l, lumaBlacks, lumaShadows, lumaMids, lumaLights, lumaWhites);
    // Scale the colour by the luminance change; near black, where the ratio is unstable,
    // fall back to adding the difference.
    c = l > 0.001 ? c * (mapped / l) : c + (mapped - l);
    c = clamp(c, 0.0, 1.0);

    c.r = curve(c.r, redBlacks, redShadows, redMids, redLights, redWhites);
    c.g = curve(c.g, greenBlacks, greenShadows, greenMids, greenLights, greenWhites);
    c.b = curve(c.b, blueBlacks, blueShadows, blueMids, blueLights, blueWhites);
    fragColor = vec4(c, src.a);
}
