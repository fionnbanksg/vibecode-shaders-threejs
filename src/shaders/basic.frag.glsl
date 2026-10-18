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

uniform sampler2D uSceneColor;
uniform sampler2D uSceneDepth;
uniform vec2 uResolution;
uniform float uCameraNear;
uniform float uCameraFar;
uniform float uDebug;
uniform vec3 uAbsorption;
uniform float uRefraction;
uniform float uShoreWidth;



// Depth-buffer value (0..1) to distance along the view axis, in metres.
float sceneViewZ(float d) {
  return (uCameraNear * uCameraFar) / (uCameraFar - d * (uCameraFar - uCameraNear));
}


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
    // --- Whatever the host scene drew under the water ---------------------
  // --- Whatever the host scene drew under the water ---------------------
  vec2 screenUv = gl_FragCoord.xy / uResolution;
  float waterZ = max(-(viewMatrix * vec4(vWorldPos, 1.0)).z, 0.001);   // distance along the view axis

  // Refraction: shift the lookup by the surface tilt, measured against flat water, in view space.
  vec2 tilt = (viewMatrix * vec4(n, 0.0)).xy - (viewMatrix * vec4(0.0, 1.0, 0.0, 0.0)).xy;
  float firstDepth = texture2D(uSceneDepth, screenUv).x;
  float firstThickness = (firstDepth < 0.9999)
      ? max(sceneViewZ(firstDepth) - waterZ, 0.0) * dist / waterZ
      : 1000.0;
  vec2 refrUv = clamp(screenUv + tilt * (uRefraction * min(firstThickness, 3.0) / waterZ), 0.001, 0.999);

  // A refracted lookup that lands on something in front of the water (beach, rock) would leak: reject it.
  float refrDepth = texture2D(uSceneDepth, refrUv).x;
  bool refrOk = refrDepth >= 0.9999 || sceneViewZ(refrDepth) > waterZ;
  vec2 sceneUv = refrOk ? refrUv : screenUv;
  float sceneDepthRaw = refrOk ? refrDepth : firstDepth;

  bool hasScene = sceneDepthRaw < 0.9999;                         // 1.0 = nothing there
  float thickness = hasScene
      ? max(sceneViewZ(sceneDepthRaw) - waterZ, 0.0) * dist / waterZ   // metres of water along the eye ray
      : 1000.0;                                                   // nothing below: bottomless
  vec3 sceneCol = hasScene ? texture2D(uSceneColor, sceneUv).rgb : body;

  // Beer-Lambert: each channel is absorbed at its own rate, red first.
  vec3 transmit = exp(-uAbsorption * thickness);
  vec3 under = mix(body, sceneCol, transmit);

  // Shoreline foam: where the water gets thin, ragged with the same noise as the crest foam.
  float shoreMask = 1.0 - smoothstep(0.0, uShoreWidth, thickness);
  float shoreFoam = smoothstep(0.45, 0.6, shoreMask * 1.1 + (foamTex - 0.5) * 0.9) * foamFade * uFoamStrength;
  foam = max(foam, shoreFoam);

  vec3 col = mix(under, reflection, fresnel);
  col = mix(sceneCol, col, smoothstep(0.0, 0.1, thickness));      // water vanishes cleanly at the beach


  // --- Debug views (uDebug). One if/else chain, so the order doesn't matter. ---
  if (uDebug > 0.5) {
    if (uDebug < 1.5) {
      col = vec3(1.0 - exp(-thickness * 0.2));                                    // water thickness
    } else if (uDebug < 2.5) {
      col = sceneCol;                                                             // captured scene
    } else if (uDebug < 3.5) {                                                    // terrain height
      float th = terrainHeight(vWorldPos.xz);
      float t = clamp((th + 14.0) / 17.0, 0.0, 1.0);                              // demo range: -14 m to +3 m
      col = mix(vec3(0.0, 0.15, 0.4), vec3(0.85, 0.75, 0.45), t);
      col = mix(col, vec3(0.0), 0.5 * (1.0 - smoothstep(0.0, 0.06, abs(fract(th + 0.5) - 0.5))));
      col = mix(col, vec3(1.0, 0.0, 0.0), 1.0 - smoothstep(0.0, 0.15, abs(th)));  // red = shoreline
    } else if (uDebug < 4.5) {                                                    // sim wave height
      float e = sampleWaveSim(vWorldPos.xz).x;
      col = vec3(0.5) + vec3(0.5, 0.1, -0.5) * clamp(e / 1.5, -1.0, 1.0);         // orange crest, blue trough
    } else {                                                                      // sim minus deep-water swell, x4
      float r = sampleWaveSim(vWorldPos.xz).z;
      col = vec3(0.5) + vec3(0.5, 0.1, -0.5) * clamp(r * 4.0 / 1.5, -1.0, 1.0);
    }
  }
    //col = vec3(fract(terrainHeight(vWorldPos.xz)));   // TEMP: a sawtooth, one band per metre of terrain height                                            // debug: captured scene
  gl_FragColor = vec4(col, 1.0);
      if (uDebug > 2.5) {   // debug: terrain height. Dark lines every 1 m, red line = rest-level shoreline
    float th = terrainHeight(vWorldPos.xz);
    float t = clamp((th + 14.0) / 17.0, 0.0, 1.0);                 // demo range: -14 m (deep) to +3 m (dune top)
    col = mix(vec3(0.0, 0.15, 0.4), vec3(0.85, 0.75, 0.45), t);
    col = mix(col, vec3(0.0), 0.5 * (1.0 - smoothstep(0.0, 0.06, abs(fract(th + 0.5) - 0.5))));
    col = mix(col, vec3(1.0, 0.0, 0.0), 1.0 - smoothstep(0.0, 0.15, abs(th)));
  }
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}