import * as THREE from 'three';
import bathyLib from './shaders/lib/bathymetry.glsl?raw';
import wavesimLib from './shaders/lib/wavesim.glsl?raw';
import memoryLib from './shaders/lib/memory.glsl?raw';
import quadVert from './shaders/sim.vert.glsl?raw';
import memFrag from './shaders/memory.frag.glsl?raw';

/**
 * A texture that remembers: foam that lingers and drifts, and wetness left behind by the water.
 * Reads the wave sim and the terrain, publishes uSurfaceMemory for the ocean and for host materials.
 */
export class SurfaceMemory {
  constructor(renderer, uniforms, { center = [0, 0], size = 400, resolution = 512 } = {}) {
    this.renderer = renderer;
    this.uniforms = uniforms;

    const options = {
      type: THREE.FloatType,         // slow fades are far below half-float precision
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      depthBuffer: false,
    };
    this.read = new THREE.WebGLRenderTarget(resolution, resolution, options);
    this.write = new THREE.WebGLRenderTarget(resolution, resolution, options);

    this.mem = {
      uBathyDepth: uniforms.uBathyDepth,
      uBathyParams: uniforms.uBathyParams,
      uBathyRange: uniforms.uBathyRange,
      uSimState: uniforms.uSimState,
      uSimWindow: uniforms.uSimWindow,
      uSurfaceMemory: uniforms.uSurfaceMemory,
      uMemWindow: uniforms.uMemWindow,
      uFoamLife: uniforms.uFoamLife,
      uWetLife: uniforms.uWetLife,
      uMemDt: { value: 0 },
      uMemInit: { value: 0 },
      uFoamDrift: { value: new THREE.Vector2(0.24, 0.07) },   // roughly the wind direction, 0.25 m/s
    };

    const quad = new THREE.Mesh(
      new THREE.PlaneGeometry(2, 2),
      new THREE.ShaderMaterial({
        vertexShader: quadVert,
        fragmentShader: bathyLib + '\n' + wavesimLib + '\n' + memoryLib + '\n' + memFrag,
        uniforms: this.mem,
        depthTest: false,
        depthWrite: false,
      })
    );
    quad.frustumCulled = false;
    this.scene = new THREE.Scene();
    this.scene.add(quad);
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

    uniforms.uMemWindow.value.set(center[0], center[1], size, 0);

    this.mem.uMemInit.value = 1;
    this._draw(this.read);
    this.mem.uMemInit.value = 0;
    uniforms.uSurfaceMemory.value = this.read.texture;
    this.lastTime = uniforms.uTime.value;
  }

  // Call once per frame, after the wave sim has updated.
  update() {
    const now = this.uniforms.uTime.value;
    const dt = Math.min(now - this.lastTime, 0.1);
    this.lastTime = now;
    if (dt <= 0) return;

    this.mem.uMemDt.value = dt;
    this._draw(this.write);
    [this.read, this.write] = [this.write, this.read];
    this.uniforms.uSurfaceMemory.value = this.read.texture;
  }

  _draw(target) {
    const previous = this.renderer.getRenderTarget();
    this.renderer.setRenderTarget(target);
    this.renderer.render(this.scene, this.camera);
    this.renderer.setRenderTarget(previous);
  }
}