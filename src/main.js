import * as THREE from 'three';
import { CameraController } from './CameraController.js';
import { material, skyMaterial, uniforms } from './material.js';
import { createGui } from './gui.js';

const canvas = document.getElementById('canvas');

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;

const scene = new THREE.Scene();

const camera = new THREE.PerspectiveCamera(50, 1, 0.1, 200);
const controls = new CameraController(camera, canvas, { distance: 14, pitch: 0.2 });

const geometry = new THREE.PlaneGeometry(20, 20, 256, 256);
geometry.rotateX(-Math.PI / 2);
scene.add(new THREE.Mesh(geometry, material));

// Sky dome: a big sphere we sit inside, drawn before everything else.
const sky = new THREE.Mesh(new THREE.SphereGeometry(100, 32, 16), skyMaterial);
sky.renderOrder = -1;
scene.add(sky);

createGui({ uniforms, renderer });

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.getDrawingBufferSize(uniforms.uResolution.value);
}
window.addEventListener('resize', resize);
resize();

const timer = new THREE.Timer();
timer.connect(document);

renderer.setAnimationLoop((timestamp) => {
  timer.update(timestamp);
  const dt = Math.min(timer.getDelta(), 0.1);
  uniforms.uTime.value = timer.getElapsed();
  controls.update(dt);
  renderer.render(scene, camera);
});