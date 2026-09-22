/**
 * Turns a structured RepAnalysis into coaching: one dominant issue, one
 * correction, one cue, one drill. Measurement happens first, language second.
 */

import {
  issueById,
  issueFor,
  praiseForScore,
  severityForScore,
  type CoachingIssue,
  type IssueSeverity,
} from "./coaching-knowledge";
import { drillForMechanic } from "./drills";
import { mechanicCue, mechanicName, type MechanicID } from "./mechanics";
import {
  activeReps,
  mechanicAverages,
  mechanicOf,
  weakestMechanic,
  type SessionRecord,
} from "./profile";
import type { RepAnalysis } from "./scoring";
import { groupOf, shotGroupName, type ShotType } from "./shots";

/** The coaching payload attached to a rep. Exactly ONE correction, by design. */
export interface RepCoaching {
  issue?: CoachingIssue;
  headline: string;
  correction: string;
  cue: string;
  severity: IssueSeverity;
  drillID?: string;
  isPraise: boolean;
}

/** Recurring-weakness insight across multiple sessions. */
export interface WeaknessInsight {
  id: string;
  mechanic: MechanicID;
  shot: ShotType;
  sessionCount: number;
  averageScore: number;
  trend: number;
  message: string;
  drillID?: string;
}

/** Coaching for a single rep. */
export function coachRep(analysis: RepAnalysis): RepCoaching {
  const dominant = analysis.dominantIssue;
  const mechanicScore = dominant
    ? analysis.mechanics.find((item) => item.mechanic === dominant)
    : undefined;

  if (!dominant || !mechanicScore) {
    return {
      headline: praiseForScore(analysis.score),
      correction: "Nothing major to change — repeat exactly that.",
      cue: "SAME AGAIN",
      severity: "minor",
      isPraise: true,
    };
  }

  const issue = issueFor(dominant, analysis.shot, analysis.dominantValueIsHigh);
  const severity = severityForScore(mechanicScore.score);

  if (!issue) {
    return {
      headline: `${mechanicName[dominant]} needs work`,
      correction: `Focus on your ${mechanicName[dominant].toLowerCase()} on the next rep.`,
      cue: mechanicCue[dominant],
      severity,
      drillID: drillForMechanic(dominant, analysis.shot)?.id,
      isPraise: false,
    };
  }

  return {
    issue,
    headline: issue.title,
    correction: issue.correction,
    cue: issue.cue,
    severity,
    drillID: issue.drillID,
    isPraise: false,
  };
}

/** The session's single most important focus, from its reps. */
export function sessionFocus(session: SessionRecord): RepCoaching | null {
  const reps = activeReps(session);
  if (reps.length === 0) return null;

  // Count how often each mechanic was the dominant issue, weighted by how bad
  // it was, so one terrible rep does not outvote a pattern.
  const burden = new Map<MechanicID, number>();
  const highVotes = new Map<MechanicID, number>();
  const lowVotes = new Map<MechanicID, number>();

  for (const rep of reps) {
    const dominant = rep.dominantIssue;
    if (!dominant) continue;
    const score = mechanicOf(rep, dominant)?.score;
    if (score === undefined) continue;
    burden.set(dominant, (burden.get(dominant) ?? 0) + (100 - score));
    const issue = issueById(rep.issueID);
    if (issue) {
      if (issue.triggersOnHigh) {
        highVotes.set(dominant, (highVotes.get(dominant) ?? 0) + 1);
      } else {
        lowVotes.set(dominant, (lowVotes.get(dominant) ?? 0) + 1);
      }
    }
  }

  let worst: { mechanic: MechanicID; value: number } | null = null;
  burden.forEach((value, mechanic) => {
    if (!worst || value > worst.value) worst = { mechanic, value };
  });

  if (!worst) {
    const best = reps.reduce((sum, rep) => sum + rep.score, 0) / reps.length;
    return {
      headline: praiseForScore(best),
      correction: "Keep repeating this shape.",
      cue: "SAME AGAIN",
      severity: "minor",
      isPraise: true,
    };
  }

  const mechanic = (worst as { mechanic: MechanicID }).mechanic;
  const valueIsHigh = (highVotes.get(mechanic) ?? 0) > (lowVotes.get(mechanic) ?? 0);
  const issue = issueFor(mechanic, session.shot, valueIsHigh);
  const average = mechanicAverages(session)[mechanic] ?? 60;

  return {
    issue,
    headline: issue?.title ?? `${mechanicName[mechanic]} needs work`,
    correction:
      issue?.correction ??
      `Focus on your ${mechanicName[mechanic].toLowerCase()}.`,
    cue: issue?.cue ?? mechanicCue[mechanic],
    severity: severityForScore(average),
    drillID: issue?.drillID ?? drillForMechanic(mechanic, session.shot)?.id,
    isPraise: false,
  };
}

/**
 * Recurring weaknesses across recent sessions — the "this has been your main
 * issue across 4 sessions" insight.
 */
export function recurringWeaknesses(
  sessions: SessionRecord[],
  minimumSessions = 2,
): WeaknessInsight[] {
  const relevant = sessions.filter(
    (session) => activeReps(session).length > 0,
  );
  if (relevant.length < minimumSessions) return [];

  const grouped = new Map<ShotType, SessionRecord[]>();
  for (const session of relevant) {
    const existing = grouped.get(session.shot) ?? [];
    existing.push(session);
    grouped.set(session.shot, existing);
  }

  const insights: WeaknessInsight[] = [];

  grouped.forEach((shotSessions, shot) => {
    const ordered = [...shotSessions].sort((a, b) => a.startedAt - b.startedAt);
    const appearances = new Map<MechanicID, number[]>();

    for (const session of ordered) {
      const weakest = weakestMechanic(session);
      if (!weakest) continue;
      const existing = appearances.get(weakest.mechanic) ?? [];
      existing.push(weakest.score);
      appearances.set(weakest.mechanic, existing);
    }

    appearances.forEach((scores, mechanic) => {
      if (scores.length < minimumSessions) return;
      const average = scores.reduce((sum, value) => sum + value, 0) / scores.length;
      const trend = (scores[scores.length - 1] ?? average) - (scores[0] ?? average);
      const groupLabel = shotGroupName[groupOf(shot)];
      const mechanicLabel = mechanicName[mechanic].toLowerCase();

      let message: string;
      if (trend > 4) {
        message = `${groupLabel} ${mechanicLabel} has been your main issue across ${scores.length} sessions, but it is improving (+${Math.round(trend)}). Keep the current drill.`;
      } else if (trend < -4) {
        message = `${groupLabel} ${mechanicLabel} has been your main issue across ${scores.length} sessions and it is slipping (${Math.round(trend)}). Slow the drill down.`;
      } else {
        message = `${groupLabel} ${mechanicLabel} has been your main issue across ${scores.length} sessions. It is not moving yet — commit to the prescribed drill.`;
      }

      insights.push({
        id: `${shot}-${mechanic}`,
        mechanic,
        shot,
        sessionCount: scores.length,
        averageScore: average,
        trend,
        message,
        drillID: drillForMechanic(mechanic, shot)?.id,
      });
    });
  });

  return insights.sort((a, b) => b.sessionCount - a.sessionCount);
}
