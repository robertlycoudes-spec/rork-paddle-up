/**
 * Motion state machine that turns a continuous stream of pose frames into
 * discrete swing reps, with explicit rejection of non-swing motion.
 */

import {
  bodyScale,
  hipCenter,
  jointPoint,
  meanConfidence,
  pathLength,
  wristFor,
  type PoseFrame,
  type Point,
  type Vector,
} from "./pose";
import type { Handedness } from "./profile";
import type { RepWindow } from "./mechanics-analyzer";

export type RepState =
  | "idle"
  | "ready"
  | "backswing"
  | "forwardSwing"
  | "contactWindow"
  | "followThrough"
  | "cooldown";

export const repStateLabel: Record<RepState, string> = {
  idle: "IDLE",
  ready: "READY",
  backswing: "BACKSWING",
  forwardSwing: "FORWARD_SWING",
  contactWindow: "CONTACT_WINDOW",
  followThrough: "FOLLOW_THROUGH",
  cooldown: "COOLDOWN",
};

/**
 * Why a candidate swing was thrown away. Exposed in developer mode and used
 * to measure the false-positive rate.
 */
export type RepRejection =
  | "tooShort"
  | "tooLong"
  | "tooSlow"
  | "tooSmall"
  | "walking"
  | "lowConfidence"
  | "wristTooLow";

export interface RepDetectorTuning {
  /** Wrist speed (body-scales/sec) that starts a backswing. */
  motionStartSpeed: number;
  /** Wrist speed that must be exceeded during the forward swing. */
  forwardSpeed: number;
  /** Speed below which the swing is considered finished. */
  restSpeed: number;
  /** Minimum peak speed for a candidate to count as a swing. */
  minimumPeakSpeed: number;
  /** Minimum wrist path length in body scales. */
  minimumPathLength: number;
  minimumDuration: number;
  maximumDuration: number;
  /** Refractory period after a rep before another can start. */
  cooldown: number;
  /** Max hip travel allowed during a rep (filters walking). */
  maximumHipTravel: number;
  minimumPoseConfidence: number;
  /** Direction reversal (degrees) required between backswing and forward. */
  reversalAngle: number;
}

export const defaultTuning: RepDetectorTuning = {
  motionStartSpeed: 0.55,
  forwardSpeed: 1.0,
  restSpeed: 0.35,
  minimumPeakSpeed: 1.2,
  minimumPathLength: 0.45,
  minimumDuration: 0.22,
  maximumDuration: 2.6,
  cooldown: 0.35,
  maximumHipTravel: 1.15,
  minimumPoseConfidence: 0.32,
  reversalAngle: 95,
};

export type RepDetectorEvent =
  | { kind: "none" }
  | { kind: "stateChanged"; state: RepState }
  | { kind: "repCompleted"; window: RepWindow }
  | { kind: "repRejected"; reason: RepRejection };

const NONE: RepDetectorEvent = { kind: "none" };

function angleBetweenVectors(a: Vector, b: Vector): number {
  const magA = Math.hypot(a.dx, a.dy);
  const magB = Math.hypot(b.dx, b.dy);
  if (magA <= 0.0001 || magB <= 0.0001) return 0;
  const cosine = Math.max(
    -1,
    Math.min(1, (a.dx * b.dx + a.dy * b.dy) / (magA * magB)),
  );
  return (Math.acos(cosine) * 180) / Math.PI;
}

function normalize(vector: Vector): Vector {
  const magnitude = Math.hypot(vector.dx, vector.dy);
  if (magnitude <= 0.0001) return { dx: 1, dy: 0 };
  return { dx: vector.dx / magnitude, dy: vector.dy / magnitude };
}

/** Stateful swing detector, driven one pose frame at a time. */
export class RepDetector {
  state: RepState = "idle";
  tuning: RepDetectorTuning;
  lastWristSpeed = 0;
  lastConfidence = 0;

  private readonly hand: Handedness;
  private buffer: PoseFrame[] = [];
  private speeds: number[] = [];
  private candidateStartIndex = 0;
  private forwardStartIndex = 0;
  private peakSpeed = 0;
  private peakSpeedIndex = 0;
  private backswingVelocity: Vector = { dx: 0, dy: 0 };
  private forwardVelocity: Vector = { dx: 0, dy: 0 };
  private cooldownUntil = 0;
  private stillFrames = 0;
  private readonly maxBuffer = 180;

  constructor(hand: Handedness, tuning: RepDetectorTuning = defaultTuning) {
    this.hand = hand;
    this.tuning = tuning;
  }

  reset(): void {
    this.state = "idle";
    this.buffer = [];
    this.speeds = [];
    this.peakSpeed = 0;
    this.stillFrames = 0;
  }

  updateTuning(tuning: RepDetectorTuning): void {
    this.tuning = tuning;
  }

  /** Feed one pose frame. Returns what happened, if anything. */
  ingest(frame: PoseFrame): RepDetectorEvent {
    this.buffer.push(frame);
    if (this.buffer.length > this.maxBuffer) {
      const drop = this.buffer.length - this.maxBuffer;
      this.buffer.splice(0, drop);
      this.speeds.splice(0, Math.min(drop, this.speeds.length));
      this.candidateStartIndex = Math.max(0, this.candidateStartIndex - drop);
      this.forwardStartIndex = Math.max(0, this.forwardStartIndex - drop);
      this.peakSpeedIndex = Math.max(0, this.peakSpeedIndex - drop);
    }

    const confidence = meanConfidence(frame);
    this.lastConfidence = confidence;

    if (this.buffer.length < 2) {
      this.speeds.push(0);
      return NONE;
    }

    const previous = this.buffer[this.buffer.length - 2];
    const dt = Math.max(0.008, frame.time - previous.time);
    const scale = Math.max(0.02, bodyScale(frame));

    const wrist = wristFor(frame, this.hand);
    const previousWrist = wristFor(previous, this.hand);
    if (!wrist || !previousWrist) {
      this.speeds.push(0);
      if (confidence < this.tuning.minimumPoseConfidence) {
        return this.transition("idle");
      }
      return NONE;
    }

    const velocity: Vector = {
      dx: (wrist.x - previousWrist.x) / dt / scale,
      dy: (wrist.y - previousWrist.y) / dt / scale,
    };
    const speed = Math.hypot(velocity.dx, velocity.dy);
    this.speeds.push(speed);
    this.lastWristSpeed = speed;

    if (frame.time < this.cooldownUntil) {
      return this.state === "cooldown" ? NONE : this.transition("cooldown");
    }

    if (confidence < this.tuning.minimumPoseConfidence) {
      if (
        this.state === "backswing" ||
        this.state === "forwardSwing" ||
        this.state === "contactWindow"
      ) {
        return this.finish("lowConfidence");
      }
      return this.state === "idle" ? NONE : this.transition("idle");
    }

    const elapsedSinceStart = () =>
      this.buffer[this.buffer.length - 1].time -
      this.buffer[this.candidateStartIndex].time;

    switch (this.state) {
      case "idle":
      case "cooldown": {
        this.stillFrames = speed < this.tuning.restSpeed ? this.stillFrames + 1 : 0;
        if (this.stillFrames >= 3) return this.transition("ready");
        return NONE;
      }

      case "ready": {
        if (speed > this.tuning.motionStartSpeed) {
          this.candidateStartIndex = Math.max(0, this.buffer.length - 3);
          this.peakSpeed = speed;
          this.peakSpeedIndex = this.buffer.length - 1;
          this.backswingVelocity = velocity;
          return this.transition("backswing");
        }
        return NONE;
      }

      case "backswing": {
        this.backswingVelocity = {
          dx: this.backswingVelocity.dx * 0.7 + velocity.dx * 0.3,
          dy: this.backswingVelocity.dy * 0.7 + velocity.dy * 0.3,
        };
        if (speed > this.peakSpeed) {
          this.peakSpeed = speed;
          this.peakSpeedIndex = this.buffer.length - 1;
        }

        // A forward swing begins when the wrist reverses direction and accelerates.
        const reversal = angleBetweenVectors(this.backswingVelocity, velocity);
        if (reversal > this.tuning.reversalAngle && speed > this.tuning.forwardSpeed) {
          this.forwardStartIndex = this.buffer.length - 1;
          this.forwardVelocity = velocity;
          this.peakSpeed = speed;
          this.peakSpeedIndex = this.buffer.length - 1;
          return this.transition("forwardSwing");
        }
        // A long slow drift without a reversal is not a swing.
        if (elapsedSinceStart() > this.tuning.maximumDuration) {
          return this.finish("tooLong");
        }
        if (speed < this.tuning.restSpeed) {
          this.stillFrames += 1;
          if (this.stillFrames > 6) return this.finish("tooSlow");
        } else {
          this.stillFrames = 0;
        }
        return NONE;
      }

      case "forwardSwing": {
        this.forwardVelocity = {
          dx: this.forwardVelocity.dx * 0.6 + velocity.dx * 0.4,
          dy: this.forwardVelocity.dy * 0.6 + velocity.dy * 0.4,
        };
        if (speed > this.peakSpeed) {
          this.peakSpeed = speed;
          this.peakSpeedIndex = this.buffer.length - 1;
        }
        // Contact is the moment of peak wrist speed; we recognise it once
        // speed has decayed meaningfully from that peak.
        if (speed < this.peakSpeed * 0.72) return this.transition("contactWindow");
        if (elapsedSinceStart() > this.tuning.maximumDuration) {
          return this.finish("tooLong");
        }
        return NONE;
      }

      case "contactWindow": {
        if (speed < this.tuning.restSpeed) return this.transition("followThrough");
        if (elapsedSinceStart() > this.tuning.maximumDuration) {
          return this.finish("tooLong");
        }
        return NONE;
      }

      case "followThrough": {
        this.stillFrames += 1;
        if (this.stillFrames >= 2) {
          return this.completeRep(this.buffer.length - 1);
        }
        return NONE;
      }
    }
  }

  private transition(newState: RepState): RepDetectorEvent {
    if (newState === this.state) return NONE;
    this.state = newState;
    if (newState === "ready" || newState === "idle" || newState === "followThrough") {
      this.stillFrames = 0;
    }
    return { kind: "stateChanged", state: newState };
  }

  private finish(reason: RepRejection): RepDetectorEvent {
    this.state = "ready";
    this.stillFrames = 0;
    this.peakSpeed = 0;
    return { kind: "repRejected", reason };
  }

  private completeRep(endIndex: number): RepDetectorEvent {
    const start = Math.max(0, this.candidateStartIndex);
    if (endIndex <= start) return this.finish("tooShort");
    const frames = this.buffer.slice(start, endIndex + 1);
    if (frames.length < 5) return this.finish("tooShort");

    const duration = frames[frames.length - 1].time - frames[0].time;
    if (duration < this.tuning.minimumDuration) return this.finish("tooShort");
    if (duration > this.tuning.maximumDuration) return this.finish("tooLong");
    if (this.peakSpeed < this.tuning.minimumPeakSpeed) return this.finish("tooSlow");

    const wristPoints = frames
      .map((frame) => wristFor(frame, this.hand))
      .filter((point): point is Point => point !== null);
    const scale = Math.max(0.02, bodyScale(frames[Math.floor(frames.length / 2)]));
    const wristPathLength = pathLength(wristPoints) / scale;
    if (wristPathLength < this.tuning.minimumPathLength) {
      return this.finish("tooSmall");
    }

    // Walking / repositioning filter: the hips should stay roughly planted.
    const hips = frames
      .map((frame) => hipCenter(frame))
      .filter((point): point is Point => point !== null);
    if (hips.length >= 2) {
      const xs = hips.map((point) => point.x);
      const ys = hips.map((point) => point.y);
      const travel =
        Math.hypot(
          Math.max(...xs) - Math.min(...xs),
          Math.max(...ys) - Math.min(...ys),
        ) / scale;
      if (travel > this.tuning.maximumHipTravel) return this.finish("walking");
    }

    const contactIndex = Math.max(
      0,
      Math.min(frames.length - 1, this.peakSpeedIndex - start),
    );
    const contact = frames[contactIndex];

    // Bending to pick up a ball looks like a swing but happens near the floor.
    const contactWrist = wristFor(contact, this.hand);
    const knees = [
      jointPoint(contact, "leftKnee"),
      jointPoint(contact, "rightKnee"),
    ].filter((point): point is Point => point !== null);
    if (contactWrist && knees.length > 0) {
      const kneeLine =
        knees.reduce((sum, point) => sum + point.y, 0) / knees.length;
      if (contactWrist.y > kneeLine + 0.1) return this.finish("wristTooLow");
    }

    const confidence =
      frames.reduce((sum, frame) => sum + meanConfidence(frame), 0) /
      frames.length;
    if (confidence < this.tuning.minimumPoseConfidence) {
      return this.finish("lowConfidence");
    }

    const window: RepWindow = {
      frames,
      contactIndex,
      forwardStartIndex: Math.max(
        0,
        Math.min(frames.length - 1, this.forwardStartIndex - start),
      ),
      hand: this.hand,
      detectionConfidence: this.confidenceScore(
        confidence,
        this.peakSpeed,
        wristPathLength,
        duration,
      ),
      peakWristSpeed: this.peakSpeed,
      swingDirection: normalize(this.forwardVelocity),
    };

    this.cooldownUntil =
      (frames[frames.length - 1]?.time ?? 0) + this.tuning.cooldown;
    this.state = "cooldown";
    this.stillFrames = 0;
    this.peakSpeed = 0;
    return { kind: "repCompleted", window };
  }

  private confidenceScore(
    confidence: number,
    peakSpeed: number,
    wristPathLength: number,
    duration: number,
  ): number {
    const poseTerm = Math.min(1, confidence / 0.75);
    const speedTerm = Math.min(1, peakSpeed / (this.tuning.minimumPeakSpeed * 1.8));
    const pathTerm = Math.min(
      1,
      wristPathLength / (this.tuning.minimumPathLength * 2.2),
    );
    const durationTerm = duration > 0.3 && duration < 1.9 ? 1.0 : 0.72;
    return Math.max(
      0.1,
      Math.min(
        1,
        poseTerm * 0.45 + speedTerm * 0.25 + pathTerm * 0.2 + durationTerm * 0.1,
      ),
    );
  }
}
