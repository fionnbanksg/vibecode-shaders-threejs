import * as THREE from 'three';

import waterVert from './shaders/basic.vert.glsl?raw';
import waterFrag from './shaders/basic.frag.glsl?raw';
import skyLib from './shaders/lib/sky.glsl?raw';
import noiseLib from './shaders/lib/noise.glsl?raw';
import skyVert from './shaders/sky.vert.glsl?raw';
import skyFrag from './shaders/sky.frag.glsl?raw';

// One uniforms object shared by both materials. A shader ignores uniforms it doesn't declare.
export const uniforms = {
  uTime: { value: 0 },
  uResolution: { value: new THREE.Vector2(1, 1) },
  uSteepness: { value: 0.7 },
  uSunDir: { value: new THREE.Vector3(0.4, 0.35, 0.3).normalize() },
  uWaterColor: { value: new THREE.Color(0x0a4a5c) },
  uScatterColor: { value: new THREE.Color(0x2fd0b8) },
  uSssStrength: { value: 3.0 },
  uRippleStrength: { value: 1.0 },
};

// Current source strings, kept so hot reload can rebuild either material.
const src = { waterVert, waterFrag, skyLib, noiseLib, skyVert, skyFrag };

// Libraries first, then the shader that uses them.
const waterFragment = () => src.skyLib + '\n' + src.noiseLib + '\n' + src.waterFrag;
const skyFragment = () => src.skyLib + '\n' + src.skyFrag;

export const material = new THREE.ShaderMaterial({
  vertexShader: src.waterVert,
  fragmentShader: waterFragment(),
  uniforms,
  side: THREE.DoubleSide,
});

export const skyMaterial = new THREE.ShaderMaterial({
  vertexShader: src.skyVert,
  fragmentShader: skyFragment(),
  uniforms,
  side: THREE.BackSide,
  depthWrite: false,
});

if (import.meta.hot) {
  import.meta.hot.accept(
    [
      './shaders/basic.vert.glsl?raw',
      './shaders/basic.frag.glsl?raw',
      './shaders/lib/sky.glsl?raw',
      './shaders/lib/noise.glsl?raw',
      './shaders/sky.vert.glsl?raw',
      './shaders/sky.frag.glsl?raw',
    ],
    ([wv, wf, sl, nl, sv, sf]) => {
      // Only the modules that changed are defined; the rest are undefined.
      if (wv) src.waterVert = wv.default;
      if (wf) src.waterFrag = wf.default;
      if (sl) src.skyLib = sl.default;
      if (nl) src.noiseLib = nl.default;
      if (sv) src.skyVert = sv.default;
      if (sf) src.skyFrag = sf.default;

      material.vertexShader = src.waterVert;
      material.fragmentShader = waterFragment();
      skyMaterial.vertexShader = src.skyVert;
      skyMaterial.fragmentShader = skyFragment();
      material.needsUpdate = true;
      skyMaterial.needsUpdate = true;
    }
  );
}