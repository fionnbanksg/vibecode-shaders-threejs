uniform float uMemDt;
uniform float uMemInit;
uniform float uFoamLife;      // seconds for foam to fade
uniform float uWetLife;       // seconds for wet sand to dry
uniform vec2 uFoamDrift;      // m/s, world xz: foam travels with the wind
varying vec2 vUv;

void main() {
  vec2 xz = uMemWindow.xy + vec2((vUv.x - 0.5) * uMemWindow.z, (0.5 - vUv.y) * uMemWindow.z);
  float ground = terrainHeightSmooth(xz);

  if (uMemInit > 0.5) {
    gl_FragColor = vec4(0.0, 1.0 - step(0.0, ground), 0.0, 1.0);   // everything under water starts wet
    return;
  }

  // What was here a moment ago. Foam is carried along the drift; wetness stays where it is.
  vec4 oldHere = sampleSurfaceMemory(xz);
  vec4 oldDrifted = sampleSurfaceMemory(xz - uFoamDrift * uMemDt);

  vec4 s = sampleWaveSim(xz);                          // x = surface height, w = breaking
  float thickness = s.x - ground;                      // water above the ground here
  float water = smoothstep(0.0, 0.03, thickness);
  float front = water * (1.0 - smoothstep(0.02, 0.25, thickness));   // thin water = the leading edge
  float inject = max(smoothstep(0.1, 0.5, s.w), 0.8 * front);

  float foam = max(oldDrifted.x * exp(-uMemDt / uFoamLife), inject);
  float wet = max(oldHere.y * exp(-uMemDt / uWetLife), water);
  gl_FragColor = vec4(foam, wet, 0.0, 1.0);
}