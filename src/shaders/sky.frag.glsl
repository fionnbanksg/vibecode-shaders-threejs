uniform vec3 uSunDir;
varying vec3 vWorldPos;

void main() {
  vec3 dir = normalize(vWorldPos - cameraPosition);   // where is this pixel looking?
  vec3 col = skyGradient(dir, uSunDir) + sunDisc(dir, uSunDir);

  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}