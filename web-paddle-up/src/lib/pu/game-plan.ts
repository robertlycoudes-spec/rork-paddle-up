/**
 * Builds the player's game plan. Two inputs drive it:
 *
 *   1. The player's DUPR range — sets the starting curriculum, drill
 *      difficulty and training volume.
 *   2. Measured practice data — once sessions exist, the mechanics that
 *      actually score lowest take over the plan's lead slots.
 *
 * The remaining onboarding answers (style, goals, struggles, weekly time,
 * success metric) only fine-tune volume and add extra plan lines; they never
 * choose the core focus. A brand-new player with no sessions gets the
 * curriculum for their range. Deterministic and pure — mirrors the iOS
 * GamePlanEngine exactly.
 */

import { allDrills, drillForMechanic, drillsForShot } from "./drills";
import type { MechanicID } from "./mechanics";
import {
  duprFullLabel,
  duprOrder,
  duprRangeOption,
  practiceDaysPerWeek,
  trainingGoalName,
  trainingTimeRepScale,
  weeklyMinutesFor,
  type BiggestStruggle,
  type DuprRange,
  type PlayerProfile,
  type PlayerStyle,
  type PlayFrequency,
  type SuccessMetric,
  type TrainingGoal,
  type WeeklyTrainingTime,
} from "./profile";
import type { ShotType } from "./shots";

/** Everything the onboarding flow collects, in order. */
export interface OnboardingAnswers {
  name: string;
  /** Undefined until the player picks a range. */
  duprRange?: DuprRange;
  playerTypes: PlayerStyle[];
  frequency: PlayFrequency;
  goals: TrainingGoal[];
  struggles: BiggestStruggle[];
  trainingTime: WeeklyTrainingTime;
  successMetric?: SuccessMetric;
}

export function emptyAnswers(): OnboardingAnswers {
  return {
    name: "",
    playerTypes: [],
    frequency: "weekly",
    goals: [],
    struggles: [],
    trainingTime: "moderate",
  };
}

/** One line of the this-week prescription. */
export interface GamePlanItem {
  id: string;
  title: string;
  amount: number;
  /** "reps", "min", "sessions" — how `amount` is counted. */
  unit: string;
  icon: string;
}

/** The personalised result shown before the paywall. */
export interface GamePlan {
  opportunity: string;
  opportunityDetail: string;
  items: GamePlanItem[];
  focusCue: string;
  weeklyMinutes: number;
  practiceDays: number;
}

export interface WeeklyPlanEntry {
  id: string;
  /** 1 = Sunday, matching JavaScript's Date.getDay() + 1. */
  weekday: number;
  shot: ShotType;
  mechanic: MechanicID;
  drillID: string;
  isAssessment: boolean;
  completedAt?: number;
}

export interface WeeklyPlan {
  generatedAt: number;
  entries: WeeklyPlanEntry[];
  /** Explains why this plan was built the way it was. */
  rationale: string;
}

/** A measured weak spot from real reps. */
export interface MeasuredFocus {
  shot: ShotType;
  mechanic: MechanicID;
}

export const weekdayNames = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

/** Range used when a player has not picked one (legacy profiles only). */
export const DEFAULT_RANGE: DuprRange = "lowerIntermediate";

// MARK: - Level curriculum

/** The skills a player in this range should build first, in priority order. */
export function curriculumFor(range: DuprRange): TrainingGoal[] {
  switch (range) {
    case "beginner":
      return ["consistency", "dinking", "serve"];
    case "lowerIntermediate":
      return ["dinking", "consistency", "returnOfServe"];
    case "intermediate":
      return ["thirdShotDrops", "dinking", "consistency"];
    case "upperIntermediate":
      return ["thirdShotDrops", "volleys", "dinking"];
    case "advanced":
      return ["volleys", "thirdShotDrops", "drives"];
    case "advancedPlus":
      return ["volleys", "drives", "speedReaction"];
    case "pro":
      return ["speedReaction", "volleys", "drives"];
  }
}

/** Multiplies prescribed rep counts: newer players start lighter. */
export function volumeScaleFor(range: DuprRange): number {
  switch (range) {
    case "beginner":
      return 0.7;
    case "lowerIntermediate":
      return 0.85;
    case "intermediate":
      return 1.0;
    case "upperIntermediate":
      return 1.1;
    case "advanced":
      return 1.2;
    case "advancedPlus":
      return 1.3;
    case "pro":
      return 1.4;
  }
}

/** Advanced ranges rehearse pressure, not just technique. */
export function wantsPressureWork(range: DuprRange): boolean {
  return duprOrder(range) >= duprOrder("advanced");
}

function levelNarrative(range: DuprRange): string {
  switch (range) {
    case "beginner":
      return "At 2.0–2.49 the fastest gains come from keeping the ball in play. We'll build a repeatable contact point and a reliable serve before anything else.";
    case "lowerIntermediate":
      return "At 2.5–2.99 points are won and lost at the kitchen. We'll build a controlled dink and a deep return so you can get there and stay there.";
    case "intermediate":
      return "At 3.0–3.49 the third shot decides whether you reach the kitchen at all. We'll build your drop on top of a steady dink.";
    case "upperIntermediate":
      return "At 3.5–3.99 the gap is consistency under pace — clean drops, quiet hands at the line, and volleys that don't pop up.";
    case "advanced":
      return "At 4.0–4.49 hands battles and shot selection decide games. We'll sharpen your volleys and keep your drop reliable when it matters.";
    case "advancedPlus":
      return "At 4.5–4.99 the margins are small. We'll tighten your volley shape, add depth to your drives and speed up your first step.";
    case "pro":
      return "At 5.0+ every rep is about marginal gains — reaction speed, a stable paddle in fast exchanges and drives with intent.";
  }
}

// MARK: - Onboarding result

/**
 * Struggles that don't map to a shot skill (conditioning, direction) return
 * null and are handled as extra plan lines instead.
 */
export function struggleGoal(struggle: BiggestStruggle): TrainingGoal | null {
  switch (struggle) {
    case "unforcedErrors":
      return "consistency";
    case "serveNeedsWork":
      return "serve";
    case "consistency":
      return "consistency";
    case "kitchenPoints":
      return "dinking";
    case "thirdShot":
      return "thirdShotDrops";
    case "betterPlayers":
      return "strategyIQ";
    case "whatToPractice":
    case "fitness":
      return null;
  }
}

/** The core focus areas: the range's curriculum. */
export function focusAreas(answers: OnboardingAnswers): TrainingGoal[] {
  return curriculumFor(answers.duprRange ?? DEFAULT_RANGE);
}

/** Scales a rep count and rounds to a clean, credible number. */
function scaled(base: number, scale: number): number {
  return Math.max(5, Math.round((base * scale) / 5) * 5);
}

function prescriptionTitle(goal: TrainingGoal): string {
  switch (goal) {
    case "consistency":
      return "Controlled cross-court dinks";
    case "serve":
      return "Serve reps to depth targets";
    case "returnOfServe":
      return "Deep return reps";
    case "dinking":
      return "Kitchen dink reps";
    case "thirdShotDrops":
      return "Third-shot drop reps";
    case "drives":
      return "Drive reps with depth targets";
    case "volleys":
      return "Punch volley reps";
    case "speedReaction":
      return "Reaction footwork";
    case "strategyIQ":
      return "Strategy sessions";
    case "competitive":
      return "Reaction drills";
  }
}

let itemCounter = 0;
function makeItem(
  title: string,
  amount: number,
  unit: string,
  icon: string,
): GamePlanItem {
  itemCounter += 1;
  return { id: `plan-item-${itemCounter}`, title, amount, unit, icon };
}

function prescriptionItem(goal: TrainingGoal, scale: number): GamePlanItem {
  const title = prescriptionTitle(goal);
  switch (goal) {
    case "consistency":
      return makeItem(title, scaled(30, scale), "reps", "Target");
    case "serve":
      return makeItem(title, scaled(36, scale), "reps", "Hand");
    case "returnOfServe":
      return makeItem(title, scaled(24, scale), "reps", "Undo2");
    case "dinking":
      return makeItem(title, scaled(30, scale), "reps", "Grid2x2");
    case "thirdShotDrops":
      return makeItem(title, scaled(40, scale), "reps", "Crosshair");
    case "drives":
      return makeItem(title, scaled(30, scale), "reps", "Zap");
    case "volleys":
      return makeItem(title, scaled(40, scale), "reps", "LayoutGrid");
    case "speedReaction":
      return makeItem(title, scaled(10, scale), "min", "Rabbit");
    case "strategyIQ":
      return makeItem(title, 2, "sessions", "Brain");
    case "competitive":
      return makeItem(title, 3, "drills", "Zap");
  }
}

/** A counterweight line chosen from one of the player's self-described styles. */
function styleItem(style: PlayerStyle, scale: number): GamePlanItem {
  switch (style) {
    case "aggressive":
      return makeItem(
        "Soft resets to balance your attack",
        scaled(20, scale),
        "reps",
        "ArrowDownCircle",
      );
    case "defensive":
      return makeItem("Attack the short ball", scaled(20, scale), "reps", "Zap");
    case "consistent":
      return makeItem("Streak challenges — 10 clean in a row", 5, "sets", "Repeat");
    case "athletic":
      return makeItem(
        "Footwork & conditioning",
        scaled(10, scale),
        "min",
        "Footprints",
      );
    case "strategic":
      return makeItem("Strategy sessions", 2, "sessions", "Brain");
    case "figuringOut":
      return makeItem(
        "Guided sessions with your AI coach",
        3,
        "sessions",
        "AudioWaveform",
      );
  }
}

function styleClause(style: PlayerStyle): string {
  switch (style) {
    case "aggressive":
      return "You play aggressive, so we keep your pace and add a reliable soft option — attack from the kitchen, not from no-man's land.";
    case "defensive":
      return "You play defensive, so alongside that we'll train you to step in and finish the short ball instead of resetting it back.";
    case "consistent":
      return "You already play consistent, so your reps are scored in streaks — the bar is clean repetition, not highlight shots.";
    case "athletic":
      return "You're fast, so we'll convert that athleticism into position: early split-steps and balanced contact.";
    case "strategic":
      return "You think the game, so your plan pairs every technical block with a pattern to run it inside.";
    case "figuringOut":
      return "You're still finding your style, so your first weeks stay guided — Paddle Up will show you what your game is actually good at.";
  }
}

function successClause(metric: SuccessMetric): string {
  switch (metric) {
    case "fewerErrors":
      return "You'll know it's working when your unforced errors drop — that's the number we track first.";
    case "winMoreGames":
      return "You'll know it's working when you win more of the games you used to lose close.";
    case "consistency":
      return "You'll know it's working when your rep scores tighten up — consistency is measured as your spread, not your best shot.";
    case "beatBetterPlayers":
      return "You'll know it's working when stronger opponents stop getting free points off you.";
    case "higherDUPR":
      return "Rating gains follow error reduction, so we'll track your Paddle Up score as the leading indicator of your rating.";
    case "confidence":
      return "You'll know it's working when you stop second-guessing the shot mid-swing.";
    case "winTournaments":
      return "You'll know it's working when your game holds up on tournament day, so we rehearse pressure, not just technique.";
  }
}

export function generateGamePlan(answers: OnboardingAnswers): GamePlan {
  const range = answers.duprRange ?? DEFAULT_RANGE;
  const areas = curriculumFor(range);
  const primary = areas[0];
  const opportunity = `${trainingGoalName[primary]} + ${trainingGoalName[areas[1]].toLowerCase()}`;
  const scale = trainingTimeRepScale[answers.trainingTime] * volumeScaleFor(range);

  const items: GamePlanItem[] = [];
  const add = (item: GamePlanItem) => {
    if (!items.some((existing) => existing.title === item.title)) items.push(item);
  };

  // Core: the curriculum for the player's range.
  for (const goal of areas) add(prescriptionItem(goal, scale));

  // Fine-tuning: personal answers add lines but never replace the core.
  if (wantsPressureWork(range)) {
    add(
      makeItem(
        "Scored, game-like reps",
        duprOrder(range) >= duprOrder("advancedPlus") ? 3 : 2,
        "sessions",
        "Trophy",
      ),
    );
  }
  const extraGoals = [
    ...answers.struggles
      .map(struggleGoal)
      .filter((goal): goal is TrainingGoal => goal !== null),
    ...answers.goals,
  ];
  for (const goal of extraGoals) {
    if (!areas.includes(goal)) add(prescriptionItem(goal, scale));
  }
  for (const style of answers.playerTypes.slice(0, 2)) add(styleItem(style, scale));
  if (answers.struggles.includes("whatToPractice")) {
    add(makeItem("Guided sessions with your AI coach", 3, "sessions", "AudioWaveform"));
  }
  if (
    answers.struggles.includes("fitness") &&
    !items.some((item) => item.unit === "min")
  ) {
    add(makeItem("Footwork & conditioning", scaled(10, scale), "min", "Footprints"));
  }

  const sentences = [levelNarrative(range)];
  const style = answers.playerTypes[0];
  if (style) sentences.push(styleClause(style));
  if (answers.successMetric) sentences.push(successClause(answers.successMetric));

  return {
    opportunity,
    opportunityDetail: sentences.join(" "),
    // Keep the reveal glanceable — the plan adapts weekly anyway.
    items: items.slice(0, 5),
    focusCue: focusCueFor(answers, primary),
    weeklyMinutes: weeklyMinutesFor[answers.trainingTime],
    practiceDays: practiceDaysPerWeek[answers.trainingTime],
  };
}

/** The single cue the coach repeats first, nudged by playing style. */
export function focusCueFor(
  answers: OnboardingAnswers,
  primary: TrainingGoal,
): string {
  const softGame: TrainingGoal[] = ["dinking", "thirdShotDrops", "consistency"];
  if (answers.playerTypes.includes("aggressive") && softGame.includes(primary)) {
    return "Patience first — earn the attack";
  }
  if (
    answers.playerTypes.includes("defensive") &&
    (primary === "drives" || primary === "volleys")
  ) {
    return "Step in early, finish through the ball";
  }
  return goalFocusCue(primary);
}

export function goalFocusCue(goal: TrainingGoal): string {
  switch (goal) {
    case "consistency":
      return "One ball, one target — every rep has a purpose";
    case "serve":
      return "Same toss, same contact, every time";
    case "returnOfServe":
      return "Deep and through, then move in";
    case "dinking":
      return "Soft hands, paddle above the waist";
    case "thirdShotDrops":
      return "Lift with the legs, finish high";
    case "drives":
      return "Low to high, finish at the target";
    case "volleys":
      return "Punch from the shoulder, don't swing";
    case "speedReaction":
      return "First step explosive, stay low";
    case "strategyIQ":
      return "Pick your spot before the point starts";
    case "competitive":
      return "Play the score, not the moment";
  }
}

export function shotForGoal(goal: TrainingGoal): ShotType {
  switch (goal) {
    case "consistency":
    case "dinking":
    case "speedReaction":
    case "competitive":
      return "forehandDink";
    case "serve":
      return "serve";
    case "returnOfServe":
      return "returnOfServe";
    case "thirdShotDrops":
    case "strategyIQ":
      return "thirdShotDrop";
    case "drives":
      return "forehandDrive";
    case "volleys":
      return "forehandVolley";
  }
}

export function mechanicForGoal(goal: TrainingGoal): MechanicID {
  switch (goal) {
    case "consistency":
    case "dinking":
    case "returnOfServe":
    case "strategyIQ":
    case "competitive":
      return "contactPosition";
    case "serve":
      return "stanceWidth";
    case "thirdShotDrops":
      return "weightTransfer";
    case "drives":
      return "followThrough";
    case "volleys":
      return "armStructure";
    case "speedReaction":
      return "kneeBend";
  }
}

/** Rebuilds the onboarding answers from a saved profile. */
export function answersFromProfile(profile: PlayerProfile): OnboardingAnswers {
  return {
    name: profile.displayName,
    duprRange: profile.duprRange,
    playerTypes: profile.playerTypes,
    frequency: profile.frequency,
    goals: profile.goals,
    struggles: profile.struggles,
    trainingTime: profile.trainingTime,
    successMetric: profile.successMetric,
  };
}

/** The shot a player should practise first when they have no sessions yet. */
export function focusShotFor(profile: PlayerProfile): ShotType {
  return shotForGoal(curriculumFor(profile.duprRange ?? DEFAULT_RANGE)[0]);
}

/** A drill for the mechanic that suits the player's range. */
export function drillIDFor(
  mechanic: MechanicID,
  shot: ShotType,
  range: DuprRange,
): string {
  const suitable = allDrills.filter(
    (drill) => duprOrder(drill.minimumLevel) <= duprOrder(range),
  );
  const pick =
    suitable.find((drill) => drill.targetMechanic === mechanic && drill.shot === shot) ??
    drillForMechanic(mechanic, shot);
  return pick?.id ?? allDrills[0].id;
}

/** Practice weekdays (1 = Sunday) for the player's weekly time budget. */
export function practiceWeekdays(time: WeeklyTrainingTime): number[] {
  const days = practiceDaysPerWeek[time];
  if (days <= 2) return [2, 5];
  if (days === 3) return [2, 4, 6];
  if (days === 4) return [2, 3, 5, 6];
  return [2, 3, 4, 5, 6];
}

/**
 * The weekly plan. Measured weak spots (from real reps) lead; remaining slots
 * come from the range curriculum. With no measured data the whole week is the
 * curriculum — the default for a brand-new player. Every week ends with a
 * Sunday assessment so change is measured.
 */
export function buildWeeklyPlan(
  profile: PlayerProfile,
  measured: MeasuredFocus[],
  leadInsight: string | null = null,
  now: number = Date.now(),
): WeeklyPlan {
  const range = profile.duprRange ?? DEFAULT_RANGE;
  const curriculumFocus: MeasuredFocus[] = curriculumFor(range).map((goal) => ({
    shot: shotForGoal(goal),
    mechanic: mechanicForGoal(goal),
  }));

  const focus: MeasuredFocus[] = [];
  for (const item of [...measured.slice(0, 3), ...curriculumFocus]) {
    if (!focus.some((f) => f.shot === item.shot && f.mechanic === item.mechanic)) {
      focus.push(item);
    }
  }

  const entries: WeeklyPlanEntry[] = practiceWeekdays(profile.trainingTime).map(
    (weekday, index) => {
      const item = focus[index % focus.length];
      return {
        id: crypto.randomUUID(),
        weekday,
        shot: item.shot,
        mechanic: item.mechanic,
        drillID: drillIDFor(item.mechanic, item.shot, range),
        isAssessment: false,
      };
    },
  );

  const lead = focus[0];
  entries.push({
    id: crypto.randomUUID(),
    weekday: 1,
    shot: lead.shot,
    mechanic: lead.mechanic,
    drillID: drillsForShot(lead.shot)[0]?.id ?? allDrills[0].id,
    isAssessment: true,
  });

  const rangeLabel = duprRangeOption(range).rangeLabel;
  let rationale: string;
  if (leadInsight) {
    rationale = `Built around your recurring ${leadInsight} issue, measured from your reps, with the rest of the week from the ${rangeLabel} curriculum and a Sunday assessment to measure whether it moved.`;
  } else if (measured.length > 0) {
    rationale = `Built from the weakest mechanics in your recent sessions, rounded out with the ${rangeLabel} curriculum and a Sunday assessment to measure progress.`;
  } else {
    rationale = `A starter week for a ${duprFullLabel(range)} player, ending with an assessment so Paddle Up can measure your baseline. Once you log sessions, your measured weak spots take over the plan.`;
  }
  return { generatedAt: now, entries, rationale };
}
