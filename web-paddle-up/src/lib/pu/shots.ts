/**
 * Shot taxonomy. The whole app is architected around these from day one;
 * only forehand/backhand dink ship with a production analyzer.
 */

export type AnalyzerStatus = "production" | "preview" | "planned";

export const analyzerStatusLabel: Record<AnalyzerStatus, string> = {
  production: "Live",
  preview: "Preview",
  planned: "Coming soon",
};

export type ShotGroup =
  | "dink"
  | "serve"
  | "returnOfServe"
  | "drive"
  | "volley"
  | "reset"
  | "thirdShotDrop"
  | "speedUp"
  | "overhead"
  | "block"
  | "rollVolley"
  | "lob";

export const shotGroups: ShotGroup[] = [
  "dink",
  "serve",
  "returnOfServe",
  "drive",
  "volley",
  "reset",
  "thirdShotDrop",
  "speedUp",
  "overhead",
  "block",
  "rollVolley",
  "lob",
];

export const shotGroupName: Record<ShotGroup, string> = {
  dink: "Dink",
  serve: "Serve",
  returnOfServe: "Return",
  drive: "Drive",
  volley: "Volley",
  reset: "Reset",
  thirdShotDrop: "Third-Shot Drop",
  speedUp: "Speed-Up",
  overhead: "Overhead",
  block: "Block",
  rollVolley: "Roll Volley",
  lob: "Lob",
};

/** lucide-react icon names, mirroring the iOS SF Symbol choices. */
export const shotGroupIcon: Record<ShotGroup, string> = {
  dink: "Grid2x2",
  serve: "Hand",
  returnOfServe: "Undo2",
  drive: "Zap",
  volley: "LayoutGrid",
  reset: "CircleDashed",
  thirdShotDrop: "Crosshair",
  speedUp: "Rabbit",
  overhead: "ArrowUpCircle",
  block: "Shield",
  rollVolley: "Tornado",
  lob: "ArrowUpRight",
};

export type ShotType =
  | "forehandDink"
  | "backhandDink"
  | "forehandDrive"
  | "backhandDrive"
  | "forehandVolley"
  | "backhandVolley"
  | "reset"
  | "thirdShotDrop"
  | "serve"
  | "returnOfServe"
  | "speedUp"
  | "overhead"
  | "rollVolley"
  | "block"
  | "lob";

export const shotTypes: ShotType[] = [
  "forehandDink",
  "backhandDink",
  "forehandDrive",
  "backhandDrive",
  "forehandVolley",
  "backhandVolley",
  "reset",
  "thirdShotDrop",
  "serve",
  "returnOfServe",
  "speedUp",
  "overhead",
  "rollVolley",
  "block",
  "lob",
];

export const shotName: Record<ShotType, string> = {
  forehandDink: "Forehand Dink",
  backhandDink: "Backhand Dink",
  forehandDrive: "Forehand Drive",
  backhandDrive: "Backhand Drive",
  forehandVolley: "Forehand Volley",
  backhandVolley: "Backhand Volley",
  reset: "Reset",
  thirdShotDrop: "Third-Shot Drop",
  serve: "Serve",
  returnOfServe: "Return",
  speedUp: "Speed-Up",
  overhead: "Overhead",
  rollVolley: "Roll Volley",
  block: "Block",
  lob: "Lob",
};

export function groupOf(shot: ShotType): ShotGroup {
  switch (shot) {
    case "forehandDink":
    case "backhandDink":
      return "dink";
    case "forehandDrive":
    case "backhandDrive":
      return "drive";
    case "forehandVolley":
    case "backhandVolley":
      return "volley";
    case "reset":
      return "reset";
    case "thirdShotDrop":
      return "thirdShotDrop";
    case "serve":
      return "serve";
    case "returnOfServe":
      return "returnOfServe";
    case "speedUp":
      return "speedUp";
    case "overhead":
      return "overhead";
    case "rollVolley":
      return "rollVolley";
    case "block":
      return "block";
    case "lob":
      return "lob";
  }
}

export function analyzerStatusOf(shot: ShotType): AnalyzerStatus {
  switch (shot) {
    case "forehandDink":
    case "backhandDink":
      return "production";
    case "reset":
    case "thirdShotDrop":
    case "serve":
      return "preview";
    default:
      return "planned";
  }
}

export const shotSummary: Record<ShotType, string> = {
  forehandDink: "Soft, controlled shot from the kitchen line.",
  backhandDink: "Soft, controlled shot from the kitchen line.",
  reset: "Absorb pace and drop the ball back into the kitchen.",
  thirdShotDrop: "Arcing drop from the baseline to win the net.",
  serve: "Underhand delivery that starts the point.",
  forehandDrive: "Flat, driven ball from mid-court or baseline.",
  backhandDrive: "Flat, driven ball from mid-court or baseline.",
  forehandVolley: "Punch volley taken out of the air at the net.",
  backhandVolley: "Punch volley taken out of the air at the net.",
  returnOfServe: "Deep return that buys time to reach the kitchen.",
  speedUp: "Sudden attack out of a dink exchange.",
  overhead: "Put-away smash on a short lob.",
  rollVolley: "Topspin roll taken out of the air.",
  block: "Soft-hands defensive answer to a speed-up.",
  lob: "High, deep ball over the opponents at the net.",
};

/** Shots the player can actually start a practice session with today. */
export const practiceableShots: ShotType[] = shotTypes.filter(
  (shot) => analyzerStatusOf(shot) !== "planned",
);
