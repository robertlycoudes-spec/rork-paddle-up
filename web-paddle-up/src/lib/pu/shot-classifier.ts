/**
 * Classifies a detected swing into a shot type from normalised pose features.
 *
 * SCOPE: this is a deterministic feature-rule classifier, not a trained model.
 * It reliably separates forehand from backhand and rejects swings whose shape
 * clearly does not match the session's shot. During a practice session the
 * player has already told us which shot they are drilling, so the classifier's
 * real job is side detection plus a plausibility check.
 */

import { contactFrame, type RepWindow } from "./mechanics-analyzer";
import {
  bodyScale,
  hipCenter,
  pathLength,
  shoulderCenter,
  shoulderFor,
  torsoLength,
  wristFor,
  type Point,
} from "./pose";
import type { Handedness } from "./profile";
import type { ShotType } from "./shots";

export interface ShotClassification {
  shot: ShotType;
  /** 0...1 confidence in the assignment. */
  confidence: number;
  /** True when the swing did not look like the shot the session expected. */
  mismatchesExpectation: boolean;
}

/** Classify within the context of the session's selected shot. */
export function classifySwing(
  window: RepWindow,
  hand: Handedness,
  expected: ShotType,
): ShotClassification {
  const side = detectSide(window, hand);
  const resolved = resolve(expected, side.isForehand);
  const plausibilityScore = plausibility(window, resolved);

  return {
    shot: resolved,
    confidence: Math.max(
      0.15,
      Math.min(1, side.confidence * 0.6 + plausibilityScore * 0.4),
    ),
    mismatchesExpectation: plausibilityScore < 0.35,
  };
}

/**
 * Which side of the body the swing happened on, relative to the paddle hand.
 * A backhand crosses the body's centre line; a forehand stays outside it.
 */
function detectSide(
  window: RepWindow,
  hand: Handedness,
): { isForehand: boolean; confidence: number } {
  const frame = contactFrame(window);
  const wrist = wristFor(frame, hand);
  const center = shoulderCenter(frame);
  const paddleShoulder = shoulderFor(frame, hand);
  if (!wrist || !center || !paddleShoulder) {
    return { isForehand: true, confidence: 0.3 };
  }

  // Positive when the wrist sits on the same side as the paddle shoulder.
  const shoulderOffset = paddleShoulder.x - center.x;
  const wristOffset = wrist.x - center.x;
  const scale = Math.max(0.02, bodyScale(frame));
  const alignment = (shoulderOffset * wristOffset) / (scale * scale);

  return {
    isForehand: alignment >= 0,
    // Confidence grows with how decisively the wrist sits on one side.
    confidence: Math.max(0.35, Math.min(1, Math.abs(alignment) / 0.35)),
  };
}

function resolve(expected: ShotType, isForehandSide: boolean): ShotType {
  switch (expected) {
    case "forehandDink":
    case "backhandDink":
      return isForehandSide ? "forehandDink" : "backhandDink";
    case "forehandDrive":
    case "backhandDrive":
      return isForehandSide ? "forehandDrive" : "backhandDrive";
    case "forehandVolley":
    case "backhandVolley":
      return isForehandSide ? "forehandVolley" : "backhandVolley";
    default:
      // Single-sided shots (serve, drop, reset, ...) keep their identity.
      return expected;
  }
}

/** How well the swing's shape matches the expected shot's signature. */
function plausibility(window: RepWindow, shot: ShotType): number {
  const frame = contactFrame(window);
  const scale = Math.max(0.02, bodyScale(frame));
  const speed = window.peakWristSpeed;
  const wristPath =
    pathLength(
      window.frames
        .map((item) => wristFor(item, window.hand))
        .filter((point): point is Point => point !== null),
    ) / scale;

  // Relative contact height: positive above the hips.
  let heightTerm = 0.6;
  const wrist = wristFor(frame, window.hand);
  const hips = hipCenter(frame);
  const torso = torsoLength(frame);
  if (wrist && hips && torso > 0.01) {
    const relative = (hips.y - wrist.y) / torso;
    heightTerm = score(relative, idealContactHeight(shot), 0.7);
  }

  const speedTerm = score(speed, idealSpeed(shot), idealSpeed(shot) * 0.9);
  const pathTerm = score(wristPath, idealPath(shot), idealPath(shot) * 0.95);

  return Math.max(
    0,
    Math.min(1, heightTerm * 0.4 + speedTerm * 0.35 + pathTerm * 0.25),
  );
}

function score(value: number, ideal: number, tolerance: number): number {
  if (tolerance <= 0) return 0.5;
  return Math.max(0, 1 - Math.abs(value - ideal) / tolerance);
}

/** Signature contact height per shot, in torso lengths above the hips. */
function idealContactHeight(shot: ShotType): number {
  switch (shot) {
    case "forehandDink":
    case "backhandDink":
    case "reset":
      return 0.05;
    case "thirdShotDrop":
      return 0.0;
    case "serve":
      return -0.15;
    case "forehandVolley":
    case "backhandVolley":
    case "block":
    case "rollVolley":
    case "speedUp":
      return 0.55;
    case "overhead":
    case "lob":
      return 1.05;
    default:
      return 0.3;
  }
}

function idealSpeed(shot: ShotType): number {
  switch (shot) {
    case "forehandDink":
    case "backhandDink":
    case "reset":
    case "block":
      return 2.0;
    case "thirdShotDrop":
    case "serve":
      return 3.2;
    case "forehandVolley":
    case "backhandVolley":
    case "rollVolley":
      return 3.6;
    case "forehandDrive":
    case "backhandDrive":
    case "speedUp":
    case "overhead":
      return 5.5;
    default:
      return 3.5;
  }
}

function idealPath(shot: ShotType): number {
  switch (shot) {
    case "forehandDink":
    case "backhandDink":
    case "reset":
    case "block":
      return 1.5;
    case "thirdShotDrop":
    case "serve":
      return 2.6;
    case "forehandVolley":
    case "backhandVolley":
    case "rollVolley":
      return 1.9;
    case "forehandDrive":
    case "backhandDrive":
    case "speedUp":
    case "overhead":
      return 3.4;
    default:
      return 2.4;
  }
}
