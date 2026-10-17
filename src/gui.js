import GUI from 'lil-gui';
import * as THREE from 'three';

export function createGui({ uniforms, renderer }) {
  const gui = new GUI();
  const state = { sunElevation: 12, sunAzimuth: 200 };   // degrees

  function updateSun() {
    const phi = THREE.MathUtils.degToRad(90 - state.sunElevation);   // angle from straight up
    const theta = THREE.MathUtils.degToRad(state.sunAzimuth);        // angle around the vertical axis
    uniforms.uSunDir.value.setFromSphericalCoords(1, phi, theta);
  }

  const waves = gui.addFolder('Waves');
  waves.add(uniforms.uSteepness, 'value', 0, 1, 0.01).name('steepness');

  const sun = gui.addFolder('Sun');
  sun.add(state, 'sunElevation', 1, 90, 0.5).name('elevation').onChange(updateSun);
  sun.add(state, 'sunAzimuth', 0, 360, 1).name('azimuth').onChange(updateSun);

  gui.add(renderer, 'toneMappingExposure', 0.1, 3, 0.01).name('exposure');

  updateSun();   // apply the starting values
  return gui;
}