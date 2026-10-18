// Wave-sim state, published by WaveSim.js.
// x = height, y = previous height, z = residual (sim minus deep-water swell), w = breaking
uniform sampler2D uSimState;
uniform vec4 uSimWindow;   // centre x, centre z, size (m), unused

// Bilinear by hand: 32-bit float textures can't be filtered everywhere.
vec4 sampleWaveSim(vec2 xz) {
  vec2 uv = vec2((xz.x - uSimWindow.x) / uSimWindow.z + 0.5,
                 0.5 - (xz.y - uSimWindow.y) / uSimWindow.z);
  vec2 size = vec2(textureSize(uSimState, 0));
  vec2 p = clamp(uv, 0.0, 1.0) * size - 0.5;
  vec2 i = floor(p);
  vec2 f = p - i;
  vec2 inv = 1.0 / size;
  vec2 q = (i + 0.5) * inv;
  vec4 a = texture2D(uSimState, q);
  vec4 b = texture2D(uSimState, q + vec2(inv.x, 0.0));
  vec4 c = texture2D(uSimState, q + vec2(0.0, inv.y));
  vec4 d = texture2D(uSimState, q + inv);
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}