/**
 * Turns a window of pose frames into normalised, pose-derived measurements.
 * Everything is expressed in body-relative units (shoulder widths, torso
 * lengths, degrees) rather than raw pixels, so measurements survive changes in
 * player height, body proportions, camera distance and camera angle.
 */

import { measuredComponents, rubricFor, type MechanicID } from "./mechanics";
import {
  angleBetweenPoints,
  bodyScale,
  distance,
  elbowFor,
  hipCenter,
  jointPoint,
  meanConfidence,
  pathLength,
  shoulderCenter,
  shoulderFor,
  torsoLength,
  wristFor,
  type PoseFrame,
  type PoseJoint,
  type Vector,
} from "./pose";
import type { Handedness } from "./profile";
import type { MechanicMeasurement } from "./scoring";
import type { ShotType } from "./shots";

/** A detected swing: the pose frames plus the index of the contact frame. */
export interface RepWindow {
  frames: PoseFrame[];
  /** Index into `frames` of the estimated contact moment. */
  contactIndex: number;
  /** Index where the forward swing began. */
  forwardStartIndex: number;
  hand: Handedness;
  /** 0...1 confidence that this was a genuine, cleanly-measured swing. */
  detectionConfidence: number;
  /** Peak wrist speed in body-scales per second. */
  peakWristSpeed: number;
  /** Unit vector of the forward swing in frame space. */
  swingDirection: Vector;
}

export function contactFrame(window: RepWindow): PoseFrame {
  return window.frames[Math.min(window.contactIndex, window.frames.length - 1)];
}

export function windowDuration(window: RepWindow): number {
  const frames = window.frames;
  if (frames.length === 0) return 0;
  return frames[frames.length - 1].time - frames[0].time;
}

/**
 * Measure every mechanic the rubric for `shot` asks for and that we can
 * actually derive from pose today.
 */
export function measureWindow(
  window: RepWindow,
  shot: ShotType,
  hand: Handedness,
): MechanicMeasurement[] {
  return measuredComponents(rubricFor(shot))
    .map((component) => measureMechanic(component.mechanic, window, hand))
    .filter((item): item is MechanicMeasurement => item !== null);
}

export function measureMechanic(
  mechanic: MechanicID,
  window: RepWindow,
  hand: Handedness,
): MechanicMeasurement | null {
  switch (mechanic) {
    case "kneeBend":
      return kneeBend(window);
    case "contactPosition":
      return contactPosition(window, hand);
    case "armStructure":
      return armStructure(window, hand);
    case "headStability":
      return headStability(window);
    case "followThrough":
      return followThrough(window, hand);
    case "balance":
    case "torsoStability":
      return balance(window, mechanic);
    case "weightTransfer":
      return weightTransfer(window);
    case "softHands":
      return softHands(window);
    case "stanceWidth":
      return stanceWidth(window);
    case "contactHeight":
      return contactHeight(window, hand);
    default:
      return null;
  }
}

/**
 * Interior knee angle at contact, in degrees. Takes the more flexed knee,
 * which is the loaded leg in an athletic base.
 */
function kneeBend(window: RepWindow): MechanicMeasurement | null {
  const frame = contactFrame(window);
  const angles: number[] = [];
  const confidences: number[] = [];

  const legs: [PoseJoint, PoseJoint, PoseJoint][] = [
    ["leftHip", "leftKnee", "leftAnkle"],
    ["rightHip", "rightKnee", "rightAnkle"],
  ];

  for (const [hipJoint, kneeJoint, ankleJoint] of legs) {
    const hip = jointPoint(frame, hipJoint);
    const knee = jointPoint(frame, kneeJoint);
    const ankle = jointPoint(frame, ankleJoint);
    if (!hip || !knee || !ankle) continue;
    angles.push(angleBetweenPoints(hip, knee, ankle));
    const parts = [hipJoint, kneeJoint, ankleJoint]
      .map((joint) => frame.joints[joint]?.confidence)
      .filter((value): value is number => value !== undefined);
    confidences.push(
      parts.reduce((sum, value) => sum + value, 0) / Math.max(1, parts.length),
    );
  }

  if (angles.length === 0) return null;
  return {
    mechanic: "kneeBend",
    value: Math.min(...angles),
    unit: "°",
    confidence: confidences.length ? Math.max(...confidences) : 0.3,
  };
}

/** How far in front of the torso contact happened, in shoulder widths. */
function contactPosition(
  window: RepWindow,
  hand: Handedness,
): MechanicMeasurement | null {
  const frame = contactFrame(window);
  const wrist = wristFor(frame, hand);
  const center = shoulderCenter(frame);
  if (!wrist || !center) return null;
  const scale = bodyScale(frame);
  if (scale <= 0.01) return null;

  // Distance from the torso centre line to the wrist, measured along the swing
  // direction so it reads the same whether the camera is front-on or side-on.
  const dx = wrist.x - center.x;
  const dy = wrist.y - center.y;
  const direction = window.swingDirection;
  const alongSwing = Math.abs(dx * direction.dx + dy * direction.dy);
  const lateral = Math.abs(dx);
  const reach = Math.max(alongSwing, lateral) / scale;

  const wristJoint: PoseJoint = hand === "right" ? "rightWrist" : "leftWrist";
  const confidence = Math.min(
    frame.joints[wristJoint]?.confidence ?? 0,
    meanConfidence(frame),
  );
  return {
    mechanic: "contactPosition",
    value: reach,
    unit: "×shoulder",
    confidence,
  };
}

/** Elbow angle of the paddle arm at contact, in degrees. */
function armStructure(
  window: RepWindow,
  hand: Handedness,
): MechanicMeasurement | null {
  const frame = contactFrame(window);
  const shoulder = shoulderFor(frame, hand);
  const elbow = elbowFor(frame, hand);
  const wrist = wristFor(frame, hand);
  if (!shoulder || !elbow || !wrist) return null;

  const joints: PoseJoint[] =
    hand === "right"
      ? ["rightShoulder", "rightElbow", "rightWrist"]
      : ["leftShoulder", "leftElbow", "leftWrist"];
  const confidences = joints
    .map((joint) => frame.joints[joint]?.confidence)
    .filter((value): value is number => value !== undefined);

  return {
    mechanic: "armStructure",
    value: angleBetweenPoints(shoulder, elbow, wrist),
    unit: "°",
    confidence: confidences.length ? Math.min(...confidences) : 0.3,
  };
}

/** Total head travel across the swing, in shoulder widths. Lower is better. */
function headStability(window: RepWindow): MechanicMeasurement | null {
  const points = window.frames
    .map((frame) => jointPoint(frame, "nose", 0.25))
    .filter((point): point is { x: number; y: number } => point !== null);
  if (points.length < 3) return null;
  const scale = bodyScale(contactFrame(window));
  if (scale <= 0.01) return null;

  // Bounding travel rather than path length, so tiny jitter in the pose
  // estimate does not accumulate into a false "unstable head" reading.
  const xs = points.map((point) => point.x);
  const ys = points.map((point) => point.y);
  const spread = Math.hypot(
    Math.max(...xs) - Math.min(...xs),
    Math.max(...ys) - Math.min(...ys),
  );
  const confidences = window.frames
    .map((frame) => frame.joints.nose?.confidence ?? 0)
    .reduce((sum, value) => sum + value, 0);

  return {
    mechanic: "headStability",
    value: spread / scale,
    unit: "×shoulder",
    confidence: confidences / Math.max(1, window.frames.length),
  };
}

/** Wrist path length travelled after contact, in shoulder widths. */
function followThrough(
  window: RepWindow,
  hand: Handedness,
): MechanicMeasurement | null {
  if (window.contactIndex >= window.frames.length - 1) return null;
  const after = window.frames
    .slice(window.contactIndex)
    .map((frame) => wristFor(frame, hand))
    .filter((point): point is { x: number; y: number } => point !== null);
  if (after.length < 2) return null;
  const frame = contactFrame(window);
  const scale = bodyScale(frame);
  if (scale <= 0.01) return null;

  return {
    mechanic: "followThrough",
    value: pathLength(after) / scale,
    unit: "×shoulder",
    confidence: meanConfidence(frame),
  };
}

/** Hip-centre travel across the swing, in shoulder widths. Lower is steadier. */
function balance(
  window: RepWindow,
  mechanic: MechanicID,
): MechanicMeasurement | null {
  const centers = window.frames
    .map((frame) =>
      mechanic === "torsoStability" ? shoulderCenter(frame) : hipCenter(frame),
    )
    .filter((point): point is { x: number; y: number } => point !== null);
  if (centers.length < 3) return null;
  const frame = contactFrame(window);
  const scale = bodyScale(frame);
  if (scale <= 0.01) return null;

  const xs = centers.map((point) => point.x);
  const ys = centers.map((point) => point.y);
  const spread = Math.hypot(
    Math.max(...xs) - Math.min(...xs),
    Math.max(...ys) - Math.min(...ys),
  );

  return {
    mechanic,
    value: spread / scale,
    unit: "×shoulder",
    confidence: meanConfidence(frame),
  };
}

/** Forward hip travel along the swing direction through contact. */
function weightTransfer(window: RepWindow): MechanicMeasurement | null {
  const startFrame = window.frames[window.forwardStartIndex];
  const endFrame = window.frames[window.frames.length - 1];
  if (!startFrame || !endFrame) return null;
  const start = hipCenter(startFrame);
  const end = hipCenter(endFrame);
  if (!start || !end) return null;
  const frame = contactFrame(window);
  const scale = bodyScale(frame);
  if (scale <= 0.01) return null;

  const direction = window.swingDirection;
  const travel =
    ((end.x - start.x) * direction.dx + (end.y - start.y) * direction.dy) /
    scale;

  return {
    mechanic: "weightTransfer",
    value: travel,
    unit: "×shoulder",
    confidence: meanConfidence(frame),
  };
}

/** Peak wrist speed through contact, in shoulder widths per second. */
function softHands(window: RepWindow): MechanicMeasurement {
  return {
    mechanic: "softHands",
    value: window.peakWristSpeed,
    unit: "×shoulder/s",
    confidence: meanConfidence(contactFrame(window)),
  };
}

/** Ankle separation at contact, in shoulder widths. */
function stanceWidth(window: RepWindow): MechanicMeasurement | null {
  const frame = contactFrame(window);
  const left = jointPoint(frame, "leftAnkle");
  const right = jointPoint(frame, "rightAnkle");
  if (!left || !right) return null;
  const scale = bodyScale(frame);
  if (scale <= 0.01) return null;

  return {
    mechanic: "stanceWidth",
    value: distance(left, right) / scale,
    unit: "×shoulder",
    confidence: Math.min(
      frame.joints.leftAnkle?.confidence ?? 0,
      frame.joints.rightAnkle?.confidence ?? 0,
    ),
  };
}

/** Contact height relative to the hips, in torso lengths. Positive = above. */
function contactHeight(
  window: RepWindow,
  hand: Handedness,
): MechanicMeasurement | null {
  const frame = contactFrame(window);
  const wrist = wristFor(frame, hand);
  const hips = hipCenter(frame);
  if (!wrist || !hips) return null;
  const torso = torsoLength(frame);
  if (torso <= 0.01) return null;

  // Screen y grows downward, so invert to make "higher" positive.
  return {
    mechanic: "contactHeight",
    value: (hips.y - wrist.y) / torso,
    unit: "×torso",
    confidence: meanConfidence(frame),
  };
}
