// The deep-water swell, as plain heights. Used as the sim's boundary and deep-water target.
// !! These constants must match basic.vert.glsl. We'll unify them in the SDK refactor.
uniform float uSteepness;

const float GRAVITY = 9.81;
const float TAU = 6.28318530718;
const float SEED = 0.0;
const int   WAVE_COUNT = 20;
const int   SWELL_COUNT = 6;            // the long waves the sim takes over (wavelength > ~15 m)
const float BASE_WAVELENGTH = 36.0;
const float WAVELENGTH_DECAY = 0.84;
const float STEEPNESS_DECAY = 0.9;
const float WIND_ANGLE = 0.3;
const float SWELL_SPREAD = 0.35;
const float CHOP_SPREAD = 1.6;
const float WAVE_FADE_NEAR = 4.0;
const float WAVE_FADE_FAR = 8.0;

float hash11(float n) {
  return fract(sin(n * 127.1) * 43758.5453);
}

float waveWeight(float fi) {
  return pow(STEEPNESS_DECAY, fi) * (0.6 + 0.8 * hash11(fi + SEED + 31.0));
}

// Linear (sine) height of the first SWELL_COUNT waves at world position p, time t.
float swellHeight(vec2 p, float t) {
  float totalWeight = 0.0;
  for (int i = 0; i < WAVE_COUNT; i++) totalWeight += waveWeight(float(i));

  float h = 0.0;
  for (int i = 0; i < SWELL_COUNT; i++) {
    float fi = float(i);
    float tt = fi / float(WAVE_COUNT - 1);
    float g = fract(fi * 0.61803398875 + hash11(SEED + 3.0));
    float halfSpread = mix(SWELL_SPREAD, CHOP_SPREAD, tt);
    float angle = WIND_ANGLE + (g - 0.5) * 2.0 * halfSpread;
    vec2 dir = vec2(cos(angle), sin(angle));
    float wavelength = BASE_WAVELENGTH * pow(WAVELENGTH_DECAY, fi) * (0.85 + 0.3 * hash11(fi + SEED + 17.0));
    float phase0 = TAU * hash11(fi + SEED + 53.0);
    float k = TAU / wavelength;
    float fade = 1.0 - smoothstep(WAVE_FADE_NEAR * wavelength, WAVE_FADE_FAR * wavelength, length(p));
    float a = uSteepness * fade * waveWeight(fi) / totalWeight / k;
    h += a * sin(k * dot(dir, p) - sqrt(GRAVITY * k) * t + phase0);
  }
  return h;
}