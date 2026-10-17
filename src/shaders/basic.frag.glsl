uniform float uTime;
uniform vec3 uSunDir;
uniform vec3 uWaterColor;
uniform vec3 uScatterColor;
uniform float uSssStrength;
uniform float uRippleStrength;

varying vec3 vNormal;
varying vec3 vWorldPos;
varying float vHeight;

void main() {
  vec3 toEye = cameraPosition - vWorldPos;
  float dist = length(toEye);
  vec3 v = toEye / dist;                                // surface -> eye

  // --- Normal = big waves (vertex shader) + ripples (noise) ---------
  vec3 n = normalize(vNormal);
  vec2 slope = -n.xz / max(n.y, 0.05);                  // normal -> slope
  slope += rippleSlope(vWorldPos.xz, dist, uTime) * uRippleStrength;
  n = normalize(vec3(-slope.x, 1.0, -slope.y));         // slope -> normal

  // Fresnel (Schlick), F0 = 0.02 for water
  float cosTheta = clamp(dot(n, v), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - cosTheta, 5.0);

  // Mirror reflection of the sky
  vec3 r = reflect(-v, n);
  r.y = abs(r.y);
  vec3 reflection = skyGradient(r, uSunDir);

  // --- Water body ---------------------------------------------------
  float sunUp = smoothstep(0.0, 0.3, uSunDir.y);
  float daylight = 0.3 + 0.7 * smoothstep(0.0, 0.5, uSunDir.y);
  vec3 body = uWaterColor * daylight;

  vec3 sssDir = normalize(uSunDir + n * 0.4);
  float sssView = pow(clamp(dot(v, -sssDir), 0.0, 1.0), 4.0);
  float crest = smoothstep(0.15, 0.75, vHeight);
  body += uScatterColor * sssView * crest * sunUp * uSssStrength;

  // --- Sun glint: gets rougher (wider, dimmer) with distance --------
  float nDotL = max(dot(n, uSunDir), 0.0);
  vec3 h = normalize(uSunDir + v);
  float shininess = mix(700.0, 60.0, smoothstep(20.0, 300.0, dist));
  float spec = pow(max(dot(n, h), 0.0), shininess) * (shininess + 8.0) / 25.1327;
  vec3 sunSpec = vec3(1.0, 0.9, 0.75) * spec * fresnel * nDotL;

  vec3 col = mix(body, reflection, fresnel) + sunSpec;

  // --- Horizon haze: blend into the sky so the far edge disappears --
  float fog = 1.0 - exp(-pow(dist * 0.003, 1.5));
  fog = max(fog, smoothstep(250.0, 420.0, dist));
  vec3 fogColor = skyGradient(normalize(vec3(-v.x, 0.02, -v.z)), uSunDir);
  col = mix(col, fogColor, fog);

  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}