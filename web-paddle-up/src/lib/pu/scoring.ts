/**
 * Converts normalised measurements into 1-100 mechanic scores and a weighted
 * Paddle Up score, using the shot's own rubric and benchmark ranges.
 */

import {
  benchmarkRange,
  normalizedMeasuredWeights,
  rubricFor,
  scoreForValue,
  type MechanicID,
} from "./mechanics";
import type { MechanicScore, RepRecord, ShotRating } from "./profile";
import type { ShotType } from "./shots";

export interface MechanicMeasurement {
  mechanic: MechanicID;
  value: number;
  unit: string;
  confidence: number;
}

export interface RepAnalysis {
  shot: ShotType;
  /** 1...100. */
  score: number;
  mechanics: MechanicScore[];
  dominantIssue?: MechanicID;
  /** True when the dominant mechanic's raw value sat above the ideal band. */
  dominantValueIsHigh: boolean;
  confidence: number;
  rubricVersion: number;
}

function clamp(value: number): number {
  return Math.min(100, Math.max(1, value));
}

/**
 * Score one detected rep. Each shot uses its own rubric — never a single
 * generic model.
 */
export function scoreRep(
  measurements: MechanicMeasurement[],
  shot: ShotType,
  detectionConfidence: number,
): RepAnalysis {
  const rubric = rubricFor(shot);
  const weights = normalizedMeasuredWeights(rubric);

  const mechanicScores: MechanicScore[] = [];
  const highFlags = new Map<MechanicID, boolean>();

  for (const measurement of measurements) {
    const range = benchmarkRange(shot, measurement.mechanic);
    if (!range) continue;
    mechanicScores.push({
      mechanic: measurement.mechanic,
      score: clamp(scoreForValue(range, measurement.value)),
      rawValue: measurement.value,
      unit: measurement.unit,
      confidence: measurement.confidence,
    });
    highFlags.set(measurement.mechanic, measurement.value > range.idealHigh);
  }

  // Keep rubric order so the breakdown always reads the same way.
  const ordered = rubric.components
    .map((component) =>
      mechanicScores.find((item) => item.mechanic === component.mechanic),
    )
    .filter((item): item is MechanicScore => item !== undefined);

  let weightedTotal = 0;
  let weightUsed = 0;
  for (const mechanic of ordered) {
    const weight = weights[mechanic.mechanic];
    if (weight === undefined) continue;
    weightedTotal += mechanic.score * weight;
    weightUsed += weight;
  }

  const base = weightUsed > 0 ? weightedTotal / weightUsed : 0;
  // Low-confidence measurement pulls the score gently toward the middle
  // rather than producing a confidently wrong extreme.
  const blended =
    base * detectionConfidence +
    70 * (1 - detectionConfidence) * 0.35 +
    base * (1 - detectionConfidence) * 0.65;

  // The dominant issue is the weakest mechanic weighted by how much it
  // matters in this rubric — a small miss on a 25% mechanic outranks a
  // large miss on a 10% one.
  const candidates = ordered.filter((item) => item.score < 82);
  let dominant: MechanicScore | undefined;
  for (const candidate of candidates) {
    if (!dominant) {
      dominant = candidate;
      continue;
    }
    const candidateBurden =
      (100 - candidate.score) * (weights[candidate.mechanic] ?? 0);
    const dominantBurden =
      (100 - dominant.score) * (weights[dominant.mechanic] ?? 0);
    if (candidateBurden > dominantBurden) dominant = candidate;
  }

  return {
    shot,
    score: clamp(Math.round(blended)),
    mechanics: ordered,
    dominantIssue: dominant?.mechanic,
    dominantValueIsHigh: dominant
      ? (highFlags.get(dominant.mechanic) ?? false)
      : false,
    confidence: detectionConfidence,
    rubricVersion: rubric.version,
  };
}

/**
 * Roll per-rep scores up into a shot-group rating (1-100), weighting recent
 * reps more heavily so the rating tracks current form.
 */
export function ratingFromReps(reps: RepRecord[]): number | null {
  if (reps.length === 0) return null;
  const sorted = [...reps].sort((a, b) => a.timestamp - b.timestamp);
  let weightedSum = 0;
  let weightTotal = 0;
  sorted.forEach((rep, index) => {
    const recency = (index + 1) / sorted.length;
    const weight = 0.35 + recency * 0.65;
    weightedSum += rep.score * weight;
    weightTotal += weight;
  });
  if (weightTotal <= 0) return null;
  return Math.min(100, Math.max(1, weightedSum / weightTotal));
}

/**
 * Overall Paddle Up Rating derived from per-shot ratings. Shots with more
 * evidence count more; this is explicitly NOT a DUPR rating.
 */
export function overallRatingFrom(ratings: ShotRating[]): number | null {
  const rated = ratings.filter((rating) => rating.repCount > 0);
  if (rated.length === 0) return null;
  let weightedSum = 0;
  let weightTotal = 0;
  for (const rating of rated) {
    const evidence = Math.min(1, rating.repCount / 60);
    const weight = 0.4 + evidence * 0.6;
    weightedSum += rating.score * weight;
    weightTotal += weight;
  }
  return Math.min(100, Math.max(1, weightedSum / weightTotal));
}
