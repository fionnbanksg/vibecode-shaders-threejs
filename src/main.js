import * as THREE from 'three';
import { CameraController } from './CameraController.js';
import { material, skyMaterial, uniforms } from './material.js';
import { createGui } from './gui.js';
import { SceneCapture } from './SceneCapture.js';
import { createDemoTerrain } from './demo/beach.js';   // demo only
import { Bathymetry } from './Bathymetry.js';
import { WaveSim } from './WaveSim.js';
import { SurfaceMemory } from './SurfaceMemory.js';


const canvas = document.getElementById('canvas');
          // foam and wet sand
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
const memory = new SurfaceMemory(renderer, uniforms); 
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;

const scene = new THREE.Scene();
const sim = new WaveSim(renderer, uniforms);                    // window matches the bathymetry
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

const ocean = new THREE.Mesh(createOceanGeometry(500, 512, 5.1), material);
scene.add(ocean);
scene.add(createDemoTerrain());   // demo only: a sloping beach to test the water against
// Sky dome: a big sphere we sit inside, drawn before everything else.
const sky = new THREE.Mesh(new THREE.SphereGeometry(100, 32, 16), skyMaterial);
sky.renderOrder = -1;
scene.add(sky);


const capture = new SceneCapture(uniforms);
const bathymetry = new Bathymetry(uniforms);                    // window matches the 400 m demo terrain
bathymetry.capture(renderer, scene, [ocean, sky]);              // static terrain: capture once
createGui({ uniforms, renderer });

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.getDrawingBufferSize(uniforms.uResolution.value);
  capture.setSize(uniforms.uResolution.value.x, uniforms.uResolution.value.y);
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
  sim.update();
  memory.update();
  capture.render(renderer, scene, camera, [ocean, sky]);   // what is under the water
  renderer.render(scene, camera);
});