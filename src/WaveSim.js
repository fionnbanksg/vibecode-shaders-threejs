import * as THREE from 'three';
import bathyLib from './shaders/lib/bathymetry.glsl?raw';
import swellLib from './shaders/lib/swell.glsl?raw';
import simVert from './shaders/sim.vert.glsl?raw';
import simFrag from './shaders/sim.frag.glsl?raw';

/**
 * Local wave simulation. Reads terrain depth (from Bathymetry), evolves the surface height with
 * a depth-dependent wave speed, and publishes the state as uniforms for the ocean to read.
 * Knows nothing about beaches: depth comes only from the capture.
 */
export class WaveSim {
  constructor(renderer, uniforms, { center = [0, 0], size = 400, resolution = 256, step = 1 / 60 } = {}) {
    this.renderer = renderer;
    this.uniforms = uniforms;
    this.step = step;

    const options = {
      type: THREE.FloatType,            // 32-bit: the per-step change is far below half-float precision
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      depthBuffer: false,
    };
    this.read = new THREE.WebGLRenderTarget(resolution, resolution, options);
    this.write = new THREE.WebGLRenderTarget(resolution, resolution, options);

    this.sim = {
      // Shared with the ocean, so the same sliders and the same terrain drive both.
      uBathyDepth: uniforms.uBathyDepth,
      uBathyParams: uniforms.uBathyParams,
      uBathyRange: uniforms.uBathyRange,
      uSteepness: uniforms.uSteepness,
      // The sim's own.
      uState: { value: null },
      uSimTime: { value: 0 },
      uDt: { value: step },
      uInit: { value: 0 },
      uSimCenter: { value: new THREE.Vector2(center[0], center[1]) },
      uSimSize: { value: size },
      uTexel: { value: new THREE.Vector2(1 / resolution, 1 / resolution) },
      uRelaxRate: { value: 3.0 },
      uBaseDamping: { value: 0.02 },
      uBreakRate: { value: 2.0 },
    };

    const quad = new THREE.Mesh(
      new THREE.PlaneGeometry(2, 2),
      new THREE.ShaderMaterial({
        vertexShader: simVert,
        fragmentShader: bathyLib + '\n' + swellLib + '\n' + simFrag,
        uniforms: this.sim,
        depthTest: false,
        depthWrite: false,
      })
    );
    quad.frustumCulled = false;
    this.scene = new THREE.Scene();
    this.scene.add(quad);
    this.camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

    uniforms.uSimWindow.value.set(center[0], center[1], size, 1);

    // Start in equilibrium with the deep-water swell, so nothing has to roll in from the edges.
    this.time = uniforms.uTime.value;
    this.sim.uSimTime.value = this.time;
    this.sim.uInit.value = 1;
    this._draw(this.read);
    this.sim.uInit.value = 0;
    uniforms.uSimState.value = this.read.texture;
  }

  // Call once per frame, after uTime is updated.
  update() {
    const now = this.uniforms.uTime.value;
    if (now - this.time > 4 * this.step) this.time = now - 4 * this.step;   // after a hitch, don't spiral
    while (this.time + this.step <= now) this._step();
  }

  _step() {
    this.time += this.step;
    this.sim.uState.value = this.read.texture;
    this.sim.uSimTime.value = this.time;
    this._draw(this.write);
    [this.read, this.write] = [this.write, this.read];
    this.uniforms.uSimState.value = this.read.texture;
  }

  _draw(target) {
    const previous = this.renderer.getRenderTarget();
    this.renderer.setRenderTarget(target);
    this.renderer.render(this.scene, this.camera);
    this.renderer.setRenderTarget(previous);
  }
}