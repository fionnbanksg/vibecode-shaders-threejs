import * as THREE from 'three';
import { CameraController } from './CameraController.js';
import { material, uniforms } from './material.js';

const canvas = document.getElementById('canvas');

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x111111);

const camera = new THREE.PerspectiveCamera(50, 1, 0.1, 200);
const controls = new CameraController(camera, canvas, { distance: 30, pitch: 0.45 });

// Swap this for BoxGeometry / SphereGeometry / etc. Raise segments for vertex-shader work.
const geometry = new THREE.PlaneGeometry(20, 20, 256, 256);
geometry.rotateX(-Math.PI / 2);
const mesh = new THREE.Mesh(geometry, material);
scene.add(mesh);

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
timer.connect(document); // handles the tab being hidden/shown cleanly

renderer.setAnimationLoop((timestamp) => {
  timer.update(timestamp);                 // tell it "now" (milliseconds)
  const dt = Math.min(timer.getDelta(), 0.1);
  uniforms.uTime.value = timer.getElapsed();
  controls.update(dt);
  renderer.render(scene, camera);
});