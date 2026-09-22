/**
 * Framework-agnostic pose representation. Coordinates are normalised to the
 * frame (0...1) with a TOP-LEFT origin, so y grows downward like screen space.
 */

import type { Handedness } from "./profile";

export type PoseJoint =
  | "nose"
  | "neck"
  | "root"
  | "leftShoulder"
  | "rightShoulder"
  | "leftElbow"
  | "rightElbow"
  | "leftWrist"
  | "rightWrist"
  | "leftHip"
  | "rightHip"
  | "leftKnee"
  | "rightKnee"
  | "leftAnkle"
  | "rightAnkle";

export interface PosePoint {
  x: number;
  y: number;
  confidence: number;
}

export interface Point {
  x: number;
  y: number;
}

export interface Vector {
  dx: number;
  dy: number;
}

/** One detected body pose at a moment in time. */
export interface PoseFrame {
  /** Seconds since session start. */
  time: number;
  joints: Partial<Record<PoseJoint, PosePoint>>;
}

export function jointPoint(
  frame: PoseFrame,
  joint: PoseJoint,
  minConfidence = 0.2,
): Point | null {
  const point = frame.joints[joint];
  if (!point || point.confidence < minConfidence) return null;
  return { x: point.x, y: point.y };
}

/** Mean confidence across the joints that matter for swing mechanics. */
export function meanConfidence(frame: PoseFrame): number {
  const keys: PoseJoint[] = [
    "leftShoulder",
    "rightShoulder",
    "leftHip",
    "rightHip",
    "leftKnee",
    "rightKnee",
    "leftWrist",
    "rightWrist",
    "nose",
  ];
  const values = keys
    .map((key) => frame.joints[key]?.confidence)
    .filter((value): value is number => value !== undefined);
  if (values.length === 0) return 0;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

/**
 * Distance between shoulders — the app's normalisation unit. Using a body
 * dimension instead of raw pixels keeps scores comparable across player
 * heights, camera distances and screen sizes.
 */
export function shoulderWidth(frame: PoseFrame): number {
  const left = jointPoint(frame, "leftShoulder");
  const right = jointPoint(frame, "rightShoulder");
  if (!left || !right) return 0;
  return Math.hypot(left.x - right.x, left.y - right.y);
}

export function shoulderCenter(frame: PoseFrame): Point | null {
  const left = jointPoint(frame, "leftShoulder");
  const right = jointPoint(frame, "rightShoulder");
  if (!left || !right) return null;
  return { x: (left.x + right.x) / 2, y: (left.y + right.y) / 2 };
}

export function hipCenter(frame: PoseFrame): Point | null {
  const left = jointPoint(frame, "leftHip");
  const right = jointPoint(frame, "rightHip");
  if (!left || !right) return null;
  return { x: (left.x + right.x) / 2, y: (left.y + right.y) / 2 };
}

/** Shoulder-centre to hip-centre distance; the vertical normalisation unit. */
export function torsoLength(frame: PoseFrame): number {
  const shoulders = shoulderCenter(frame);
  const hips = hipCenter(frame);
  if (!shoulders || !hips) return 0;
  return Math.hypot(shoulders.x - hips.x, shoulders.y - hips.y);
}

/**
 * Normalisation scale that tolerates a player turned side-on to the camera
 * (shoulder width collapses, torso length does not).
 */
export function bodyScale(frame: PoseFrame): number {
  const shoulder = shoulderWidth(frame);
  const torso = torsoLength(frame);
  if (shoulder > 0.02 && torso > 0.02) return Math.max(shoulder, torso * 0.62);
  if (torso > 0.02) return torso * 0.62;
  return Math.max(shoulder, 0.02);
}

export function wristFor(frame: PoseFrame, hand: Handedness): Point | null {
  return jointPoint(frame, hand === "right" ? "rightWrist" : "leftWrist");
}

export function elbowFor(frame: PoseFrame, hand: Handedness): Point | null {
  return jointPoint(frame, hand === "right" ? "rightElbow" : "leftElbow");
}

export function shoulderFor(frame: PoseFrame, hand: Handedness): Point | null {
  return jointPoint(frame, hand === "right" ? "rightShoulder" : "leftShoulder");
}

/** Fraction of the body that is inside the frame, used by camera setup. */
export function framingCoverage(frame: PoseFrame): number {
  const points = Object.values(frame.joints).filter(
    (point): point is PosePoint => !!point && point.confidence > 0.2,
  );
  if (points.length < 6) return 0;
  const inside = points.filter(
    (point) =>
      point.x > 0.02 && point.x < 0.98 && point.y > 0.02 && point.y < 0.98,
  );
  return inside.length / points.length;
}

/** Interior angle ABC in degrees. */
export function angleBetweenPoints(a: Point, b: Point, c: Point): number {
  const v1 = { dx: a.x - b.x, dy: a.y - b.y };
  const v2 = { dx: c.x - b.x, dy: c.y - b.y };
  const dot = v1.dx * v2.dx + v1.dy * v2.dy;
  const magnitude = Math.hypot(v1.dx, v1.dy) * Math.hypot(v2.dx, v2.dy);
  if (magnitude <= 0) return 180;
  const cosine = Math.max(-1, Math.min(1, dot / magnitude));
  return (Math.acos(cosine) * 180) / Math.PI;
}

export function distance(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

/** Path length of a polyline. */
export function pathLength(points: Point[]): number {
  if (points.length < 2) return 0;
  let total = 0;
  for (let index = 1; index < points.length; index += 1) {
    total += distance(points[index - 1], points[index]);
  }
  return total;
}

/** Bones drawn by the skeleton overlay. */
export const poseBones: [PoseJoint, PoseJoint][] = [
  ["leftShoulder", "rightShoulder"],
  ["leftShoulder", "leftElbow"],
  ["leftElbow", "leftWrist"],
  ["rightShoulder", "rightElbow"],
  ["rightElbow", "rightWrist"],
  ["leftShoulder", "leftHip"],
  ["rightShoulder", "rightHip"],
  ["leftHip", "rightHip"],
  ["leftHip", "leftKnee"],
  ["leftKnee", "leftAnkle"],
  ["rightHip", "rightKnee"],
  ["rightKnee", "rightAnkle"],
];
