// Surface memory, published by SurfaceMemory.js. Written so host materials can include it too.
// x = foam (0..1, fades over seconds), y = wetness (0..1, fades over tens of seconds)
uniform sampler2D uSurfaceMemory;
uniform vec4 uMemWindow;   // centre x, centre z, size (m), unused

// Bilinear by hand: 32-bit float textures can't be filtered everywhere.
vec4 sampleSurfaceMemory(vec2 xz) {
  vec2 uv = vec2((xz.x - uMemWindow.x) / uMemWindow.z + 0.5,
                 0.5 - (xz.y - uMemWindow.y) / uMemWindow.z);
  vec2 size = vec2(textureSize(uSurfaceMemory, 0));
  vec2 p = clamp(uv, 0.0, 1.0) * size - 0.5;
  vec2 i = floor(p);
  vec2 f = p - i;
  vec2 inv = 1.0 / size;
  vec2 q = (i + 0.5) * inv;
  vec4 a = texture2D(uSurfaceMemory, q);
  vec4 b = texture2D(uSurfaceMemory, q + vec2(inv.x, 0.0));
  vec4 c = texture2D(uSurfaceMemory, q + vec2(0.0, inv.y));
  vec4 d = texture2D(uSurfaceMemory, q + inv);
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}