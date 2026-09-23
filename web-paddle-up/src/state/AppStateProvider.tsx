/**
 * Single source of truth for the player's data. Owns persistence, derives
 * ratings/progress, and prescribes drills and plans — the web counterpart of
 * the iOS AppState observable.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import {
  recurringWeaknesses as computeRecurringWeaknesses,
  sessionFocus,
  type WeaknessInsight,
} from "@/lib/pu/coaching";
import { drillById, drillsForShot, type Drill } from "@/lib/pu/drills";
import {
  answersFromProfile,
  buildWeeklyPlan,
  focusShotFor,
  type MeasuredFocus,
  type OnboardingAnswers,
  type WeeklyPlan,
} from "@/lib/pu/game-plan";
import { mechanicName } from "@/lib/pu/mechanics";
import { allMechanics, type MechanicID } from "@/lib/pu/mechanics";
import {
  deleteAccountData,
  emptyAccountData,
  ensureLocalAccount,
  loadAccountData,
  saveAccountData,
  type AccountData,
  type AppSettings,
} from "@/lib/pu/persistence";
import {
  activeReps,
  mechanicAverages,
  weakestMechanic,
  type Achievement,
  type MechanicHistoryPoint,
  type PlayerProfile,
  type RepRecord,
  type SessionRecord,
  type ShotRating,
} from "@/lib/pu/profile";
import { overallRatingFrom, ratingFromReps } from "@/lib/pu/scoring";
import { groupOf, shotGroupName, shotGroups, type ShotGroup, type ShotType } from "@/lib/pu/shots";

export interface WeeklyTrendPoint {
  label: string;
  score: number;
}

interface AppStateValue {
  data: AccountData;
  profile: PlayerProfile;
  settings: AppSettings;
  sessions: SessionRecord[];
  completedSessions: SessionRecord[];
  isLoaded: boolean;

  updateProfile: (transform: (profile: PlayerProfile) => PlayerProfile) => void;
  updateSettings: (transform: (settings: AppSettings) => AppSettings) => void;
  saveOnboardingDraft: (answers: OnboardingAnswers) => void;
  completeOnboarding: (answers: OnboardingAnswers) => void;
  resetOnboarding: () => void;

  saveSession: (session: SessionRecord) => void;
  sessionById: (id: string) => SessionRecord | undefined;
  deleteSession: (id: string) => void;
  deleteRep: (rep: RepRecord) => void;
  reclassifyRep: (rep: RepRecord, shot: ShotType) => void;

  repsFor: (group: ShotGroup) => RepRecord[];
  shotRatings: ShotRating[];
  overallRating: number | null;
  overallRatingDelta: number | null;
  strongestShot: ShotRating | null;
  weakestShot: ShotRating | null;
  totalRepCount: number;
  completedSessionCount: number;
  practiceStreak: number;

  historyFor: (mechanic: MechanicID, group?: ShotGroup) => MechanicHistoryPoint[];
  improvementFor: (
    mechanic: MechanicID,
    group?: ShotGroup,
    days?: number,
  ) => number | null;
  biggestImprovement: {
    mechanic: MechanicID;
    delta: number;
    group: ShotGroup;
  } | null;
  weeklyTrend: (group: ShotGroup, weeks?: number) => WeeklyTrendPoint[];

  recommendedDrill: Drill | null;
  recurringWeaknesses: WeaknessInsight[];
  weeklyPlan: WeeklyPlan | null;
  regeneratePlan: () => void;
  markPlanEntryComplete: (entryID: string) => void;
  achievements: Achievement[];

  deleteAllPracticeData: () => void;
  deleteEverything: () => void;
  /** Replaces local data with a newer cloud snapshot (last write wins). */
  applyRemote: (remote: AccountData) => void;
}

const AppStateContext = createContext<AppStateValue | null>(null);

const DAY_MS = 86_400_000;

function startOfDay(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function AppStateProvider({ children }: { children: ReactNode }) {
  const [accountID, setAccountID] = useState<string | null>(null);
  const [data, setData] = useState<AccountData>(() => emptyAccountData());
  const [isLoaded, setIsLoaded] = useState<boolean>(false);
  const saveTimer = useRef<number | null>(null);

  // Load the implicit on-device account once on mount.
  useEffect(() => {
    const account = ensureLocalAccount();
    setAccountID(account.id);
    const loaded = loadAccountData(account.id);
    if (loaded) {
      // Profiles saved before the new onboarding ran have no level; send them
      // through onboarding again rather than personalising on nothing.
      if (loaded.profile.hasCompletedOnboarding && !loaded.profile.duprRange) {
        loaded.profile = { ...loaded.profile, hasCompletedOnboarding: false };
      }
      setData(loaded);
    }
    setIsLoaded(true);
  }, []);

  // Every local change stamps modifiedAt, which cloud sync uses for
  // last-write-wins. Remote snapshots (applyRemote) keep their own stamp.
  const setLocalData = useCallback(
    (transform: (current: AccountData) => AccountData) => {
      setData((current) => {
        const next = transform(current);
        return next === current ? current : { ...next, modifiedAt: Date.now() };
      });
    },
    [],
  );

  // Debounced write so rapid rep updates don't thrash storage.
  useEffect(() => {
    if (!accountID || !isLoaded) return;
    if (saveTimer.current !== null) window.clearTimeout(saveTimer.current);
    saveTimer.current = window.setTimeout(() => {
      saveAccountData(data, accountID);
    }, 400);
    return () => {
      if (saveTimer.current !== null) window.clearTimeout(saveTimer.current);
    };
  }, [data, accountID, isLoaded]);

  const completedSessions = useMemo(
    () =>
      data.sessions
        .filter((session) => session.endedAt && activeReps(session).length > 0)
        .sort((a, b) => b.startedAt - a.startedAt),
    [data.sessions],
  );

  const allReps = useMemo(
    () => data.sessions.flatMap((session) => activeReps(session)),
    [data.sessions],
  );

  const repsFor = useCallback(
    (group: ShotGroup) => allReps.filter((rep) => groupOf(rep.shot) === group),
    [allReps],
  );

  /** Per-shot-group ratings for the skill card, best first. */
  const shotRatings = useMemo<ShotRating[]>(() => {
    return shotGroups
      .map((group) => {
        const reps = repsFor(group).sort((a, b) => a.timestamp - b.timestamp);
        if (reps.length === 0) return null;
        const score = ratingFromReps(reps);
        if (score === null) return null;

        // Previous rating = rating excluding the most recent session's reps.
        const mostRecent = data.sessions
          .filter(
            (session) =>
              groupOf(session.shot) === group && activeReps(session).length > 0,
          )
          .sort((a, b) => b.startedAt - a.startedAt)[0];
        const older = reps.filter((rep) => rep.sessionID !== mostRecent?.id);
        const previous = older.length >= 5 ? ratingFromReps(older) : null;

        return { group, score, previousScore: previous, repCount: reps.length };
      })
      .filter((rating): rating is ShotRating => rating !== null)
      .sort((a, b) => b.score - a.score);
  }, [data.sessions, repsFor]);

  const overallRating = useMemo(
    () => overallRatingFrom(shotRatings),
    [shotRatings],
  );

  /** Change in overall rating over the last 30 days. */
  const overallRatingDelta = useMemo(() => {
    const cutoff = Date.now() - 30 * DAY_MS;
    const older = data.sessions
      .filter((session) => session.startedAt < cutoff)
      .flatMap((session) => activeReps(session));
    if (older.length < 8 || overallRating === null) return null;
    const then = ratingFromReps(older);
    if (then === null) return null;
    return overallRating - then;
  }, [data.sessions, overallRating]);

  /** Consecutive days with at least one completed session. */
  const practiceStreak = useMemo(() => {
    const days = new Set(
      completedSessions.map((session) => startOfDay(session.startedAt)),
    );
    if (days.size === 0) return 0;

    const today = startOfDay(Date.now());
    let cursor = days.has(today) ? today : today - DAY_MS;
    if (!days.has(cursor)) return 0;

    let streak = 0;
    while (days.has(cursor)) {
      streak += 1;
      cursor -= DAY_MS;
    }
    return streak;
  }, [completedSessions]);

  /** Scores for one mechanic over time, oldest first. */
  const historyFor = useCallback(
    (mechanic: MechanicID, group?: ShotGroup) =>
      data.mechanicHistory
        .filter(
          (point) =>
            point.mechanic === mechanic &&
            (group === undefined || groupOf(point.shot) === group),
        )
        .sort((a, b) => a.date - b.date),
    [data.mechanicHistory],
  );

  /** Improvement in a mechanic over the trailing window. */
  const improvementFor = useCallback(
    (mechanic: MechanicID, group?: ShotGroup, days = 30) => {
      const points = historyFor(mechanic, group);
      if (points.length < 2) return null;
      const cutoff = Date.now() - days * DAY_MS;
      const recent = points.filter((point) => point.date >= cutoff);
      const first = recent[0] ?? points[0];
      const last = points[points.length - 1];
      if (!first || !last || first.id === last.id) return null;
      return last.score - first.score;
    },
    [historyFor],
  );

  /** The mechanic that improved most in the trailing window. */
  const biggestImprovement = useMemo(() => {
    let best: { mechanic: MechanicID; delta: number; group: ShotGroup } | null =
      null;
    for (const group of shotGroups) {
      for (const mechanic of allMechanics) {
        const delta = improvementFor(mechanic, group);
        if (delta === null || delta <= 0) continue;
        if (!best || delta > best.delta) best = { mechanic, delta, group };
      }
    }
    return best;
  }, [improvementFor]);

  /** Weekly averages of a shot group's score, for the trend chart. */
  const weeklyTrend = useCallback(
    (group: ShotGroup, weeks = 4): WeeklyTrendPoint[] => {
      const reps = repsFor(group);
      if (reps.length === 0) return [];

      const today = startOfDay(Date.now());
      const buckets: { label: string; scores: number[] }[] = [];
      for (let offset = weeks - 1; offset >= 0; offset -= 1) {
        const weekEnd = today - offset * 7 * DAY_MS;
        const weekStart = weekEnd - 6 * DAY_MS;
        const inWeek = reps.filter(
          (rep) => rep.timestamp >= weekStart && rep.timestamp <= weekEnd + DAY_MS,
        );
        buckets.push({
          label: `Week ${weeks - offset}`,
          scores: inWeek.map((rep) => rep.score),
        });
      }

      // Carry the last known value forward so the line stays continuous.
      let carried: number | null = null;
      const points: WeeklyTrendPoint[] = [];
      for (const bucket of buckets) {
        if (bucket.scores.length === 0) {
          if (carried === null) continue;
          points.push({ label: bucket.label, score: carried });
          continue;
        }
        const average =
          bucket.scores.reduce((sum, value) => sum + value, 0) /
          bucket.scores.length;
        carried = average;
        points.push({ label: bucket.label, score: average });
      }
      return points;
    },
    [repsFor],
  );

  const recurringWeaknesses = useMemo(
    () => computeRecurringWeaknesses(completedSessions),
    [completedSessions],
  );

  /**
   * Today's recommended drill, derived from the player's weakest measured
   * mechanic — or a sensible starting drill for a brand-new player.
   */
  const recommendedDrill = useMemo<Drill | null>(() => {
    const insight = recurringWeaknesses[0];
    if (insight) {
      const drill = drillById(insight.drillID);
      if (drill) return drill;
    }
    const latest = completedSessions[0];
    if (latest) {
      const focus = sessionFocus(latest);
      const drill = drillById(focus?.drillID);
      if (drill) return drill;
    }
    // No data yet: start from the onboarding game plan.
    return drillsForShot(focusShotFor(data.profile))[0] ?? null;
  }, [recurringWeaknesses, completedSessions, data.profile]);

  const updateProfile = useCallback(
    (transform: (profile: PlayerProfile) => PlayerProfile) => {
      setLocalData((current) => ({ ...current, profile: transform(current.profile) }));
    },
    [setLocalData],
  );

  const updateSettings = useCallback(
    (transform: (settings: AppSettings) => AppSettings) => {
      setLocalData((current) => ({ ...current, settings: transform(current.settings) }));
    },
    [setLocalData],
  );

  const applyAnswers = useCallback(
    (profile: PlayerProfile, answers: OnboardingAnswers): PlayerProfile => ({
      ...profile,
      displayName: answers.name.trim() ? answers.name : profile.displayName,
      duprRange: answers.duprRange ?? profile.duprRange,
      playerTypes: answers.playerTypes,
      frequency: answers.frequency,
      goals: answers.goals,
      struggles: answers.struggles,
      trainingTime: answers.trainingTime,
      successMetric: answers.successMetric,
    }),
    [],
  );

  /** Saves a draft as answers are collected, so nothing is lost on reload. */
  const saveOnboardingDraft = useCallback(
    (answers: OnboardingAnswers) => {
      setLocalData((current) => ({
        ...current,
        profile: applyAnswers(current.profile, answers),
      }));
    },
    [applyAnswers, setLocalData],
  );

  /**
   * Builds the week from the DUPR range plus measured practice data:
   * recurring issues first, then each recent session's weakest mechanic.
   */
  const buildPlan = useCallback((source: AccountData): WeeklyPlan => {
    const completed = source.sessions
      .filter((session) => session.endedAt && activeReps(session).length > 0)
      .sort((a, b) => b.startedAt - a.startedAt);
    const insights = computeRecurringWeaknesses(completed);

    const measured: MeasuredFocus[] = insights
      .slice(0, 3)
      .map((insight) => ({ shot: insight.shot, mechanic: insight.mechanic }));
    for (const session of completed.slice(0, 4)) {
      const weakest = weakestMechanic(session);
      if (!weakest) continue;
      const exists = measured.some(
        (item) => item.shot === session.shot && item.mechanic === weakest.mechanic,
      );
      if (!exists) measured.push({ shot: session.shot, mechanic: weakest.mechanic });
    }

    const first = insights[0];
    const lead = first
      ? `${mechanicName[first.mechanic].toLowerCase()} on the ${shotGroupName[
          groupOf(first.shot)
        ].toLowerCase()}`
      : null;
    return buildWeeklyPlan(source.profile, measured, lead);
  }, []);

  /** Completes onboarding and installs the level-based starter plan. */
  const completeOnboarding = useCallback(
    (answers: OnboardingAnswers) => {
      setLocalData((current) => {
        const next: AccountData = {
          ...current,
          profile: {
            ...applyAnswers(current.profile, answers),
            hasCompletedOnboarding: true,
          },
        };
        return { ...next, plan: buildPlan(next) };
      });
    },
    [applyAnswers, buildPlan, setLocalData],
  );

  const resetOnboarding = useCallback(() => {
    setLocalData((current) => ({
      ...current,
      profile: { ...current.profile, hasCompletedOnboarding: false },
    }));
  }, [setLocalData]);

  const awardAchievements = useCallback(
    (source: AccountData, session: SessionRecord): Achievement[] => {
      const reps = activeReps(session);
      if (reps.length === 0) return source.achievements;

      const average = reps.reduce((sum, rep) => sum + rep.score, 0) / reps.length;
      const best = Math.max(...reps.map((rep) => rep.score));
      const earned = [...source.achievements];

      const award = (
        id: string,
        title: string,
        detail: string,
        icon: string,
      ) => {
        if (earned.some((item) => item.id === id)) return;
        earned.push({ id, title, detail, earnedAt: Date.now(), icon });
      };

      const previousBest = source.sessions
        .filter(
          (item) =>
            item.id !== session.id && groupOf(item.shot) === groupOf(session.shot),
        )
        .map((item) => {
          const itemReps = activeReps(item);
          if (itemReps.length === 0) return 0;
          return itemReps.reduce((sum, rep) => sum + rep.score, 0) / itemReps.length;
        })
        .reduce((max, value) => Math.max(max, value), 0);

      if (previousBest < average && reps.length >= 10) {
        award(
          `pb_${groupOf(session.shot)}_${Math.round(best)}`,
          "New personal best",
          `${shotGroupName[groupOf(session.shot)]} score: ${Math.round(best)}`,
          "Trophy",
        );
      }

      const totalReps = source.sessions.flatMap((item) => activeReps(item)).length;
      for (const milestone of [100, 500, 1000, 2500]) {
        if (totalReps >= milestone) {
          award(
            `reps_${milestone}`,
            `${milestone} reps logged`,
            "Every one of them measured.",
            "BadgeCheck",
          );
        }
      }

      return earned;
    },
    [],
  );

  const saveSession = useCallback(
    (incoming: SessionRecord) => {
      setLocalData((current) => {
        // Consent flags are stamped from the current setting; only flags the
        // record — nothing is sent anywhere.
        const session: SessionRecord = current.settings.shareAnonymizedData
          ? {
              ...incoming,
              sharedForResearch: true,
              reps: incoming.reps.map((rep) => ({ ...rep, sharedForResearch: true })),
            }
          : incoming;
        const sessions = current.sessions.some((item) => item.id === session.id)
          ? current.sessions.map((item) =>
              item.id === session.id ? session : item,
            )
          : [...current.sessions, session];

        // Record one mechanic-history point per mechanic per session, so
        // progress is stored at mechanic granularity, not just overall score.
        const history = current.mechanicHistory.filter(
          (point) =>
            !(point.date === session.startedAt && point.shot === session.shot),
        );
        const averages = mechanicAverages(session);
        for (const key of Object.keys(averages) as MechanicID[]) {
          const score = averages[key];
          if (score === undefined) continue;
          history.push({
            id: `${session.id}-${key}`,
            date: session.startedAt,
            shot: session.shot,
            mechanic: key,
            score,
          });
        }

        const next: AccountData = {
          ...current,
          sessions,
          mechanicHistory: history,
          profile:
            session.mode === "assessment" && activeReps(session).length > 0
              ? { ...current.profile, hasCompletedBaselineAssessment: true }
              : current.profile,
        };
        next.achievements = awardAchievements(next, session);

        // Refresh weekly, or as soon as the first completed session gives the
        // plan measured data to replace the level-only starter week.
        const completedCount = sessions.filter(
          (item) => item.endedAt && activeReps(item).length > 0,
        ).length;
        const isFirstMeasured =
          session.endedAt !== undefined &&
          activeReps(session).length > 0 &&
          completedCount === 1;
        if (
          !next.plan ||
          isFirstMeasured ||
          Date.now() - next.plan.generatedAt > 7 * DAY_MS
        ) {
          next.plan = buildPlan(next);
        }
        return next;
      });
    },
    [awardAchievements, buildPlan, setLocalData],
  );

  const sessionById = useCallback(
    (id: string) => data.sessions.find((session) => session.id === id),
    [data.sessions],
  );

  const deleteSession = useCallback((id: string) => {
    setLocalData((current) => {
      const sessions = current.sessions.filter((session) => session.id !== id);
      return {
        ...current,
        sessions,
        mechanicHistory: current.mechanicHistory.filter((point) =>
          sessions.some(
            (session) =>
              session.startedAt === point.date && session.shot === point.shot,
          ),
        ),
      };
    });
  }, [setLocalData]);

  const deleteRep = useCallback((rep: RepRecord) => {
    setLocalData((current) => ({
      ...current,
      sessions: current.sessions.map((session) =>
        session.id !== rep.sessionID
          ? session
          : {
              ...session,
              reps: session.reps.map((item) =>
                item.id === rep.id ? { ...item, isDeleted: true } : item,
              ),
            },
      ),
      feedback: [
        ...current.feedback,
        {
          id: crypto.randomUUID(),
          repID: rep.id,
          sessionID: rep.sessionID,
          kind: "repDeleted" as const,
          originalShot: rep.shot,
          createdAt: Date.now(),
        },
      ],
    }));
  }, [setLocalData]);

  const reclassifyRep = useCallback((rep: RepRecord, shot: ShotType) => {
    setLocalData((current) => ({
      ...current,
      sessions: current.sessions.map((session) =>
        session.id !== rep.sessionID
          ? session
          : {
              ...session,
              reps: session.reps.map((item) =>
                item.id === rep.id
                  ? { ...item, shot, wasReclassified: true }
                  : item,
              ),
            },
      ),
      feedback: [
        ...current.feedback,
        {
          id: crypto.randomUUID(),
          repID: rep.id,
          sessionID: rep.sessionID,
          kind: "shotReclassified" as const,
          originalShot: rep.shot,
          correctedShot: shot,
          createdAt: Date.now(),
        },
      ],
    }));
  }, [setLocalData]);

  const regeneratePlan = useCallback(() => {
    setLocalData((current) => ({ ...current, plan: buildPlan(current) }));
  }, [buildPlan, setLocalData]);

  const markPlanEntryComplete = useCallback((entryID: string) => {
    setLocalData((current) => {
      if (!current.plan) return current;
      return {
        ...current,
        plan: {
          ...current.plan,
          entries: current.plan.entries.map((entry) =>
            entry.id === entryID ? { ...entry, completedAt: Date.now() } : entry,
          ),
        },
      };
    });
  }, [setLocalData]);

  /** Erases all practice data while keeping the account and profile. */
  const deleteAllPracticeData = useCallback(() => {
    setLocalData((current) => ({
      ...current,
      sessions: [],
      mechanicHistory: [],
      achievements: [],
      feedback: [],
      plan: null,
      profile: { ...current.profile, hasCompletedBaselineAssessment: false },
    }));
  }, [setLocalData]);

  const deleteEverything = useCallback(() => {
    if (accountID) deleteAccountData(accountID);
    setData(emptyAccountData());
  }, [accountID]);

  const applyRemote = useCallback((remote: AccountData) => {
    setData(remote);
  }, []);

  const achievements = useMemo(
    () => [...data.achievements].sort((a, b) => b.earnedAt - a.earnedAt),
    [data.achievements],
  );

  const value = useMemo<AppStateValue>(
    () => ({
      data,
      profile: data.profile,
      settings: data.settings,
      sessions: data.sessions,
      completedSessions,
      isLoaded,
      updateProfile,
      updateSettings,
      saveOnboardingDraft,
      completeOnboarding,
      resetOnboarding,
      saveSession,
      sessionById,
      deleteSession,
      deleteRep,
      reclassifyRep,
      repsFor,
      shotRatings,
      overallRating,
      overallRatingDelta,
      strongestShot: shotRatings[0] ?? null,
      weakestShot: shotRatings[shotRatings.length - 1] ?? null,
      totalRepCount: allReps.length,
      completedSessionCount: completedSessions.length,
      practiceStreak,
      historyFor,
      improvementFor,
      biggestImprovement,
      weeklyTrend,
      recommendedDrill,
      recurringWeaknesses,
      weeklyPlan: data.plan,
      regeneratePlan,
      markPlanEntryComplete,
      achievements,
      deleteAllPracticeData,
      deleteEverything,
      applyRemote,
    }),
    [
      applyRemote,
      data,
      completedSessions,
      isLoaded,
      updateProfile,
      updateSettings,
      saveOnboardingDraft,
      completeOnboarding,
      resetOnboarding,
      saveSession,
      sessionById,
      deleteSession,
      deleteRep,
      reclassifyRep,
      repsFor,
      shotRatings,
      overallRating,
      overallRatingDelta,
      allReps.length,
      practiceStreak,
      historyFor,
      improvementFor,
      biggestImprovement,
      weeklyTrend,
      recommendedDrill,
      recurringWeaknesses,
      regeneratePlan,
      markPlanEntryComplete,
      achievements,
      deleteAllPracticeData,
      deleteEverything,
    ],
  );

  return (
    <AppStateContext.Provider value={value}>{children}</AppStateContext.Provider>
  );
}

export function useAppState(): AppStateValue {
  const context = useContext(AppStateContext);
  if (!context) {
    throw new Error("useAppState must be used inside AppStateProvider");
  }
  return context;
}

export { answersFromProfile };
