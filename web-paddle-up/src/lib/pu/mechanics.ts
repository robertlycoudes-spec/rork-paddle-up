/**
 * Mechanic taxonomy, per-shot rubrics (configurable weights) and benchmark
 * ranges. Benchmarks live here, apart from screen logic, so they can later be
 * replaced with values derived from coach review or elite footage.
 */

import { groupOf, type ShotGroup, type ShotType } from "./shots";

export type MechanicID =
  | "kneeBend"
  | "contactPosition"
  | "armStructure"
  | "headStability"
  | "followThrough"
  | "torsoStability"
  | "balance"
  | "paddlePosition"
  | "paddleFaceStability"
  | "shoulderMovement"
  | "wristMovement"
  | "stanceWidth"
  | "recoveryPosition"
  | "weightTransfer"
  | "contactHeight"
  | "movementConsistency"
  | "torsoRotation"
  | "armPath"
  | "softHands"
  | "setup";

export const mechanicName: Record<MechanicID, string> = {
  kneeBend: "Knee Bend",
  contactPosition: "Contact Position",
  armStructure: "Arm Structure",
  headStability: "Head Stability",
  followThrough: "Follow-Through",
  torsoStability: "Torso Stability",
  balance: "Balance",
  paddlePosition: "Paddle Position",
  paddleFaceStability: "Paddle-Face Stability",
  shoulderMovement: "Shoulder Movement",
  wristMovement: "Wrist Movement",
  stanceWidth: "Stance Width",
  recoveryPosition: "Recovery Position",
  weightTransfer: "Weight Transfer",
  contactHeight: "Contact Height",
  movementConsistency: "Movement Consistency",
  torsoRotation: "Torso Rotation",
  armPath: "Arm Path",
  softHands: "Soft Hands",
  setup: "Setup",
};

/** Short imperative cue the player hears or reads mid-session. */
export const mechanicCue: Record<MechanicID, string> = {
  kneeBend: "STAY LOW",
  contactPosition: "CONTACT OUT FRONT",
  armStructure: "FIRM ARM SHAPE",
  headStability: "HEAD STILL",
  followThrough: "FINISH THE SWING",
  torsoStability: "QUIET TORSO",
  balance: "STAY BALANCED",
  paddlePosition: "PADDLE UP",
  paddleFaceStability: "STEADY FACE",
  shoulderMovement: "LEAD WITH SHOULDER",
  wristMovement: "QUIET WRIST",
  stanceWidth: "WIDEN BASE",
  recoveryPosition: "RESET YOUR FEET",
  weightTransfer: "MOVE THROUGH IT",
  contactHeight: "LIFT CONTACT",
  movementConsistency: "SAME EVERY REP",
  torsoRotation: "ROTATE THE CHEST",
  armPath: "CLEAN ARM PATH",
  softHands: "SOFT HANDS",
  setup: "SET UP EARLY",
};

export const allMechanics = Object.keys(mechanicName) as MechanicID[];

export interface RubricComponent {
  mechanic: MechanicID;
  /** 0...1, weights within a rubric sum to 1. */
  weight: number;
  /** False while a mechanic is defined but not yet measurable from pose. */
  isMeasured: boolean;
}

export interface ShotRubric {
  shot: ShotType;
  components: RubricComponent[];
  version: number;
}

function component(
  mechanic: MechanicID,
  weight: number,
  isMeasured: boolean,
): RubricComponent {
  return { mechanic, weight, isMeasured };
}

/**
 * Per-shot scoring rubric. Every shot has its OWN rubric — never a single
 * generic model across shot types.
 */
export function defaultRubric(shot: ShotType): ShotRubric {
  switch (shot) {
    case "forehandDink":
    case "backhandDink":
      return {
        shot,
        version: 1,
        components: [
          component("kneeBend", 0.25, true),
          component("contactPosition", 0.25, true),
          component("armStructure", 0.2, true),
          component("headStability", 0.15, true),
          component("followThrough", 0.15, true),
        ],
      };
    case "reset":
      return {
        shot,
        version: 1,
        components: [
          component("balance", 0.2, true),
          component("contactPosition", 0.2, true),
          component("kneeBend", 0.2, true),
          component("softHands", 0.15, true),
          component("headStability", 0.1, true),
          component("paddleFaceStability", 0.15, false),
        ],
      };
    case "thirdShotDrop":
      return {
        shot,
        version: 1,
        components: [
          component("kneeBend", 0.2, true),
          component("contactPosition", 0.2, true),
          component("followThrough", 0.2, true),
          component("headStability", 0.15, true),
          component("weightTransfer", 0.25, true),
        ],
      };
    case "serve":
      return {
        shot,
        version: 1,
        components: [
          component("stanceWidth", 0.15, true),
          component("kneeBend", 0.15, true),
          component("weightTransfer", 0.2, true),
          component("contactPosition", 0.2, true),
          component("followThrough", 0.15, true),
          component("balance", 0.15, true),
        ],
      };
    case "forehandDrive":
    case "backhandDrive":
      return {
        shot,
        version: 1,
        components: [
          component("kneeBend", 0.15, true),
          component("torsoRotation", 0.25, false),
          component("contactPosition", 0.2, true),
          component("weightTransfer", 0.2, true),
          component("followThrough", 0.2, true),
        ],
      };
    case "forehandVolley":
    case "backhandVolley":
    case "block":
    case "rollVolley":
      return {
        shot,
        version: 1,
        components: [
          component("paddlePosition", 0.25, false),
          component("contactPosition", 0.25, true),
          component("armStructure", 0.2, true),
          component("balance", 0.15, true),
          component("headStability", 0.15, true),
        ],
      };
    case "returnOfServe":
    case "speedUp":
    case "overhead":
    case "lob":
      return {
        shot,
        version: 1,
        components: [
          component("setup", 0.2, false),
          component("contactPosition", 0.25, true),
          component("weightTransfer", 0.2, true),
          component("followThrough", 0.2, true),
          component("balance", 0.15, true),
        ],
      };
  }
}

const overrides = new Map<ShotType, ShotRubric>();

export function rubricFor(shot: ShotType): ShotRubric {
  return overrides.get(shot) ?? defaultRubric(shot);
}

export function setRubricWeights(
  weights: Partial<Record<MechanicID, number>>,
  shot: ShotType,
): void {
  const rubric = rubricFor(shot);
  overrides.set(shot, {
    ...rubric,
    components: rubric.components.map((item) => ({
      ...item,
      weight: weights[item.mechanic] ?? item.weight,
    })),
  });
}

export function resetRubricOverrides(): void {
  overrides.clear();
}

export function measuredComponents(rubric: ShotRubric): RubricComponent[] {
  return rubric.components.filter((item) => item.isMeasured);
}

/** Weights renormalised over the components we can actually measure today. */
export function normalizedMeasuredWeights(
  rubric: ShotRubric,
): Partial<Record<MechanicID, number>> {
  const measured = measuredComponents(rubric);
  const total = measured.reduce((sum, item) => sum + item.weight, 0);
  if (total <= 0) return {};
  const result: Partial<Record<MechanicID, number>> = {};
  for (const item of measured) result[item.mechanic] = item.weight / total;
  return result;
}

/** Where a benchmark range came from — never claim clinical validation. */
export type BenchmarkSource =
  | "coachingHeuristic"
  | "eliteFootage"
  | "aggregateUsage";

export interface BenchmarkRange {
  idealLow: number;
  idealHigh: number;
  acceptableLow: number;
  acceptableHigh: number;
  unit: string;
  source: BenchmarkSource;
}

/** `ideal` scores 100; the score decays through `acceptable` and bottoms out. */
export function scoreForValue(range: BenchmarkRange, value: number): number {
  if (value >= range.idealLow && value <= range.idealHigh) return 100;
  if (value < range.idealLow) {
    const span = Math.max(0.0001, range.idealLow - range.acceptableLow);
    const t = (value - range.acceptableLow) / span;
    return Math.max(10, 45 + 55 * Math.min(1, Math.max(0, t)));
  }
  const span = Math.max(0.0001, range.acceptableHigh - range.idealHigh);
  const t = (range.acceptableHigh - value) / span;
  return Math.max(10, 45 + 55 * Math.min(1, Math.max(0, t)));
}

export const BENCHMARK_VERSION = "v1-heuristic-2026.09";

function range(
  idealLow: number,
  idealHigh: number,
  acceptableLow: number,
  acceptableHigh: number,
  unit: string,
): BenchmarkRange {
  return {
    idealLow,
    idealHigh,
    acceptableLow,
    acceptableHigh,
    unit,
    source: "coachingHeuristic",
  };
}

/**
 * Benchmark ranges, stored separately from scoring logic so they can be
 * swapped for coach-validated or data-derived values without touching code
 * that consumes them.
 */
export function benchmarkRange(
  shot: ShotType,
  mechanic: MechanicID,
): BenchmarkRange | null {
  const group: ShotGroup = groupOf(shot);

  if (group === "dink") {
    switch (mechanic) {
      case "kneeBend":
        return range(118, 148, 95, 172, "°");
      case "contactPosition":
        return range(0.85, 1.55, 0.25, 2.1, "×shoulder");
      case "armStructure":
        return range(122, 158, 85, 178, "°");
      case "headStability":
        return range(0, 0.22, -0.1, 0.75, "×shoulder");
      case "followThrough":
        return range(0.45, 1.15, 0.08, 1.9, "×shoulder");
      case "contactHeight":
        return range(-0.15, 0.35, -0.6, 0.85, "×torso");
    }
  }

  if (group === "reset") {
    switch (mechanic) {
      case "kneeBend":
        return range(110, 142, 90, 168, "°");
      case "contactPosition":
        return range(0.75, 1.45, 0.2, 2.0, "×shoulder");
      case "balance":
        return range(0, 0.18, -0.1, 0.7, "×shoulder");
      case "softHands":
        return range(0, 1.5, -0.2, 4.2, "×shoulder/s");
      case "headStability":
        return range(0, 0.24, -0.1, 0.8, "×shoulder");
    }
  }

  if (group === "thirdShotDrop") {
    switch (mechanic) {
      case "kneeBend":
        return range(120, 152, 95, 175, "°");
      case "contactPosition":
        return range(0.9, 1.7, 0.3, 2.3, "×shoulder");
      case "followThrough":
        return range(0.6, 1.5, 0.1, 2.3, "×shoulder");
      case "headStability":
        return range(0, 0.3, -0.1, 0.9, "×shoulder");
      case "weightTransfer":
        return range(0.12, 0.6, -0.15, 1.1, "×shoulder");
    }
  }

  if (group === "serve") {
    switch (mechanic) {
      case "stanceWidth":
        return range(0.95, 1.7, 0.45, 2.4, "×shoulder");
      case "kneeBend":
        return range(130, 162, 100, 178, "°");
      case "weightTransfer":
        return range(0.2, 0.8, -0.1, 1.4, "×shoulder");
      case "contactPosition":
        return range(0.7, 1.5, 0.15, 2.2, "×shoulder");
      case "followThrough":
        return range(0.8, 1.9, 0.2, 2.8, "×shoulder");
      case "balance":
        return range(0, 0.22, -0.1, 0.8, "×shoulder");
    }
  }

  // Generic fallbacks for preview-quality shots.
  switch (mechanic) {
    case "kneeBend":
      return range(120, 155, 95, 178, "°");
    case "contactPosition":
      return range(0.8, 1.6, 0.2, 2.2, "×shoulder");
    case "armStructure":
      return range(120, 160, 85, 178, "°");
    case "headStability":
      return range(0, 0.26, -0.1, 0.85, "×shoulder");
    case "followThrough":
      return range(0.5, 1.4, 0.08, 2.3, "×shoulder");
    case "balance":
      return range(0, 0.2, -0.1, 0.8, "×shoulder");
    case "weightTransfer":
      return range(0.1, 0.7, -0.2, 1.3, "×shoulder");
    case "stanceWidth":
      return range(0.9, 1.8, 0.4, 2.5, "×shoulder");
    case "softHands":
      return range(0, 1.8, -0.2, 4.5, "×shoulder/s");
    case "contactHeight":
      return range(-0.15, 0.4, -0.7, 1.0, "×torso");
    default:
      return null;
  }
}
