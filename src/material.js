import * as THREE from 'three';

import waterVert from './shaders/basic.vert.glsl?raw';
import waterFrag from './shaders/basic.frag.glsl?raw';
import skyLib from './shaders/lib/sky.glsl?raw';
import noiseLib from './shaders/lib/noise.glsl?raw';
import bathyLib from './shaders/lib/bathymetry.glsl?raw';
import wavesimLib from './shaders/lib/wavesim.glsl?raw';
import memoryLib from './shaders/lib/memory.glsl?raw';
import skyVert from './shaders/sky.vert.glsl?raw';
import skyFrag from './shaders/sky.frag.glsl?raw';

// One uniforms object shared by every material. A shader ignores uniforms it doesn't declare.
export const uniforms = {
  uTime: { value: 0 },
  uResolution: { value: new THREE.Vector2(1, 1) },
  uSteepness: { value: 0.7 },
  uSunDir: { value: new THREE.Vector3(0.4, 0.35, 0.3).normalize() },
  uWaterColor: { value: new THREE.Color(0x0a4a5c) },
  uScatterColor: { value: new THREE.Color(0x2fd0b8) },
  uSssStrength: { value: 3.0 },
  uRippleStrength: { value: 1.0 },
  uFoamThreshold: { value: 0.5 },
  uFoamStrength: { value: 1.0 },
  uSceneColor: { value: null },     // set by SceneCapture
  uSceneDepth: { value: null },
  uCameraNear: { value: 0.5 },
  uCameraFar: { value: 5000 },
  uDebug: { value: 0 },
  uAbsorption: { value: new THREE.Vector3(0.45, 0.12, 0.08) },   // per metre, for red / green / blue
  uRefraction: { value: 0.3 },
  uShoreWidth: { value: 0.5 },                                   // metres of water where shore foam shows
  uBathyDepth: { value: null },                                  // set by Bathymetry
  uBathyParams: { value: new THREE.Vector4(0, 0, 400, 20) },
  uBathyRange: { value: new THREE.Vector2(0.1, 60) },
  uSimState: { value: null },                                    // set by WaveSim
  uSimWindow: { value: new THREE.Vector4(0, 0, 400, 1) },
  uSimBlend: { value: 1.0 },                                     // 0 = the old Gerstner ocean, 1 = sim-informed
  uSurfaceMemory: { value: null },                               // set by SurfaceMemory
  uMemWindow: { value: new THREE.Vector4(0, 0, 400, 0) },
  uFoamLife: { value: 6.0 },                                     // seconds for foam to fade
  uWetLife: { value: 30.0 },                                     // seconds for wet sand to dry
};

// Current source strings, kept so hot reload can rebuild either material.
const src = { waterVert, waterFrag, skyLib, noiseLib, skyVert, skyFrag, bathyLib, wavesimLib, memoryLib };

// Libraries first, then the shader that uses them.
const waterFragment = () =>
  src.skyLib + '\n' + src.bathyLib + '\n' + src.wavesimLib + '\n' + src.memoryLib + '\n' + src.noiseLib + '\n' + src.waterFrag;
const waterVertex = () => src.wavesimLib + '\n' + src.waterVert;   // the vertex shader reads the sim too
const skyFragment = () => src.skyLib + '\n' + src.skyFrag;

export const material = new THREE.ShaderMaterial({
  vertexShader: waterVertex(),
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

      material.vertexShader = waterVertex();
      material.fragmentShader = waterFragment();
      skyMaterial.vertexShader = src.skyVert;
      skyMaterial.fragmentShader = skyFragment();
      material.needsUpdate = true;
      skyMaterial.needsUpdate = true;
    }
  );
}