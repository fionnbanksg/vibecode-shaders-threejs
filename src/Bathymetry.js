import * as THREE from 'three';

/**
 * Captures the height of whatever the host scene has near the water, looking straight down,
 * and publishes it as uniforms. Static by default: call capture() again if the terrain changes.
 * It knows nothing about beaches: anything the scene draws becomes seabed or shore.
 */
export class Bathymetry {
  constructor(uniforms, { center = [0, 0], size = 400, resolution = 512, top = 20, bottom = -40 } = {}) {
    this.uniforms = uniforms;

    // Orthographic camera above the window looking straight down.
    // With up = -Z, screen-right is +X and screen-up is -Z.
    this.camera = new THREE.OrthographicCamera(-size / 2, size / 2, size / 2, -size / 2, 0.1, top - bottom);
    this.camera.up.set(0, 0, -1);
    this.camera.position.set(center[0], top, center[1]);
    this.camera.lookAt(center[0], 0, center[1]);
    this.camera.updateMatrixWorld();

    this.target = new THREE.WebGLRenderTarget(resolution, resolution, {
      depthTexture: new THREE.DepthTexture(resolution, resolution),
    });

    uniforms.uBathyDepth.value = this.target.depthTexture;
    uniforms.uBathyParams.value.set(center[0], center[1], size, top);
    uniforms.uBathyRange.value.set(this.camera.near, this.camera.far);
  }

  // `hide`: objects that are not terrain (the water itself, the sky dome).
  capture(renderer, scene, hide = []) {
    const wasVisible = hide.map((o) => o.visible);
    hide.forEach((o) => (o.visible = false));

    const previousTarget = renderer.getRenderTarget();
    renderer.setRenderTarget(this.target);
    renderer.render(scene, this.camera);
    renderer.setRenderTarget(previousTarget);

    hide.forEach((o, i) => (o.visible = wasVisible[i]));
  }
}