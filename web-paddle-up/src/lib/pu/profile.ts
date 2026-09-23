/**
 * Persisted domain entities: profile, sessions, reps, mechanic history.
 * Timestamps are epoch milliseconds so everything serialises to JSON cleanly.
 */

import { rubricFor, type MechanicID } from "./mechanics";
import type { PoseFrame } from "./pose";
import { BENCHMARK_VERSION } from "./mechanics";
import { groupOf, type ShotGroup, type ShotType } from "./shots";

export interface Option<T extends string> {
  id: T;
  displayName: string;
  detail?: string;
  icon?: string;
}

/**
 * The player's level as a DUPR band. Players who know their DUPR pick the band
 * it falls in; players who don't pick by the plain-language label. Only the
 * band is stored — never a precise rating.
 */
export type DuprRange =
  | "beginner"
  | "lowerIntermediate"
  | "intermediate"
  | "upperIntermediate"
  | "advanced"
  | "advancedPlus"
  | "pro";

export interface DuprRangeOption {
  id: DuprRange;
  rangeLabel: string;
  displayName: string;
  detail: string;
}

export const duprRanges: DuprRangeOption[] = [
  {
    id: "beginner",
    rangeLabel: "2.0–2.49",
    displayName: "Beginner",
    detail: "Learning the rules, the serve and keeping a rally going",
  },
  {
    id: "lowerIntermediate",
    rangeLabel: "2.5–2.99",
    displayName: "Lower Intermediate",
    detail: "Rallying comfortably, starting to play at the kitchen",
  },
  {
    id: "intermediate",
    rangeLabel: "3.0–3.49",
    displayName: "Intermediate",
    detail: "Dinking with control, working on the third shot",
  },
  {
    id: "upperIntermediate",
    rangeLabel: "3.5–3.99",
    displayName: "Upper Intermediate",
    detail: "Consistent drops and resets, playing with intent",
  },
  {
    id: "advanced",
    rangeLabel: "4.0–4.49",
    displayName: "Advanced",
    detail: "Strong hands battles, attacking the right balls",
  },
  {
    id: "advancedPlus",
    rangeLabel: "4.5–4.99",
    displayName: "Advanced+",
    detail: "Tournament-level consistency under pressure",
  },
  {
    id: "pro",
    rangeLabel: "5.0+",
    displayName: "Pro",
    detail: "Competing at the top of the sport",
  },
];

export function duprRangeOption(range: DuprRange): DuprRangeOption {
  return duprRanges.find((option) => option.id === range) ?? duprRanges[1];
}

/** "3.0–3.49 · Intermediate". */
export function duprFullLabel(range: DuprRange): string {
  const option = duprRangeOption(range);
  return `${option.rangeLabel} · ${option.displayName}`;
}

/** Ordinal position, for "at or above" comparisons. */
export function duprOrder(range: DuprRange): number {
  return duprRanges.findIndex((option) => option.id === range);
}

/**
 * Maps the retired five-step skill level onto the nearest DUPR band so data
 * saved before schema v2 keeps a sensible level.
 */
export function migrateLegacySkillLevel(raw: unknown): DuprRange | undefined {
  switch (raw) {
    case "justStarting":
    case "beginner":
      return "beginner";
    case "intermediate":
      return "intermediate";
    case "advanced":
      return "upperIntermediate";
    case "competitive":
      return "advanced";
    default:
      return undefined;
  }
}

export type PlayerStyle =
  | "aggressive"
  | "defensive"
  | "consistent"
  | "athletic"
  | "strategic"
  | "figuringOut";

export const playerStyles: Option<PlayerStyle>[] = [
  { id: "aggressive", displayName: "Aggressive", icon: "Zap" },
  { id: "defensive", displayName: "Defensive", icon: "Shield" },
  { id: "consistent", displayName: "Consistent", icon: "Target" },
  { id: "athletic", displayName: "Fast / Athletic", icon: "Rabbit" },
  { id: "strategic", displayName: "Strategic", icon: "Brain" },
  {
    id: "figuringOut",
    displayName: "Still figuring out my style",
    icon: "CircleHelp",
  },
];

export type SuccessMetric =
  | "fewerErrors"
  | "winMoreGames"
  | "consistency"
  | "beatBetterPlayers"
  | "higherDUPR"
  | "confidence"
  | "winTournaments";

export const successMetrics: Option<SuccessMetric>[] = [
  { id: "fewerErrors", displayName: "Fewer unforced errors" },
  { id: "winMoreGames", displayName: "Winning more games" },
  { id: "consistency", displayName: "Better consistency" },
  { id: "beatBetterPlayers", displayName: "Beating better players" },
  { id: "higherDUPR", displayName: "Higher DUPR" },
  { id: "confidence", displayName: "Better confidence" },
  { id: "winTournaments", displayName: "Winning tournaments" },
];

export type TrainingGoal =
  | "consistency"
  | "serve"
  | "returnOfServe"
  | "dinking"
  | "thirdShotDrops"
  | "drives"
  | "volleys"
  | "speedReaction"
  | "strategyIQ"
  | "competitive";

export const trainingGoals: Option<TrainingGoal>[] = [
  { id: "consistency", displayName: "Consistency", icon: "Target" },
  { id: "serve", displayName: "Serve", icon: "Hand" },
  { id: "returnOfServe", displayName: "Return", icon: "Undo2" },
  { id: "dinking", displayName: "Dinking", icon: "Grid2x2" },
  { id: "thirdShotDrops", displayName: "Third-shot drops", icon: "Crosshair" },
  { id: "drives", displayName: "Drives", icon: "Zap" },
  { id: "volleys", displayName: "Volleys", icon: "LayoutGrid" },
  { id: "speedReaction", displayName: "Speed & reaction", icon: "Rabbit" },
  { id: "strategyIQ", displayName: "Strategy / IQ", icon: "Brain" },
  { id: "competitive", displayName: "Become more competitive", icon: "Trophy" },
];

export const trainingGoalName: Record<TrainingGoal, string> = {
  consistency: "Consistency",
  serve: "Serve",
  returnOfServe: "Return",
  dinking: "Dinking",
  thirdShotDrops: "Third-shot drops",
  drives: "Drives",
  volleys: "Volleys",
  speedReaction: "Speed & reaction",
  strategyIQ: "Strategy / IQ",
  competitive: "Become more competitive",
};

export type BiggestStruggle =
  | "unforcedErrors"
  | "serveNeedsWork"
  | "consistency"
  | "kitchenPoints"
  | "thirdShot"
  | "betterPlayers"
  | "whatToPractice"
  | "fitness";

export const biggestStruggles: Option<BiggestStruggle>[] = [
  { id: "unforcedErrors", displayName: "I make too many unforced errors" },
  { id: "serveNeedsWork", displayName: "My serve needs work" },
  { id: "consistency", displayName: "I struggle with consistency" },
  { id: "kitchenPoints", displayName: "I lose points at the kitchen" },
  { id: "thirdShot", displayName: "My third shot needs improvement" },
  { id: "betterPlayers", displayName: "I struggle against better players" },
  { id: "whatToPractice", displayName: "I don't know what to practice" },
  { id: "fitness", displayName: "I get tired during games" },
];

export type WeeklyTrainingTime = "light" | "moderate" | "serious" | "elite";

export const weeklyTrainingTimes: Option<WeeklyTrainingTime>[] = [
  { id: "light", displayName: "1–2 hours" },
  { id: "moderate", displayName: "3–4 hours" },
  { id: "serious", displayName: "5–7 hours" },
  { id: "elite", displayName: "8+ hours" },
];

export const weeklyMinutesFor: Record<WeeklyTrainingTime, number> = {
  light: 90,
  moderate: 150,
  serious: 240,
  elite: 330,
};

export const trainingTimeRepScale: Record<WeeklyTrainingTime, number> = {
  light: 0.85,
  moderate: 1.0,
  serious: 1.35,
  elite: 1.7,
};

export const practiceDaysPerWeek: Record<WeeklyTrainingTime, number> = {
  light: 2,
  moderate: 3,
  serious: 4,
  elite: 5,
};

export type PlayFrequency = "rarely" | "weekly" | "fewTimesWeek" | "daily";

export const playFrequencies: Option<PlayFrequency>[] = [
  { id: "rarely", displayName: "Less than once a week" },
  { id: "weekly", displayName: "1–2 times a week" },
  { id: "fewTimesWeek", displayName: "3–4 times a week" },
  { id: "daily", displayName: "5+ times a week" },
];

export type Handedness = "right" | "left";

export interface PlayerProfile {
  displayName: string;
  email: string;
  /** The selected DUPR band. Undefined until the player picks one. */
  duprRange?: DuprRange;
  handedness: Handedness;
  playerTypes: PlayerStyle[];
  goals: TrainingGoal[];
  struggles: BiggestStruggle[];
  trainingTime: WeeklyTrainingTime;
  successMetric?: SuccessMetric;
  frequency: PlayFrequency;
  heightCentimetres: number;
  hasCompletedOnboarding: boolean;
  hasCompletedBaselineAssessment: boolean;
  createdAt: number;
}

export function emptyProfile(): PlayerProfile {
  return {
    displayName: "",
    email: "",
    handedness: "right",
    playerTypes: [],
    goals: [],
    struggles: [],
    trainingTime: "moderate",
    frequency: "weekly",
    heightCentimetres: 178,
    hasCompletedOnboarding: false,
    hasCompletedBaselineAssessment: false,
    createdAt: Date.now(),
  };
}

export function profileInitials(profile: PlayerProfile): string {
  const parts = profile.displayName.split(" ").filter(Boolean).slice(0, 2);
  const letters = parts.map((part) => part[0]).join("");
  return letters.length === 0 ? "PU" : letters.toUpperCase();
}

/** One measured mechanic inside a rep. */
export interface MechanicScore {
  mechanic: MechanicID;
  /** 0...100. */
  score: number;
  /** Raw pose-derived measurement in the benchmark's unit. */
  rawValue: number;
  unit: string;
  /** 0...1 measurement confidence. */
  confidence: number;
}

export interface RepRecord {
  id: string;
  sessionID: string;
  index: number;
  timestamp: number;
  shot: ShotType;
  /** Overall 0...100 Paddle Up score for the rep. */
  score: number;
  mechanics: MechanicScore[];
  dominantIssue?: MechanicID;
  issueID?: string;
  correction: string;
  nextRepCue: string;
  recommendedDrillID?: string;
  /** Detector confidence that this was a real, well-measured rep. */
  confidence: number;
  isDeleted: boolean;
  wasReclassified: boolean;
  /** Pose frames spanning the rep, used for replay overlay. */
  poseFrames: PoseFrame[];
  rubricVersion: number;
  benchmarkVersion: string;

  // Ball & paddle data — reserved, not yet measured. Paddle Up only measures
  // the body today; these stay null and nothing estimates or fills them.
  /** Ball speed off the paddle, in mph. */
  ballSpeedMPH: number | null;
  /** Ball spin, in revolutions per minute. */
  spinRPM: number | null;
  /** Paddle face angle at contact, in degrees from vertical. */
  paddleFaceAngleDegrees: number | null;
  /** How close contact was to the ideal moment, in ms (lower is better). */
  contactTimingPrecisionMS: number | null;

  /**
   * True when the player had opted in to share anonymized data when this rep
   * was recorded. Only flags the record — nothing is sent anywhere.
   */
  sharedForResearch: boolean;
}

export function mechanicOf(
  rep: RepRecord,
  id: MechanicID,
): MechanicScore | undefined {
  return rep.mechanics.find((item) => item.mechanic === id);
}

export type SessionMode = "freePractice" | "drill" | "assessment";

export const sessionModeName: Record<SessionMode, string> = {
  freePractice: "Practice",
  drill: "Drill",
  assessment: "Assessment",
};

export interface SessionRecord {
  id: string;
  startedAt: number;
  endedAt?: number;
  shot: ShotType;
  mode: SessionMode;
  drillID?: string;
  reps: RepRecord[];
  focusCue?: string;
  /**
   * True when the player had opted in to share anonymized data when this
   * session was recorded. Only flags the record — nothing is sent anywhere.
   */
  sharedForResearch?: boolean;
}

export function activeReps(session: SessionRecord): RepRecord[] {
  return session.reps.filter((rep) => !rep.isDeleted);
}

export function sessionDuration(session: SessionRecord): number {
  return ((session.endedAt ?? Date.now()) - session.startedAt) / 1000;
}

export function averageScore(session: SessionRecord): number | null {
  const scores = activeReps(session).map((rep) => rep.score);
  if (scores.length === 0) return null;
  return scores.reduce((sum, value) => sum + value, 0) / scores.length;
}

export function bestScore(session: SessionRecord): number | null {
  const scores = activeReps(session).map((rep) => rep.score);
  return scores.length ? Math.max(...scores) : null;
}

export function worstScore(session: SessionRecord): number | null {
  const scores = activeReps(session).map((rep) => rep.score);
  return scores.length ? Math.min(...scores) : null;
}

/** 100 minus the normalised spread of rep scores. */
export function consistency(session: SessionRecord): number | null {
  const scores = activeReps(session).map((rep) => rep.score);
  const mean = averageScore(session);
  if (scores.length <= 1 || mean === null) return null;
  const variance =
    scores.reduce((sum, value) => sum + (value - mean) ** 2, 0) / scores.length;
  return Math.max(0, Math.min(100, 100 - Math.sqrt(variance) * 2.4));
}

/** Average of each mechanic across the session's reps. */
export function mechanicAverages(
  session: SessionRecord,
): Partial<Record<MechanicID, number>> {
  const totals = new Map<MechanicID, { sum: number; count: number }>();
  for (const rep of activeReps(session)) {
    for (const item of rep.mechanics) {
      const existing = totals.get(item.mechanic) ?? { sum: 0, count: 0 };
      totals.set(item.mechanic, {
        sum: existing.sum + item.score,
        count: existing.count + 1,
      });
    }
  }
  const result: Partial<Record<MechanicID, number>> = {};
  totals.forEach((value, key) => {
    if (value.count > 0) result[key] = value.sum / value.count;
  });
  return result;
}

/** Mechanics in rubric order, so summaries read consistently. */
export function orderedMechanicAverages(
  session: SessionRecord,
): { mechanic: MechanicID; score: number }[] {
  const averages = mechanicAverages(session);
  return rubricFor(session.shot)
    .components.map((component) => ({
      mechanic: component.mechanic,
      score: averages[component.mechanic],
    }))
    .filter(
      (entry): entry is { mechanic: MechanicID; score: number } =>
        entry.score !== undefined,
    );
}

export function weakestMechanic(
  session: SessionRecord,
): { mechanic: MechanicID; score: number } | null {
  const ordered = orderedMechanicAverages(session);
  if (ordered.length === 0) return null;
  return ordered.reduce((lowest, entry) =>
    entry.score < lowest.score ? entry : lowest,
  );
}

/** Snapshot of a mechanic's score at a point in time; the progress backbone. */
export interface MechanicHistoryPoint {
  id: string;
  date: number;
  shot: ShotType;
  mechanic: MechanicID;
  score: number;
}

/** Per-shot-group rating shown on the skill card. */
export interface ShotRating {
  group: ShotGroup;
  score: number;
  previousScore: number | null;
  repCount: number;
}

export interface Achievement {
  id: string;
  title: string;
  detail: string;
  earnedAt: number;
  icon: string;
}

export interface UserFeedbackRecord {
  id: string;
  repID: string;
  sessionID: string;
  kind: "repDeleted" | "shotReclassified" | "scoreDisputed";
  originalShot: ShotType;
  correctedShot?: ShotType;
  createdAt: number;
}

export function newRep(input: Omit<
  RepRecord,
  | "id"
  | "isDeleted"
  | "wasReclassified"
  | "benchmarkVersion"
  | "ballSpeedMPH"
  | "spinRPM"
  | "paddleFaceAngleDegrees"
  | "contactTimingPrecisionMS"
  | "sharedForResearch"
>): RepRecord {
  return {
    ...input,
    id: crypto.randomUUID(),
    isDeleted: false,
    wasReclassified: false,
    benchmarkVersion: BENCHMARK_VERSION,
    ballSpeedMPH: null,
    spinRPM: null,
    paddleFaceAngleDegrees: null,
    contactTimingPrecisionMS: null,
    sharedForResearch: false,
  };
}

/** Fills fields added in schema v2 on reps saved by older versions. */
export function normalizeRep(rep: Partial<RepRecord> & RepRecord): RepRecord {
  return {
    ...rep,
    ballSpeedMPH: rep.ballSpeedMPH ?? null,
    spinRPM: rep.spinRPM ?? null,
    paddleFaceAngleDegrees: rep.paddleFaceAngleDegrees ?? null,
    contactTimingPrecisionMS: rep.contactTimingPrecisionMS ?? null,
    sharedForResearch: rep.sharedForResearch ?? false,
  };
}

export function repGroup(rep: RepRecord): ShotGroup {
  return groupOf(rep.shot);
}
