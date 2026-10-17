import * as THREE from 'three';
import { SmoothValue } from './utils/SmoothValue.js';

/**
 * Orbit camera with damped motion.
 *  - Left-drag: orbit (yaw/pitch)
 *  - Scroll:    zoom (exponential, so each notch feels the same at any distance)
 */
export class CameraController {
  constructor(camera, domElement, opts = {}) {
    this.camera = camera;
    this.dom = domElement;
    this.target = new THREE.Vector3(...(opts.target ?? [0, 0, 0]));

    this.rotateSpeed = opts.rotateSpeed ?? 0.005;   // radians per pixel
    this.zoomSpeed = opts.zoomSpeed ?? 0.0015;      // log-distance per wheel unit
    this.minDistance = opts.minDistance ?? 0.5;
    this.maxDistance = opts.maxDistance ?? 50;
    this.minPitch = 0.04;
    this.maxPitch = Math.PI / 2 - 0.01;

    // Tune feel here: larger smoothTime = more glide.
    this.yaw = new SmoothValue(0, opts.rotateSmoothTime ?? 0.25);
    this.pitch = new SmoothValue(opts.pitch ?? 0, opts.rotateSmoothTime ?? 0.25);
    this.logDistance = new SmoothValue(Math.log(opts.distance ?? 4), opts.zoomSmoothTime ?? 0.3);

    this._dragging = false;
    this._lastX = 0;
    this._lastY = 0;

    this._onDown = this._onDown.bind(this);
    this._onMove = this._onMove.bind(this);
    this._onUp = this._onUp.bind(this);
    this._onWheel = this._onWheel.bind(this);

    domElement.addEventListener('pointerdown', this._onDown);
    domElement.addEventListener('pointermove', this._onMove);
    domElement.addEventListener('pointerup', this._onUp);
    domElement.addEventListener('pointercancel', this._onUp);
    domElement.addEventListener('wheel', this._onWheel, { passive: false });
  }

  _onDown(e) {
    if (e.button !== 0) return; // left button only
    this._dragging = true;
    this._lastX = e.clientX;
    this._lastY = e.clientY;
    this.dom.setPointerCapture(e.pointerId);
  }

  _onMove(e) {
    if (!this._dragging) return;
    const dx = e.clientX - this._lastX;
    const dy = e.clientY - this._lastY;
    this._lastX = e.clientX;
    this._lastY = e.clientY;

    // Move the *targets*; the springs do the easing.
    this.yaw.target -= dx * this.rotateSpeed;
    this.pitch.target = THREE.MathUtils.clamp(
      this.pitch.target + dy * this.rotateSpeed,
      this.minPitch,
      this.maxPitch
    );
  }

  _onUp(e) {
    if (!this._dragging) return;
    this._dragging = false;
    if (this.dom.hasPointerCapture(e.pointerId)) this.dom.releasePointerCapture(e.pointerId);
  }

  _onWheel(e) {
    e.preventDefault();
    // Normalise line/page scrolling (Firefox, some mice) to pixels.
    const unit = e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? 100 : 1;
    const next = this.logDistance.target + e.deltaY * unit * this.zoomSpeed;
    this.logDistance.target = THREE.MathUtils.clamp(
      next,
      Math.log(this.minDistance),
      Math.log(this.maxDistance)
    );
  }

  update(dt) {
    const yaw = this.yaw.update(dt);
    const pitch = this.pitch.update(dt);
    const dist = Math.exp(this.logDistance.update(dt));

    const cp = Math.cos(pitch);
    this.camera.position.set(
      this.target.x + dist * Math.sin(yaw) * cp,
      this.target.y + dist * Math.sin(pitch),
      this.target.z + dist * Math.cos(yaw) * cp
    );
    this.camera.lookAt(this.target);
  }

  dispose() {
    this.dom.removeEventListener('pointerdown', this._onDown);
    this.dom.removeEventListener('pointermove', this._onMove);
    this.dom.removeEventListener('pointerup', this._onUp);
    this.dom.removeEventListener('pointercancel', this._onUp);
    this.dom.removeEventListener('wheel', this._onWheel);
  }
}
