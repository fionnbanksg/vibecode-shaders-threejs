import * as THREE from 'three';

import waterVert from './shaders/basic.vert.glsl?raw';
import waterFrag from './shaders/basic.frag.glsl?raw';
import skyLib from './shaders/lib/sky.glsl?raw';
import skyVert from './shaders/sky.vert.glsl?raw';
import skyFrag from './shaders/sky.frag.glsl?raw';

// One uniforms object shared by both materials. A shader ignores uniforms it doesn't declare.
export const uniforms = {
  uTime: { value: 0 },
  uResolution: { value: new THREE.Vector2(1, 1) },
  uSteepness: { value: 0.7 },
  uSunDir: { value: new THREE.Vector3(0.4, 0.35, 0.3).normalize() },
  // Hex colours are treated as sRGB and converted to linear by three automatically.
  uWaterColor: { value: new THREE.Color(0x0a4a5c) },
};

// Keep the current source strings so hot reload can rebuild either material.
const src = { waterVert, waterFrag, skyLib, skyVert, skyFrag };

export const material = new THREE.ShaderMaterial({
  vertexShader: src.waterVert,
  fragmentShader: src.skyLib + '\n' + src.waterFrag,   // library first, then the shader that uses it
  uniforms,
  side: THREE.DoubleSide,
});

export const skyMaterial = new THREE.ShaderMaterial({
  vertexShader: src.skyVert,
  fragmentShader: src.skyLib + '\n' + src.skyFrag,
  uniforms,
  side: THREE.BackSide,     // we're inside the sphere, so draw its inner faces
  depthWrite: false,
});

if (import.meta.hot) {
  import.meta.hot.accept(
    [
      './shaders/basic.vert.glsl?raw',
      './shaders/basic.frag.glsl?raw',
      './shaders/lib/sky.glsl?raw',
      './shaders/sky.vert.glsl?raw',
      './shaders/sky.frag.glsl?raw',
    ],
    ([wv, wf, lib, sv, sf]) => {
      // Only the modules that changed are defined; the rest are undefined.
      if (wv) src.waterVert = wv.default;
      if (wf) src.waterFrag = wf.default;
      if (lib) src.skyLib = lib.default;
      if (sv) src.skyVert = sv.default;
      if (sf) src.skyFrag = sf.default;

      material.vertexShader = src.waterVert;
      material.fragmentShader = src.skyLib + '\n' + src.waterFrag;
      skyMaterial.vertexShader = src.skyVert;
      skyMaterial.fragmentShader = src.skyLib + '\n' + src.skyFrag;
      material.needsUpdate = true;
      skyMaterial.needsUpdate = true;
    }
  );
}