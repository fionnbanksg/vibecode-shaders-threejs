// Procedural noise with analytic derivatives. Pure functions, no uniforms.

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise. Returns vec3(value, d/dx, d/dy).
vec3 noised(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u  = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);   // quintic smoothing
  vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);        // its derivative

  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));

  float k1 = b - a;
  float k2 = c - a;
  float k4 = a - b - c + d;

  float value = a + k1 * u.x + k2 * u.y + k4 * u.x * u.y;
  vec2 grad = du * vec2(k1 + k4 * u.y, k2 + k4 * u.x);
  return vec3(value, grad);
}

const int   RIPPLE_OCTAVES      = 6;
const float RIPPLE_BASE_FREQ    = 0.9;    // cycles per metre of the first octave
const float RIPPLE_LACUNARITY   = 2.0;    // frequency multiplier per octave
const float RIPPLE_GAIN         = 0.4;    // amplitude multiplier per octave
const float RIPPLE_SLOPE_SCALE  = 0.07;   // overall steepness of the ripples
const float RIPPLE_FADE_START   = 60.0;   // in wavelengths: distance where an octave starts fading
const float RIPPLE_FADE_END     = 220.0;  // ...and where it is gone

const mat2 OCTAVE_ROT = mat2(0.8, -0.6, 0.6, 0.8);   // a rotation (0.8^2 + 0.6^2 = 1)

// Returns the slope (dh/dx, dh/dz) of the ripple height field at world position p.
vec2 rippleSlope(vec2 p, float dist, float time, out float lostVar) {
  vec2 slope = vec2(0.0);
  lostVar = 0.0;
  float freq = RIPPLE_BASE_FREQ;
  float amp = 1.0;
  mat2 rot = mat2(1.0);

  for (int i = 0; i < RIPPLE_OCTAVES; i++) {
    float wavelength = 1.0 / freq;
    float fade = 1.0 - smoothstep(RIPPLE_FADE_START * wavelength,
                                  RIPPLE_FADE_END * wavelength, dist);

    float octaveSlope = amp * freq * RIPPLE_SLOPE_SCALE;           // slope amplitude of this octave
    lostVar += 0.25 * octaveSlope * octaveSlope * (1.0 - fade * fade);

    // Each octave drifts in its own direction so the pattern never visibly slides as one sheet.
    float a = 0.3 + float(i) * 1.3;
    vec2 scroll = vec2(cos(a), sin(a)) * time * (0.4 + 0.12 * float(i));

    vec3 nz = noised(rot * ((p + scroll) * freq));
    // Chain rule: q = rot * (p * freq)  =>  dh/dp = freq * (grad_q * rot)
    slope += amp * fade * freq * (nz.yz * rot);

    freq *= RIPPLE_LACUNARITY;
    amp *= RIPPLE_GAIN;
    rot = OCTAVE_ROT * rot;
  }
  return slope * RIPPLE_SLOPE_SCALE;
}

// Four octaves of value noise, roughly 0..1. Detail goes down to a few centimetres.
float foamFbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * noised(p).x;
    p = OCTAVE_ROT * p * 2.3;
    a *= 0.5;
  }
  return v / 0.9375;   // divide by the sum of the amplitudes
}