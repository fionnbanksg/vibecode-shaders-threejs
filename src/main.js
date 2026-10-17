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

const camera = new THREE.PerspectiveCamera(50, 1, 0.5, 5000);
const controls = new CameraController(camera, canvas, { distance: 14, pitch: 0.2, maxDistance: 150 });

// A big plane whose vertex spacing grows with distance from the centre.
// halfSize: metres from centre to edge. growth: how fast spacing grows.
function remap(u, k, growth) {
  return Math.sign(u) * k * (Math.exp(growth * Math.abs(u)) - 1);
}

function createOceanGeometry(halfSize, segments, growth) {
  const geometry = new THREE.PlaneGeometry(2, 2, segments, segments);   // x, y in [-1, 1]
  geometry.rotateX(-Math.PI / 2);                                       // now x, z in [-1, 1]; y is up

  const k = halfSize / (Math.exp(growth) - 1);
  const pos = geometry.attributes.position;                             // a flat array of x,y,z triples
  for (let i = 0; i < pos.count; i++) {
    pos.setX(i, remap(pos.getX(i), k, growth));
    pos.setZ(i, remap(pos.getZ(i), k, growth));
  }
  pos.needsUpdate = true;
  return geometry;
}

scene.add(new THREE.Mesh(createOceanGeometry(500, 512, 5.1), material));
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