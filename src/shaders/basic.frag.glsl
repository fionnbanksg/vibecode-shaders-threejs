uniform vec3 uSunDir;
uniform vec3 uWaterColor;

varying vec3 vNormal;
varying vec3 vWorldPos;

void main() {
  vec3 n = normalize(vNormal);
  vec3 v = normalize(cameraPosition - vWorldPos);      // surface -> eye

  // Fresnel (Schlick), F0 = 0.02 for water
  float cosTheta = clamp(dot(n, v), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - cosTheta, 5.0);

  // Mirror reflection of the sky
  vec3 r = reflect(-v, n);
  r.y = abs(r.y);                                      // cheap fix: never reflect below the horizon
  vec3 reflection = skyGradient(r, uSunDir);

  // Light scattered back out of the water body (crude for now)
  float nDotL = max(dot(n, uSunDir), 0.0);
  vec3 body = uWaterColor * (0.3 + 0.7 * nDotL);

  // Sun glint: Blinn-Phong with energy normalisation
  vec3 h = normalize(uSunDir + v);
  float shininess = 700.0;
  float spec = pow(max(dot(n, h), 0.0), shininess) * (shininess + 8.0) / 25.1327;  // 8*pi
  vec3 sunSpec = vec3(1.0, 0.9, 0.75) * spec * fresnel * nDotL;

  vec3 col = mix(body, reflection, fresnel) + sunSpec;

  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}