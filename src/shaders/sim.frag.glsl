uniform sampler2D uState;      // x = height, y = previous height
uniform float uSimTime;        // time of the step being written
uniform float uDt;
uniform float uInit;
uniform vec2 uSimCenter;
uniform float uSimSize;
uniform vec2 uTexel;
uniform float uRelaxRate;      // how hard deep water and the edges are pulled to the swell (per second)
uniform float uBaseDamping;    // gentle background damping (per second)
uniform float uBreakRate;      // extra damping while breaking (per second)
uniform float uLandDamp;       // damping on the beach, which makes run-up die out (per second)
uniform float uCapFactor;      // waves can't be taller than this fraction of the water depth
varying vec2 vUv;

const float K0 = TAU / BASE_WAVELENGTH;     // the dominant swell sets the deep-water speed
const float FILM_DEPTH = 0.25;              // the beach counts as this much water, so waves can run up it

float groundAt(vec2 xz) { return terrainHeightSmooth(xz); }   // metres above rest level, negative = underwater
float speed2(float ground) { return GRAVITY * tanh(K0 * max(-ground, FILM_DEPTH)) / K0; }

void main() {
  // v grows upward on screen, which is -Z in the world (same convention as the bathymetry).
  vec2 xz = uSimCenter + vec2((vUv.x - 0.5) * uSimSize, (0.5 - vUv.y) * uSimSize);
  float dx = uSimSize * uTexel.x;
  float ground = groundAt(xz);
  float depth = -ground;                          // negative on the beach
  float land = smoothstep(0.0, 0.6, ground);      // 0 in the water, 1 a little way up the sand

  if (uInit > 0.5) {
    gl_FragColor = vec4(swellHeight(xz, uSimTime) * (1.0 - land), swellHeight(xz, uSimTime - uDt) * (1.0 - land), 0.0, 0.0);
    return;
  }

  vec4 s = texture2D(uState, vUv);
  float eta = s.x;
  float etaPrev = s.y;

  // Neighbour heights and wave speeds (E/W along +X/-X, N/S along -Z/+Z).
  float etaE = texture2D(uState, vUv + vec2(uTexel.x, 0.0)).x;
  float etaW = texture2D(uState, vUv - vec2(uTexel.x, 0.0)).x;
  float etaN = texture2D(uState, vUv + vec2(0.0, uTexel.y)).x;
  float etaS = texture2D(uState, vUv - vec2(0.0, uTexel.y)).x;
  float c2C = speed2(ground);
  float c2E = speed2(groundAt(xz + vec2(dx, 0.0)));
  float c2W = speed2(groundAt(xz - vec2(dx, 0.0)));
  float c2N = speed2(groundAt(xz + vec2(0.0, -dx)));
  float c2S = speed2(groundAt(xz + vec2(0.0, dx)));

  // d2(eta)/dt2 = div(c^2 grad eta): flux form, so wave energy is conserved (that is what gives shoaling).
  float lap = (0.5 * (c2C + c2E) * (etaE - eta) - 0.5 * (c2C + c2W) * (eta - etaW)
             + 0.5 * (c2C + c2N) * (etaN - eta) - 0.5 * (c2C + c2S) * (eta - etaS)) / (dx * dx);

  // Damping: background, breaking (waves tall for the depth), and the beach (so run-up dies out).
  float breaking = smoothstep(0.35, 0.8, abs(eta) / (max(depth, 0.0) + 0.1)) * (1.0 - land);
  float damp = clamp(uDt * (uBaseDamping + uBreakRate * breaking + uLandDamp * land), 0.0, 0.5);

  float next = eta + (eta - etaPrev) * (1.0 - damp) + uDt * uDt * lap;

  // Deep water and the window edge are pulled toward the analytic swell: that is what drives the sim.
  float target = swellHeight(xz, uSimTime);
  vec2 e2 = min(vUv, 1.0 - vUv);
  float wEdge = (1.0 - smoothstep(0.0, 0.08, min(e2.x, e2.y))) * (1.0 - land);
  float wDeep = smoothstep(0.15 * BASE_WAVELENGTH, 0.35 * BASE_WAVELENGTH, depth);
  next = mix(next, target, clamp(uRelaxRate * max(wEdge, wDeep) * uDt, 0.0, 1.0));

  // Waves can't be much taller than the water is deep (saturated surf), plus a little for the swash.
  float cap = uCapFactor * max(depth, 0.0) + 0.12;
  next = cap * tanh(next / cap);
  next *= 1.0 - smoothstep(0.4, 1.6, ground);     // high up the beach there is no water at all

  gl_FragColor = vec4(next, eta, next - target, breaking);
}