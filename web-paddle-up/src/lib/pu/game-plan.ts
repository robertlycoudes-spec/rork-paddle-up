/**
 * Turns onboarding answers into a personalised game plan: the player's biggest
 * opportunity, a this-week prescription, and a weekly plan wired to the real
 * drill library. Deterministic and pure — the same answers always produce the
 * same plan, so the "AI result" is reproducible and testable.
 */

import { allDrills, drillForMechanic, drillsForShot } from "./drills";
import type { MechanicID } from "./mechanics";
import {
  competitivenessRepScale,
  practiceDaysPerWeek,
  trainingGoalName,
  trainingTimeRepScale,
  weaknessFocusName,
  wantsPressureWork,
  weeklyMinutesFor,
  type BiggestStruggle,
  type BiggestWeakness,
  type Competitiveness,
  type PlayerProfile,
  type PlayerStyle,
  type PlayFrequency,
  type SkillLevel,
  type SuccessMetric,
  type TrainingGoal,
  type TrainingMotivation,
  type WeeklyTrainingTime,
} from "./profile";
import type { ShotType } from "./shots";

/** Everything the onboarding flow collects, in order. */
export interface OnboardingAnswers {
  name: string;
  level: SkillLevel;
  playerTypes: PlayerStyle[];
  frequency: PlayFrequency;
  goals: TrainingGoal[];
  struggles: BiggestStruggle[];
  weaknesses: BiggestWeakness[];
  trainingTime: WeeklyTrainingTime;
  motivation?: TrainingMotivation;
  competitiveness?: Competitiveness;
  successMetric?: SuccessMetric;
}

export function emptyAnswers(): OnboardingAnswers {
  return {
    name: "",
    level: "intermediate",
    playerTypes: [],
    frequency: "weekly",
    goals: [],
    struggles: [],
    weaknesses: [],
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

export const weekdayNames = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

/**
 * Weaknesses that map onto a trainable shot skill. Lob and mental game return
 * null and get their own dedicated plan lines instead.
 */
export function weaknessGoal(weakness: BiggestWeakness): TrainingGoal | null {
  switch (weakness) {
    case "serve":
      return "serve";
    case "returnShot":
      return "returnOfServe";
    case "dinking":
      return "dinking";
    case "thirdShotDrop":
      return "thirdShotDrops";
    case "drive":
      return "drives";
    case "volley":
      return "volleys";
    case "footwork":
      return "speedReaction";
    case "strategy":
      return "strategyIQ";
    case "lob":
    case "mentalGame":
      return null;
  }
}

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

/**
 * Goals ranked by priority: the named weakness leads (it is the most specific
 * answer the player gives), then struggles (their own pain), then stated goals.
 */
export function focusAreas(answers: OnboardingAnswers): TrainingGoal[] {
  const fromWeakness = answers.weaknesses
    .map(weaknessGoal)
    .filter((goal): goal is TrainingGoal => goal !== null);
  const fromStruggles = answers.struggles
    .map(struggleGoal)
    .filter((goal): goal is TrainingGoal => goal !== null);

  const merged: TrainingGoal[] = [];
  for (const goal of [...fromWeakness, ...fromStruggles, ...answers.goals]) {
    if (!merged.includes(goal)) merged.push(goal);
  }
  return merged.length === 0 ? ["consistency"] : merged;
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

/** Dedicated line for a weakness that isn't a measurable shot skill yet. */
function weaknessItem(weakness: BiggestWeakness, scale: number): GamePlanItem {
  switch (weakness) {
    case "lob":
      return makeItem(
        "Overhead & lob defence reps",
        scaled(20, scale),
        "reps",
        "ArrowUpRight",
      );
    case "mentalGame":
      return makeItem("Pressure reps — play to a score", 3, "sessions", "Brain");
    default:
      return prescriptionItem(weaknessGoal(weakness) ?? "consistency", scale);
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
      return makeItem(
        "Streak challenges — 10 clean in a row",
        5,
        "sets",
        "Repeat",
      );
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

function weaknessDetail(weakness: BiggestWeakness): string {
  switch (weakness) {
    case "serve":
      return "You named your serve — the one shot nobody can rush. We'll make it repeatable before we make it bigger.";
    case "returnShot":
      return "You named your return. A deep return buys you the kitchen, and it's the fastest gain most players skip.";
    case "dinking":
      return "You named your dinks. Kitchen points reward patience and placement, so we'll build your soft game first.";
    case "thirdShotDrop":
      return "You named your third-shot drop — the shot that decides whether you reach the kitchen at all.";
    case "drive":
      return "You named your drive. Depth and shape come before pace, or the ball just comes back faster.";
    case "volley":
      return "You named your volleys. Holding the line under pressure starts with a stable paddle and a short punch.";
    case "lob":
      return "You named the lob. Reading it early and turning under the ball turns a scramble into an easy overhead.";
    case "footwork":
      return "You named your footwork. Almost every technique fault is really a position fault one step earlier.";
    case "strategy":
      return "You named strategy. Shot selection beats shot-making at every level, so we'll train your decisions.";
    case "mentalGame":
      return "You named the mental game. We'll train it the only way it improves: scored reps where the pressure is real.";
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

function opportunityDetail(goal: TrainingGoal): string {
  switch (goal) {
    case "consistency":
      return "Unforced errors decide more amateur games than winners do. We'll tighten your contact point first.";
    case "serve":
      return "The only shot you fully control. A repeatable serve starts every point on your terms.";
    case "returnOfServe":
      return "A deep return buys you the kitchen. It's the fastest rating gain most players ignore.";
    case "dinking":
      return "Kitchen points are won by patience and placement, not power. We'll build your soft game.";
    case "thirdShotDrops":
      return "Your third shot decides whether you reach the kitchen — we'll build it rep by rep.";
    case "drives":
      return "Penetrating drives create weak replies you can attack. Depth targets first.";
    case "volleys":
      return "Clean volleys let you hold the line under pressure. We'll keep your shape stable.";
    case "speedReaction":
      return "First-step quickness wins the tight exchanges. Short, sharp footwork blocks.";
    case "strategyIQ":
      return "Shot selection beats shot-making at every level. We'll train your decisions.";
    case "competitive":
      return "Competitors rehearse pressure. Your plan mixes skills with scored, game-like reps.";
  }
}

/**
 * Builds the "why this matters" paragraph out of the player's own answers:
 * their weakness, their style, and their definition of success.
 */
function detailNarrative(
  answers: OnboardingAnswers,
  primary: TrainingGoal,
): string {
  const sentences: string[] = [];

  if (answers.weaknesses.length > 0) {
    sentences.push(...answers.weaknesses.slice(0, 2).map(weaknessDetail));
  } else {
    sentences.push(opportunityDetail(primary));
  }
  const style = answers.playerTypes[0];
  if (style) sentences.push(styleClause(style));
  if (answers.successMetric) sentences.push(successClause(answers.successMetric));
  return sentences.join(" ");
}

export function generateGamePlan(answers: OnboardingAnswers): GamePlan {
  const areas = focusAreas(answers);
  const primary = areas[0];
  const secondary = areas.length > 1 ? areas[1] : null;

  // The named weaknesses headline the opportunity when the player gave them;
  // a single weakness is paired with the next focus area.
  let names: string[] = [];
  const firstWeakness = answers.weaknesses[0];
  if (firstWeakness) {
    names.push(weaknessFocusName[firstWeakness]);
    const secondWeakness = answers.weaknesses[1];
    if (secondWeakness) {
      names.push(weaknessFocusName[secondWeakness].toLowerCase());
    } else if (secondary) {
      names.push(trainingGoalName[secondary].toLowerCase());
    }
  }
  if (names.length === 0) names = [trainingGoalName[primary]];
  const opportunity = names.join(" + ");

  const scale =
    trainingTimeRepScale[answers.trainingTime] *
    (answers.level === "justStarting" ? 0.7 : 1.0) *
    (answers.competitiveness
      ? competitivenessRepScale[answers.competitiveness]
      : 1.0);

  const items: GamePlanItem[] = [];
  const hasTitle = (title: string) =>
    items.some((item) => item.title === title);

  // Weaknesses with no shot mapping still lead the plan with their own line.
  for (const weakness of answers.weaknesses) {
    if (weaknessGoal(weakness) !== null) continue;
    const item = weaknessItem(weakness, scale);
    if (!hasTitle(item.title)) items.push(item);
  }
  for (const goal of areas.slice(0, 3)) {
    if (hasTitle(prescriptionTitle(goal))) continue;
    items.push(prescriptionItem(goal, scale));
  }

  // Playing style acts as a counterweight so the plan rounds out the game.
  for (const style of answers.playerTypes.slice(0, 2)) {
    const item = styleItem(style, scale);
    if (!hasTitle(item.title)) items.push(item);
  }

  // Extra lines driven by the unmappable struggles.
  if (answers.struggles.includes("whatToPractice")) {
    items.push(
      makeItem("Guided sessions with your AI coach", 3, "sessions", "AudioWaveform"),
    );
  }
  if (
    answers.struggles.includes("fitness") ||
    answers.goals.includes("speedReaction")
  ) {
    if (!items.some((item) => item.unit === "min")) {
      items.push(
        makeItem("Footwork & conditioning", scaled(10, scale), "min", "Footprints"),
      );
    }
  }
  if (
    answers.goals.includes("strategyIQ") ||
    answers.struggles.includes("betterPlayers")
  ) {
    if (!items.some((item) => item.title.includes("strategy"))) {
      items.push(makeItem("Strategy sessions", 2, "sessions", "Brain"));
    }
  }
  // Competitive players rehearse pressure, not just technique.
  if (
    answers.competitiveness &&
    wantsPressureWork(answers.competitiveness) &&
    !hasTitle("Scored, game-like reps")
  ) {
    items.push(
      makeItem(
        "Scored, game-like reps",
        answers.competitiveness === "tournament" ? 3 : 2,
        "sessions",
        "Trophy",
      ),
    );
  }
  if (
    (answers.motivation === "tournaments" ||
      answers.motivation === "competitivePlayer") &&
    !hasTitle("Reaction drills")
  ) {
    items.push(makeItem("Reaction drills", 3, "drills", "Zap"));
  }

  return {
    opportunity,
    opportunityDetail: detailNarrative(answers, primary),
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
  if (answers.weaknesses.includes("lob")) {
    return "Turn and track — get behind the ball";
  }
  if (answers.weaknesses.includes("mentalGame")) {
    return "One point at a time, reset between reps";
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
      return "forehandDink";
    case "serve":
      return "serve";
    case "returnOfServe":
      return "returnOfServe";
    case "thirdShotDrops":
      return "thirdShotDrop";
    case "drives":
      return "forehandDrive";
    case "volleys":
      return "forehandVolley";
    case "strategyIQ":
      return "thirdShotDrop";
    case "competitive":
      return "forehandDink";
  }
}

export function mechanicForGoal(goal: TrainingGoal): MechanicID {
  switch (goal) {
    case "consistency":
    case "dinking":
    case "returnOfServe":
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
    case "strategyIQ":
    case "competitive":
      return "contactPosition";
  }
}

/**
 * Rebuilds the onboarding answers from a saved profile, so every feature
 * personalises from the same inputs the plan was generated with.
 */
export function answersFromProfile(profile: PlayerProfile): OnboardingAnswers {
  return {
    name: profile.displayName,
    level: profile.skillLevel,
    playerTypes: profile.playerTypes,
    frequency: profile.frequency,
    goals: profile.goals,
    struggles: profile.struggles,
    weaknesses: profile.weaknesses,
    trainingTime: profile.trainingTime,
    motivation: profile.motivation,
    competitiveness: profile.competitiveness,
    successMetric: profile.successMetric,
  };
}

/** The shot the player should practise first, from a saved profile. */
export function focusShotFor(profile: PlayerProfile): ShotType {
  return shotForGoal(focusAreas(answersFromProfile(profile))[0]);
}

/**
 * The active weekly plan, built from onboarding answers, ending in a baseline
 * assessment so improvement can be measured.
 */
export function weeklyPlanFromAnswers(answers: OnboardingAnswers): WeeklyPlan {
  const areas = focusAreas(answers).slice(0, 3);
  const days = practiceDaysPerWeek[answers.trainingTime];

  let daySlots: number[];
  if (days <= 2) daySlots = [2, 5];
  else if (days === 3) daySlots = [2, 4, 6];
  else if (days === 4) daySlots = [2, 3, 5, 6];
  else daySlots = [2, 3, 4, 5, 6];

  const entries: WeeklyPlanEntry[] = daySlots.map((weekday, index) => {
    const goal = areas[index % areas.length];
    const shot = shotForGoal(goal);
    const mechanic = mechanicForGoal(goal);
    return {
      id: crypto.randomUUID(),
      weekday,
      shot,
      mechanic,
      drillID: drillForMechanic(mechanic, shot)?.id ?? allDrills[0].id,
      isAssessment: false,
    };
  });

  const assessmentGoal = areas[0];
  const assessmentShot = shotForGoal(assessmentGoal);
  entries.push({
    id: crypto.randomUUID(),
    weekday: 1,
    shot: assessmentShot,
    mechanic: mechanicForGoal(assessmentGoal),
    drillID: drillsForShot(assessmentShot)[0]?.id ?? allDrills[0].id,
    isAssessment: true,
  });

  const plan = generateGamePlan(answers);
  let rationale = `Built from your onboarding: ${plan.opportunity} is your biggest opportunity, with a baseline assessment so Paddle Up can measure whether it moves.`;
  if (answers.playerTypes.length > 0) {
    const styles = answers.playerTypes
      .slice(0, 2)
      .map((style) => styleDisplayName(style).toLowerCase())
      .join(" + ");
    rationale += ` Balanced for a ${styles} player`;
    if (answers.competitiveness) {
      rationale += ` training as a ${competitivenessDisplayName(
        answers.competitiveness,
      ).toLowerCase()}`;
    }
    rationale += ".";
  }

  return { generatedAt: Date.now(), entries, rationale };
}

function styleDisplayName(style: PlayerStyle): string {
  switch (style) {
    case "aggressive":
      return "Aggressive";
    case "defensive":
      return "Defensive";
    case "consistent":
      return "Consistent";
    case "athletic":
      return "Fast / Athletic";
    case "strategic":
      return "Strategic";
    case "figuringOut":
      return "Still figuring out my style";
  }
}

function competitivenessDisplayName(value: Competitiveness): string {
  switch (value) {
    case "fun":
      return "Just here for fun";
    case "recreational":
      return "Recreational";
    case "veryCompetitive":
      return "Very competitive";
    case "league":
      return "League player";
    case "tournament":
      return "Tournament player";
  }
}
