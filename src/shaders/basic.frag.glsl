uniform float uTime;
uniform vec3 uSunDir;
uniform vec3 uWaterColor;
uniform vec3 uScatterColor;
uniform float uSssStrength;
uniform float uRippleStrength;
uniform float uFoamThreshold;
uniform float uFoamStrength;
varying float vJacobian;



varying vec3 vNormal;
varying vec3 vWorldPos;
varying float vHeight;
varying float vLostVar;
void main() {
  vec3 toEye = cameraPosition - vWorldPos;
  float dist = length(toEye);
  vec3 v = toEye / dist;                                // surface -> eye

  // --- Normal = big waves (vertex shader) + ripples (noise) ---------
  vec3 n = normalize(vNormal);
  vec2 slope = -n.xz / max(n.y, 0.05);                  // normal -> slope
    // Wind gusts: big, slowly drifting patches of rougher and calmer water.
  float gustNoise = noised(vWorldPos.xz * 0.04 + vec2(0.6, 0.2) * uTime * 0.1).x;
  float gust = mix(0.35, 1.6, smoothstep(0.25, 0.75, gustNoise));
  float rippleLost;
  vec2 ripples = rippleSlope(vWorldPos.xz, dist, uTime, rippleLost);
  float rk = uRippleStrength * gust;
  slope += ripples * rk;
  // Variance the LOD fades discarded, put back as roughness. Beckmann: m^2 = 2 * per-axis variance.
  float m2 = 0.00285 + 2.0 * (vLostVar + rippleLost * rk * rk);
  n = normalize(vec3(-slope.x, 1.0, -slope.y));         // slope -> normal

  // Fresnel (Schlick), F0 = 0.02 for water
  float cosTheta = clamp(dot(n, v), 0.0, 1.0);
    // Roughness-aware Schlick: rough water never reaches a perfect mirror at grazing angles.
  float rough = clamp(sqrt(m2) * 1.5, 0.0, 0.6);   // the 1.5 is a tuned fudge, not physics
  float fresnel = 0.02 + (max(1.0 - rough, 0.02) - 0.02) * pow(1.0 - cosTheta, 5.0);

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
  float crest = smoothstep(0.35, 0.75, vHeight);
  body += uScatterColor * sssView * crest * sunUp * uSssStrength;

  // --- Sun glint: gets rougher (wider, dimmer) with distance --------
  float nDotL = max(dot(n, uSunDir), 0.0);
  vec3 h = normalize(uSunDir + v);
    float shininess = max(2.0 / m2 - 2.0, 4.0);   // Beckmann roughness to Blinn-Phong exponent
  float spec = pow(max(dot(n, h), 0.0), shininess) * (shininess + 8.0) / 25.1327;
  vec3 sunSpec = vec3(1.0, 0.9, 0.75) * spec * fresnel * nDotL;
  // --- Foam: Jacobian mask, eroded by multi-scale noise so it breaks into lace ---
  float foamMask = 1.0 - smoothstep(uFoamThreshold - 0.3, uFoamThreshold, vJacobian);
    vec2 fq = (vWorldPos.xz + vec2(0.25, -0.15) * uTime) * 1.5;
  float foamTex = 0.0;
  float fa = 0.5;
  for (int i = 0; i < 4; i++) {
    foamTex += fa * noised(fq).x;
    fq = OCTAVE_ROT * fq * 2.3;
    fa *= 0.5;
  }
  foamTex /= 0.9375;   // divide by the sum of the amplitudes
  float foam = smoothstep(0.45, 0.6, foamMask * 1.1 + (foamTex - 0.5) * 0.9);
  float foamFade = 1.0 - smoothstep(80.0, 250.0, dist);   // fine noise aliases far away
  foam *= foamFade * uFoamStrength;

  // --- Spray (fake): sparse bright specks just outside the foam, blown downwind ---
  float halo = 1.0 - smoothstep(uFoamThreshold, uFoamThreshold + 0.35, vJacobian);
  float speck = smoothstep(0.78, 0.88, noised(vWorldPos.xz * 16.0 - vec2(0.955, 0.296) * uTime * 40.0).x);
  float spray = halo * speck * (1.0 - foam) * (1.0 - smoothstep(40.0, 120.0, dist)) * uFoamStrength;

  // Foam is diffuse: sky ambient plus sun, instead of mirror reflection.
  vec3 foamCol = (vec3(0.45, 0.55, 0.65) + vec3(1.0, 0.92, 0.8) * nDotL * 0.9) * daylight;
  vec3 col = mix(body, reflection, fresnel);
  col = mix(col, foamCol, foam);
  col += sunSpec * (1.0 - foam);          // foam is rough, so it hides the glint
  col = mix(col, foamCol, spray * 0.8);
  col = mix(col, vec3(0.9, 0.93, 0.95) * daylight, foam);
  // --- Horizon haze: blend into the sky so the far edge disappears --
  float fog = 1.0 - exp(-pow(dist * 0.003, 1.5));
  fog = max(fog, smoothstep(250.0, 420.0, dist));
  vec3 fogColor = skyGradient(normalize(vec3(-v.x, 0.0, -v.z)), uSunDir);
  col = mix(col, fogColor, fog);

  gl_FragColor = vec4(col, 1.0);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}