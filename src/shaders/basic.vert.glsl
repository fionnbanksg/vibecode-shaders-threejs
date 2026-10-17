uniform float uTime;

varying vec3 vNormal;
varying vec3 vWorldPos;

const float GRAVITY = 9.81;
const float TAU = 6.28318530718;

// Returns vec3(height, dHeight/dx, dHeight/dz)
vec3 sineWave(vec2 p, vec2 dir, float wavelength, float amplitude) {
  vec2 d = normalize(dir);
  float k = TAU / wavelength;
  float omega = sqrt(GRAVITY * k);          // deep-water dispersion
  float phase = k * dot(d, p) - omega * uTime;
  float c = cos(phase);
  return vec3(amplitude * sin(phase),
              amplitude * k * c * d.x,
              amplitude * k * c * d.y);
}

void main() {
  vec2 p = position.xz;

  vec3 w = vec3(0.0);
  w += sineWave(p, vec2( 1.0,  0.3), 8.0, 0.30);
  w += sineWave(p, vec2(-0.6,  1.0), 4.0, 0.12);
  w += sineWave(p, vec2( 0.2, -1.0), 2.0, 0.05);

  vec3 displaced = position;
  displaced.y += w.x;

  vNormal = normalize(vec3(-w.y, 1.0, -w.z));

  vec4 world = modelMatrix * vec4(displaced, 1.0);
  vWorldPos = world.xyz;
  gl_Position = projectionMatrix * viewMatrix * world;
}