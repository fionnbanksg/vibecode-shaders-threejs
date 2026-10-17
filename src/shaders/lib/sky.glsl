// Shared sky functions. Colours are in linear space.

vec3 skyGradient(vec3 dir, vec3 sunDir) {
  float h = clamp(dir.y, 0.0, 1.0);
  vec3 horizon = vec3(0.55, 0.68, 0.85);
  vec3 zenith  = vec3(0.08, 0.22, 0.55);
  vec3 col = mix(horizon, zenith, pow(h, 0.5));

  float s = max(dot(dir, sunDir), 0.0);
  col += vec3(1.0, 0.75, 0.45) * (pow(s, 6.0) * 0.15 + pow(s, 64.0) * 0.5);  // glow
  return col;
}

vec3 sunDisc(vec3 dir, vec3 sunDir) {
  float d = dot(dir, sunDir);
  return vec3(1.0, 0.95, 0.8) * smoothstep(0.9996, 0.9998, d) * 30.0;
}