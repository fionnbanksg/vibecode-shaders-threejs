uniform float uTime;

varying vec3 vNormal;
varying vec3 vWorldPos;

const float GRAVITY = 9.81;
const float TAU = 6.28318530718;

const int   WAVE_COUNT       = 8;
const float BASE_WAVELENGTH  = 12.0;
const float WAVELENGTH_DECAY = 0.7;   // each wave is 70% the length of the previous
const float STEEPNESS_DECAY  = 0.78;
uniform float uSteepness;             // keep < 1.0 or the surface folds over itself   // keep < 1.0 or the surface folds over itself
const float WIND_ANGLE       = 0.43;   // radians
const float WIND_SPREAD      = 1.6;   // radians; 0 = all waves aligned
const float WAVE_FADE_NEAR = 4.0;
const float WAVE_FADE_FAR  = 8.0;
varying float vHeight;
float hash11(float n) {
  return fract(sin(n * 127.1) * 43758.5453);
}

// Adds one Gerstner wave into the accumulators.
// `inout` = the function reads AND modifies the caller's variable.
void gerstner(vec2 p, vec2 dir, float wavelength, float steepness,
              inout vec3 offset, inout vec3 tangent, inout vec3 binormal) {
  vec2 d = normalize(dir);
  float k = TAU / wavelength;
  float a = steepness / k;                          // amplitude
  float f = k * dot(d, p) - sqrt(GRAVITY * k) * uTime;
  float s = sin(f);
  float c = cos(f);

  offset += vec3(d.x * a * c, a * s, d.y * a * c);

  tangent  += vec3(-d.x * d.x * steepness * s,  d.x * steepness * c, -d.x * d.y * steepness * s);
  binormal += vec3(-d.x * d.y * steepness * s,  d.y * steepness * c, -d.y * d.y * steepness * s);
}

void main() {
  vec2 p = position.xz;

  vec3 offset   = vec3(0.0);
  vec3 tangent  = vec3(1.0, 0.0, 0.0);
  vec3 binormal = vec3(0.0, 0.0, 1.0);

  // Sum of a geometric series, so the per-wave steepnesses add up to TOTAL_STEEPNESS.
  float norm = (1.0 - pow(STEEPNESS_DECAY, float(WAVE_COUNT))) / (1.0 - STEEPNESS_DECAY);

  for (int i = 0; i < WAVE_COUNT; i++) {
    float fi = float(i);
    float angle = WIND_ANGLE + (hash11(fi + 1.0) - 0.5) * WIND_SPREAD;
    vec2 dir = vec2(cos(angle), sin(angle));
    float wavelength = BASE_WAVELENGTH * pow(WAVELENGTH_DECAY, fi);
    float fade = 1.0 - smoothstep(WAVE_FADE_NEAR * wavelength, WAVE_FADE_FAR * wavelength, length(p));
    float steepness  = uSteepness * fade * pow(STEEPNESS_DECAY, fi) / norm;

    gerstner(p, dir, wavelength, steepness, offset, tangent, binormal);
  }

  vec3 displaced = position + offset;
  vHeight = offset.y / max(uSteepness, 0.05);   // signed, roughly -1..1; crests are positive
  vNormal = normalize(cross(binormal, tangent));

  vec4 world = modelMatrix * vec4(displaced, 1.0);
  vWorldPos = world.xyz;
  gl_Position = projectionMatrix * viewMatrix * world;
}