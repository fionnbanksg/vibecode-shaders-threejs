// Host-scene terrain height, captured top-down by Bathymetry.js.
uniform sampler2D uBathyDepth;
uniform vec4 uBathyParams;   // centre x, centre z, window size (m), top height (m)
uniform vec2 uBathyRange;    // orthographic near, far

float terrainHeightAtUv(vec2 uv) {
  float d = texture2D(uBathyDepth, uv).x;                                  // 0..1, linear for an ortho camera
  float dist = uBathyRange.x + d * (uBathyRange.y - uBathyRange.x);        // metres below the camera
  return uBathyParams.w - dist;
}

vec2 bathyUv(vec2 xz) {
  return vec2((xz.x - uBathyParams.x) / uBathyParams.z + 0.5,
              0.5 - (xz.y - uBathyParams.y) / uBathyParams.z);
}

// Nearest texel: stair-stepped, fine for debug views.
float terrainHeight(vec2 xz) {
  return terrainHeightAtUv(clamp(bathyUv(xz), 0.0, 1.0));
}

// Bilinear by hand (depth textures are not filterable): smooth heights and slopes for the sim.
float terrainHeightSmooth(vec2 xz) {
  vec2 size = vec2(textureSize(uBathyDepth, 0));
  vec2 p = clamp(bathyUv(xz), 0.0, 1.0) * size - 0.5;
  vec2 i = floor(p);
  vec2 f = p - i;
  vec2 inv = 1.0 / size;
  vec2 q = (i + 0.5) * inv;
  float a = terrainHeightAtUv(clamp(q, 0.0, 1.0));
  float b = terrainHeightAtUv(clamp(q + vec2(inv.x, 0.0), 0.0, 1.0));
  float c = terrainHeightAtUv(clamp(q + vec2(0.0, inv.y), 0.0, 1.0));
  float d = terrainHeightAtUv(clamp(q + inv, 0.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}