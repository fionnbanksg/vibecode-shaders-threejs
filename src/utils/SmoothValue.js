/**
 * Critically damped spring (Unity-style SmoothDamp).
 * Set `.target`; call `.update(dt)` each frame. Velocity is carried between
 * frames, so you get natural acceleration AND deceleration, frame-rate independent.
 *
 * smoothTime ~ time (seconds) to approximately reach the target. Bigger = floatier.
 */
export class SmoothValue {
  constructor(value = 0, smoothTime = 0.2) {
    this.value = value;
    this.target = value;
    this.velocity = 0;
    this.smoothTime = smoothTime;
  }

  update(dt) {
    const smoothTime = Math.max(0.0001, this.smoothTime);
    const omega = 2 / smoothTime;
    const x = omega * dt;
    const exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);

    const change = this.value - this.target;
    const temp = (this.velocity + omega * change) * dt;
    this.velocity = (this.velocity - omega * temp) * exp;
    this.value = this.target + (change + temp) * exp;

    return this.value;
  }

  /** Jump instantly, killing any motion. */
  snap(value) {
    this.value = this.target = value;
    this.velocity = 0;
  }
}
