uniform vec3 uSunDir;
uniform vec3 uWaterColor;
uniform vec3 uScatterColor;
uniform float uSssStrength;

varying vec3 vNormal;
varying vec3 vWorldPos;
varying float vHeight;

void main() {
  vec3 n = normalize(vNormal);
  vec3 v = normalize(cameraPosition - vWorldPos);      // surface -> eye

  // Fresnel (Schlick), F0 = 0.02 for water
  float cosTheta = clamp(dot(n, v), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - cosTheta, 5.0);

  // Mirror reflection of the sky
  vec3 r = reflect(-v, n);
  r.y = abs(r.y);
  vec3 reflection = skyGradient(r, uSunDir);

  // --- Water body ---------------------------------------------------
  float sunUp = smoothstep(0.0, 0.3, uSunDir.y);       // 0 at the horizon, 1 once the sun is up
  float daylight = 0.3 + 0.7 * smoothstep(0.0, 0.5, uSunDir.y);
  vec3 body = uWaterColor * daylight;

  // Fake subsurface scattering: sun light travelling through a thin crest toward the eye.
  vec3 sssDir = normalize(uSunDir + n * 0.4);
  float sssView = pow(clamp(dot(v, -sssDir), 0.0, 1.0), 4.0);
  float crest = smoothstep(0.15, 0.75, vHeight);
  body += uScatterColor * sssView * crest * sunUp * uSssStrength;

  // --- Sun glint (Blinn-Phong, energy normalised) -------------------
  float nDotL = max(dot(n, uSunDir), 0.0);
  vec3 h = normalize(uSunDir + v);
  float shininess = 700.0;
  float spec = pow(max(dot(n, h), 0.0), shininess) * (shininess + 8.0) / 25.1327;
  vec3 sunSpec = vec3(1.0, 0.9, 0.75) * spec * fresnel * nDotL;

  vec3 col = mix(body, reflection, fresnel) + sunSpec;

  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}