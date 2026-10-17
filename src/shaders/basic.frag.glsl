precision highp float;

uniform float uTime;

varying vec3 vNormal;
varying vec3 vWorldPos;

//#define DEBUG_NORMALS   // comment this line out to see the lit version

void main() {
  vec3 n = normalize(vNormal);   // interpolation shortens vectors, so renormalise

#ifdef DEBUG_NORMALS
  gl_FragColor = vec4(n * 0.5 + 0.5, 1.0);   // remap [-1,1] -> [0,1] to view as colour
#else
  vec3 lightDir = normalize(vec3(0.4, 0.8, 0.3));
  float diffuse = max(dot(n, lightDir), 0.0);
  vec3 waterColor = vec3(0.02, 0.18, 0.28);
  gl_FragColor = vec4(waterColor * (0.3 + 0.7 * diffuse), 1.0);
#endif
}