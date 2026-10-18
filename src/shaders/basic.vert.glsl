uniform float uTime;
uniform float uSteepness;
uniform float uSimBlend;

varying vec3 vNormal;
varying vec3 vWorldPos;
varying float vHeight;
varying float vJacobian;
varying float vLostVar;
varying float vBreak;

const float GRAVITY = 9.81;
const float TAU = 6.28318530718;

const float SEED             = 0.0;    // change this to re-roll the whole sea
const int   WAVE_COUNT       = 20;
const float BASE_WAVELENGTH  = 36.0;
const float WAVELENGTH_DECAY = 0.84;   // each wave ~84% the length of the previous (before jitter)
const float STEEPNESS_DECAY  = 0.9;
const float WIND_ANGLE       = 0.3;    // radians
const float SWELL_SPREAD     = 0.35;   // half-width of direction scatter for the longest waves
const float CHOP_SPREAD      = 1.6;    // ...and for the shortest waves

// Waves fade out where the mesh is too coarse to represent them.
const float WAVE_FADE_NEAR = 4.0;
const float WAVE_FADE_FAR  = 8.0;

float hash11(float n) {
  return fract(sin(n * 127.1) * 43758.5453);
}

// Relative strength of wave i: decaying, with random variation.
float waveWeight(float fi) {
  return pow(STEEPNESS_DECAY, fi) * (0.6 + 0.8 * hash11(fi + SEED + 31.0));
}

void gerstner(vec2 p, vec2 dir, float wavelength, float steepness, float phase0,
              inout vec3 offset, inout vec3 tangent, inout vec3 binormal) {
  vec2 d = normalize(dir);
  float k = TAU / wavelength;
  float a = steepness / k;
  float f = k * dot(d, p) - sqrt(GRAVITY * k) * uTime + phase0;
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
  float maxHeight = 0.0;   // tallest the sea could be here if every wave peaked at once
  float lostVar = 0.0;     // slope variance thrown away by the distance fade

  // Pass 1: add up the random weights so the final steepnesses sum to exactly uSteepness.
  float totalWeight = 0.0;
  for (int i = 0; i < WAVE_COUNT; i++) {
    totalWeight += waveWeight(float(i));
  }

  // Pass 2: build each wave.
  for (int i = 0; i < WAVE_COUNT; i++) {
    float fi = float(i);
    float t = fi / float(WAVE_COUNT - 1);          // 0 = longest wave, 1 = shortest

    // Direction: golden-ratio sequence spreads angles evenly, and the spread widens for short waves.
    float g = fract(fi * 0.61803398875 + hash11(SEED + 3.0));
    float halfSpread = mix(SWELL_SPREAD, CHOP_SPREAD, t);
    float angle = WIND_ANGLE + (g - 0.5) * 2.0 * halfSpread;
    vec2 dir = vec2(cos(angle), sin(angle));

    // Wavelength: geometric series with +-15% jitter, so no two waves are neat multiples.
    float wavelength = BASE_WAVELENGTH * pow(WAVELENGTH_DECAY, fi)
                     * (0.85 + 0.3 * hash11(fi + SEED + 17.0));

    // Random starting phase: the fix for "everything lines up at the origin".
    float phase0 = TAU * hash11(fi + SEED + 53.0);

    float fade = 1.0 - smoothstep(WAVE_FADE_NEAR * wavelength, WAVE_FADE_FAR * wavelength, length(p));
    float steepness = uSteepness * fade * waveWeight(fi) / totalWeight;
    float lost = uSteepness * (1.0 - fade) * waveWeight(fi) / totalWeight;   // steepness removed by the fade
    lostVar += 0.25 * lost * lost;   // a sine's slope variance is s^2/2; about half of that per axis, so 0.25
    maxHeight += uSteepness * waveWeight(fi) / totalWeight * wavelength / TAU;   // sum of amplitudes (a = s / k)
    gerstner(p, dir, wavelength, steepness, phase0, offset, tangent, binormal);
  }

  // Wave sim: it replaces the deep-water swell where the water is shallow.
  // residual = sim height minus that swell, so in deep water it is zero and nothing changes.
  float simStep = uSimWindow.z / float(textureSize(uSimState, 0).x);
  float residual = sampleWaveSim(p).z;
  float residualDx = (sampleWaveSim(p + vec2(simStep, 0.0)).z - sampleWaveSim(p - vec2(simStep, 0.0)).z) / (2.0 * simStep);
  float residualDz = (sampleWaveSim(p + vec2(0.0, simStep)).z - sampleWaveSim(p - vec2(0.0, simStep)).z) / (2.0 * simStep);
  offset.y += residual * uSimBlend;
  tangent.y += residualDx * uSimBlend;       // slope of the added height, so the lighting follows it
  binormal.y += residualDz * uSimBlend;
  vBreak = sampleWaveSim(p).w * uSimBlend;   // how hard the waves are breaking here (0..1)

  // Area scale of the horizontal displacement: 1 = flat, <1 = compressed, <=0 = folded.
  vJacobian = tangent.x * binormal.z - binormal.x * tangent.z;
  vLostVar = lostVar;
  vec3 displaced = position + offset;
  vHeight = offset.y / max(maxHeight, 0.001);
  vNormal = normalize(cross(binormal, tangent));

  vec4 world = modelMatrix * vec4(displaced, 1.0);
  vWorldPos = world.xyz;
  gl_Position = projectionMatrix * viewMatrix * world;
}