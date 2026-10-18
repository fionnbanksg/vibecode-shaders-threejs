import GUI from 'lil-gui';
import * as THREE from 'three';

// THREE.Color stores LINEAR values, but colour pickers work in sRGB.
// So the picker edits a plain hex string ("proxy"), and onChange copies it into the uniform;
// Color.set() converts sRGB -> linear for us.
function addColor(folder, uniform, name) {
  const proxy = { color: '#' + uniform.value.getHexString() };
  folder.addColor(proxy, 'color').name(name).onChange((hex) => uniform.value.set(hex));
}

export function createGui({ uniforms, renderer }) {
  const gui = new GUI();
  const state = { sunElevation: 12, sunAzimuth: 200 };   // degrees

  function updateSun() {
    const phi = THREE.MathUtils.degToRad(90 - state.sunElevation);
    const theta = THREE.MathUtils.degToRad(state.sunAzimuth);
    uniforms.uSunDir.value.setFromSphericalCoords(1, phi, theta);
  }

  const waves = gui.addFolder('Waves');
  waves.add(uniforms.uSteepness, 'value', 0, 2, 0.01).name('steepness');
  waves.add(uniforms.uRippleStrength, 'value', 0, 3, 0.01).name('ripple strength');
  waves.add(uniforms.uFoamThreshold, 'value', 0, 1, 0.01).name('foam threshold');
  waves.add(uniforms.uFoamStrength, 'value', 0, 1, 0.01).name('foam strength');

  const water = gui.addFolder('Water');
  addColor(water, uniforms.uWaterColor, 'deep colour');
  addColor(water, uniforms.uScatterColor, 'scatter colour');
  water.add(uniforms.uSssStrength, 'value', 0, 10, 0.1).name('sss strength');

  const sun = gui.addFolder('Sun');
  sun.add(state, 'sunElevation', 1, 190, 0.5).name('elevation').onChange(updateSun);
  sun.add(state, 'sunAzimuth', 0, 360, 1).name('azimuth').onChange(updateSun);

  gui.add(renderer, 'toneMappingExposure', 0.1, 3, 0.01).name('exposure');

  updateSun();
  return gui;
}