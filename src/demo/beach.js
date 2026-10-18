import * as THREE from 'three';

// DEMO ONLY. Test scenery for the ocean shaders. Nothing in the ocean code imports this,
// so delete the file (and its two lines in main.js) when you move to your own game scene.
//
// heightAt(x, z) returns the terrain height in metres; 0 is the water's rest level.
export function demoHeight(x, z) {
  const t = THREE.MathUtils.smoothstep(x, -100, 60);          // 0 = deep, 1 = beach
  const base = THREE.MathUtils.lerp(-14, 3, t);               // shoreline lands near x = 17
  const dunes = Math.sin(x * 0.11 + z * 0.07) * 0.25 + Math.sin(x * 0.31 - z * 0.23) * 0.1;
  return base + dunes * t;
}

export function createDemoTerrain({ size = 400, segments = 400, heightAt = demoHeight } = {}) {
  const geometry = new THREE.PlaneGeometry(size, size, segments, segments);
  geometry.rotateX(-Math.PI / 2);

  const pos = geometry.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const dry = new THREE.Color(0.55, 0.43, 0.27);   // linear values
  const wet = new THREE.Color(0.22, 0.17, 0.10);
  const c = new THREE.Color();

  for (let i = 0; i < pos.count; i++) {
    const h = heightAt(pos.getX(i), pos.getZ(i));
    pos.setY(i, h);
    c.copy(wet).lerp(dry, THREE.MathUtils.smoothstep(h, -0.5, 1.5));
    colors.set([c.r, c.g, c.b], i * 3);
  }
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geometry.computeVertexNormals();

  return new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ vertexColors: true }));
}