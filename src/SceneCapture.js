import * as THREE from 'three';

/**
 * Renders the host scene (minus the objects you hide) into a colour + depth texture,
 * and publishes them as uniforms. The water reads these to see what is under the surface.
 * It knows nothing about beaches, seabeds or any particular geometry.
 */
export class SceneCapture {
  constructor(uniforms) {
    this.uniforms = uniforms;
    this.target = new THREE.WebGLRenderTarget(1, 1, {
      type: THREE.HalfFloatType,                 // linear HDR colour, tone mapped once, by the water
      depthTexture: new THREE.DepthTexture(1, 1),
    });
    uniforms.uSceneColor.value = this.target.texture;
    uniforms.uSceneDepth.value = this.target.depthTexture;
  }

  // Must match the size of the drawing buffer: the water looks up by gl_FragCoord / uResolution.
  setSize(width, height) {
    this.target.setSize(width, height);
  }

  // `hide`: objects that must not appear in the capture (the water itself, the sky dome).
  render(renderer, scene, camera, hide = []) {
    const wasVisible = hide.map((o) => o.visible);
    hide.forEach((o) => (o.visible = false));

    const previousTarget = renderer.getRenderTarget();
    renderer.setRenderTarget(this.target);
    renderer.render(scene, camera);
    renderer.setRenderTarget(previousTarget);

    hide.forEach((o, i) => (o.visible = wasVisible[i]));

    // The water needs these to turn depth-buffer values back into metres.
    this.uniforms.uCameraNear.value = camera.near;
    this.uniforms.uCameraFar.value = camera.far;
  }
}