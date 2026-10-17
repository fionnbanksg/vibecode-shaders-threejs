import * as THREE from 'three';

// Shaders live in their own files; `?raw` imports them as strings.
import vertexShader from './shaders/basic.vert.glsl?raw';
import fragmentShader from './shaders/basic.frag.glsl?raw';

/**
 * Uniforms shared by every shader. Add your own here (or on `material.uniforms`).
 * main.js updates uTime and uResolution each frame / on resize.
 */
export const uniforms = {
  uTime: { value: 0 },
  uResolution: { value: new THREE.Vector2(1, 1) },
};

export const material = new THREE.ShaderMaterial({
  vertexShader,
  fragmentShader,
  uniforms,
  side: THREE.DoubleSide,
});

// Hot-swap shaders on save: no page reload, camera state preserved.
// To add another shader: import its files above and mirror this block.
if (import.meta.hot) {
  import.meta.hot.accept(
    ['./shaders/basic.vert.glsl?raw', './shaders/basic.frag.glsl?raw'],
    ([vert, frag]) => {
      if (vert) material.vertexShader = vert.default;
      if (frag) material.fragmentShader = frag.default;
      material.needsUpdate = true;
    }
  );
}
