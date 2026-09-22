/**
 * Structured coaching knowledge: problems, explanations, correction cues and
 * drills. Deliberately data, not code inside screens, so coaches can extend it.
 */

import type { MechanicID } from "./mechanics";
import { mechanicName } from "./mechanics";
import type { ShotType } from "./shots";

export type IssueSeverity = "minor" | "moderate" | "major";

export const severityLabel: Record<IssueSeverity, string> = {
  minor: "Minor",
  moderate: "Worth fixing",
  major: "Priority fix",
};

/** One diagnosable mechanical problem. */
export interface CoachingIssue {
  id: string;
  mechanic: MechanicID;
  /** Shot types this issue applies to. Empty means all. */
  shots: ShotType[];
  /** True when the measured value sits ABOVE the ideal band, false when below. */
  triggersOnHigh: boolean;
  title: string;
  explanation: string;
  correction: string;
  drillID: string;
  /** Cue shown as "next rep focus" and spoken by live coaching. */
  cue: string;
}

export const coachingIssues: CoachingIssue[] = [
  {
    id: "contact_too_close",
    mechanic: "contactPosition",
    shots: [],
    triggersOnHigh: false,
    title: "Contact point too close to body",
    explanation:
      "The ball is getting in behind you, so your arm has no room to work and the paddle face closes at contact.",
    correction:
      "Create space and meet the ball farther in front of your lead hip.",
    drillID: "dink_contact_point",
    cue: "CONTACT OUT FRONT",
  },
  {
    id: "contact_too_far",
    mechanic: "contactPosition",
    shots: [],
    triggersOnHigh: true,
    title: "Reaching for contact",
    explanation:
      "You are stretching to reach the ball, which pulls you off balance and costs control on the next ball.",
    correction:
      "Move your feet earlier so the ball arrives at a comfortable arm's length.",
    drillID: "dink_contact_point",
    cue: "MOVE YOUR FEET",
  },
  {
    id: "standing_tall",
    mechanic: "kneeBend",
    shots: [],
    triggersOnHigh: true,
    title: "Legs too straight at contact",
    explanation:
      "Standing tall raises your contact point and forces the arm to do the work your legs should be doing.",
    correction:
      "Sit into your knees and hold a lower athletic base through the exchange.",
    drillID: "dink_low_base",
    cue: "STAY LOWER",
  },
  {
    id: "over_squat",
    mechanic: "kneeBend",
    shots: [],
    triggersOnHigh: false,
    title: "Squatting too deep to move",
    explanation:
      "You are dropping so low that you cannot push off and recover for the next ball.",
    correction: "Raise into a loaded but mobile base — bent knees, chest up.",
    drillID: "dink_low_base",
    cue: "ATHLETIC BASE",
  },
  {
    id: "arm_collapsed",
    mechanic: "armStructure",
    shots: [],
    triggersOnHigh: false,
    title: "Elbow collapsing into the body",
    explanation:
      "Your elbow is folding in, which turns a controlled push into a wristy flick.",
    correction:
      "Keep a firm bend and move the arm from the shoulder, not the wrist.",
    drillID: "dink_arm_shape",
    cue: "HOLD ARM SHAPE",
  },
  {
    id: "arm_locked",
    mechanic: "armStructure",
    shots: [],
    triggersOnHigh: true,
    title: "Arm locked straight",
    explanation:
      "A straight, rigid arm removes the softness you need to absorb pace and control the ball.",
    correction: "Soften into a slight elbow bend so the arm can give at contact.",
    drillID: "dink_arm_shape",
    cue: "SOFTEN THE ELBOW",
  },
  {
    id: "head_lifting",
    mechanic: "headStability",
    shots: [],
    triggersOnHigh: true,
    title: "Head moving through contact",
    explanation:
      "Your head is lifting before the paddle meets the ball, which pulls your whole body up and out of the shot.",
    correction:
      "Keep your eyes down and your head still until the ball leaves the paddle.",
    drillID: "dink_quiet_head",
    cue: "HEAD STILL",
  },
  {
    id: "no_follow_through",
    mechanic: "followThrough",
    shots: [],
    triggersOnHigh: false,
    title: "Stopping the paddle at the ball",
    explanation:
      "The stroke is stopping at contact, so you lose the lift and direction that comes from finishing.",
    correction:
      "Push through the ball and finish with the paddle out toward your target.",
    drillID: "dink_follow_through",
    cue: "FINISH THE SWING",
  },
  {
    id: "overswinging",
    mechanic: "followThrough",
    shots: [],
    triggersOnHigh: true,
    title: "Swinging too big on a soft ball",
    explanation:
      "A long, fast finish on a touch shot adds pace you cannot control and floats the ball up.",
    correction: "Shorten the finish — this is a lift and a push, not a swing.",
    drillID: "dink_follow_through",
    cue: "SHORTEN IT",
  },
  {
    id: "hands_too_firm",
    mechanic: "softHands",
    shots: ["reset", "block"],
    triggersOnHigh: true,
    title: "Hands too firm on the reset",
    explanation:
      "You are punching at the ball instead of absorbing it, so the reset pops up into the attack zone.",
    correction: "Loosen your grip and let the paddle give at contact.",
    drillID: "reset_soft_hands",
    cue: "SOFT HANDS",
  },
  {
    id: "no_weight_transfer",
    mechanic: "weightTransfer",
    shots: ["thirdShotDrop", "serve", "forehandDrive", "backhandDrive"],
    triggersOnHigh: false,
    title: "Hitting without moving through the ball",
    explanation:
      "You are standing still and lifting with the arm, which makes depth control inconsistent.",
    correction: "Transfer your weight forward and step through contact.",
    drillID: "drop_weight_transfer",
    cue: "STEP THROUGH",
  },
  {
    id: "falling_forward",
    mechanic: "weightTransfer",
    shots: ["thirdShotDrop", "serve"],
    triggersOnHigh: true,
    title: "Falling through the shot",
    explanation:
      "Too much forward momentum is carrying you off balance and delaying your recovery.",
    correction: "Transfer weight in a controlled step and finish balanced.",
    drillID: "drop_weight_transfer",
    cue: "BALANCED FINISH",
  },
  {
    id: "off_balance",
    mechanic: "balance",
    shots: [],
    triggersOnHigh: true,
    title: "Losing balance through the shot",
    explanation:
      "Your base is moving during the stroke, so every ball comes off the paddle differently.",
    correction: "Set your feet before you swing and keep your weight centred.",
    drillID: "dink_low_base",
    cue: "STAY BALANCED",
  },
  {
    id: "narrow_stance",
    mechanic: "stanceWidth",
    shots: ["serve"],
    triggersOnHigh: false,
    title: "Base too narrow on the serve",
    explanation:
      "A narrow stance gives you nothing to push against, so the serve depends on arm speed alone.",
    correction: "Set your feet just wider than your shoulders before you start.",
    drillID: "serve_base",
    cue: "WIDEN YOUR BASE",
  },
];

export function issueById(id: string | undefined): CoachingIssue | undefined {
  if (!id) return undefined;
  return coachingIssues.find((issue) => issue.id === id);
}

function appliesTo(issue: CoachingIssue, shot: ShotType): boolean {
  return issue.shots.length === 0 || issue.shots.includes(shot);
}

/**
 * Resolve the diagnosed problem for a mechanic given whether the measured
 * value sat above or below the ideal band.
 */
export function issueFor(
  mechanic: MechanicID,
  shot: ShotType,
  valueIsHigh: boolean,
): CoachingIssue | undefined {
  const candidates = coachingIssues.filter(
    (issue) => issue.mechanic === mechanic && appliesTo(issue, shot),
  );
  return (
    candidates.find((issue) => issue.triggersOnHigh === valueIsHigh) ??
    candidates[0]
  );
}

export function severityForScore(score: number): IssueSeverity {
  if (score < 55) return "major";
  if (score < 72) return "moderate";
  return "minor";
}

/** Positive reinforcement when nothing is clearly wrong. */
export function praiseForScore(score: number): string {
  if (score >= 92) return "Textbook rep. Lock that in.";
  if (score >= 85) return "Strong rep — keep that shape.";
  return "Solid rep. Stay with it.";
}

export function mechanicDisplayName(mechanic: MechanicID): string {
  return mechanicName[mechanic];
}
