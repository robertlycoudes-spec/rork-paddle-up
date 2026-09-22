/**
 * Local-first persistence. Everything the player generates — profile, sessions,
 * reps, mechanic history, plans, feedback — is stored in localStorage, scoped
 * per account.
 *
 * The schema mirrors the intended server tables (User, PlayerProfile, Session,
 * Rep, MechanicScore, Drill, Recommendation, PracticePlan, ProgressMetric,
 * Achievement, UserFeedback) so a backend sync layer can be added without
 * reshaping the client's data model.
 */

import type { WeeklyPlan } from "./game-plan";
import {
  emptyProfile,
  type Achievement,
  type MechanicHistoryPoint,
  type PlayerProfile,
  type SessionRecord,
  type UserFeedbackRecord,
} from "./profile";

export type VoiceCoachingLevel =
  | "off"
  | "importantOnly"
  | "everyFewReps"
  | "frequent";

export const voiceCoachingLevels: {
  id: VoiceCoachingLevel;
  displayName: string;
}[] = [
  { id: "off", displayName: "Off" },
  { id: "importantOnly", displayName: "Important corrections only" },
  { id: "everyFewReps", displayName: "Every few reps" },
  { id: "frequent", displayName: "Frequent" },
];

/** How many reps must pass before speaking again. */
export const voiceRepInterval: Record<VoiceCoachingLevel, number> = {
  off: Number.MAX_SAFE_INTEGER,
  importantOnly: 4,
  everyFewReps: 3,
  frequent: 1,
};

export type SessionLength =
  | "fiveMinutes"
  | "tenMinutes"
  | "fifteenMinutes"
  | "thirtyMinutes"
  | "unlimited";

export const sessionLengths: { id: SessionLength; displayName: string }[] = [
  { id: "fiveMinutes", displayName: "5 min" },
  { id: "tenMinutes", displayName: "10 min" },
  { id: "fifteenMinutes", displayName: "15 min" },
  { id: "thirtyMinutes", displayName: "30 min" },
  { id: "unlimited", displayName: "Manual" },
];

export function sessionLengthSeconds(length: SessionLength): number | null {
  switch (length) {
    case "fiveMinutes":
      return 300;
    case "tenMinutes":
      return 600;
    case "fifteenMinutes":
      return 900;
    case "thirtyMinutes":
      return 1800;
    case "unlimited":
      return null;
  }
}

export function sessionLengthName(length: SessionLength): string {
  return sessionLengths.find((item) => item.id === length)?.displayName ?? "10 min";
}

export interface AppSettings {
  voiceCoaching: VoiceCoachingLevel;
  hapticFeedback: boolean;
  saveRepClips: boolean;
  /** Days after which clips are purged automatically. */
  clipRetentionDays: number;
  developerModeEnabled: boolean;
  analyticsEnabled: boolean;
  defaultSessionLength: SessionLength;
}

export function defaultSettings(): AppSettings {
  return {
    voiceCoaching: "importantOnly",
    hapticFeedback: true,
    saveRepClips: true,
    clipRetentionDays: 14,
    developerModeEnabled: false,
    analyticsEnabled: true,
    defaultSessionLength: "tenMinutes",
  };
}

/** The complete persisted state for one account. */
export interface AccountData {
  profile: PlayerProfile;
  sessions: SessionRecord[];
  mechanicHistory: MechanicHistoryPoint[];
  achievements: Achievement[];
  feedback: UserFeedbackRecord[];
  plan: WeeklyPlan | null;
  settings: AppSettings;
  schemaVersion: number;
}

export function emptyAccountData(): AccountData {
  return {
    profile: emptyProfile(),
    sessions: [],
    mechanicHistory: [],
    achievements: [],
    feedback: [],
    plan: null,
    settings: defaultSettings(),
    schemaVersion: 1,
  };
}

const ACCOUNT_KEY = "app.paddleup.account.id";

function storageKey(accountID: string): string {
  return `app.paddleup.data.${accountID}`;
}

/**
 * Every launch runs on an implicit on-device account (a stable ID kept in
 * localStorage), mirroring the iOS app's local account model.
 */
export function ensureLocalAccount(): {
  id: string;
  email: string;
  displayName: string;
} {
  let id: string | null = null;
  try {
    id = localStorage.getItem(ACCOUNT_KEY);
    if (!id) {
      id = crypto.randomUUID();
      localStorage.setItem(ACCOUNT_KEY, id);
    }
  } catch {
    // Private browsing or storage disabled — run in memory for this session.
    id = crypto.randomUUID();
  }
  return { id, email: "", displayName: "" };
}

/** Tolerant load: data saved by earlier versions still opens with defaults. */
export function loadAccountData(accountID: string): AccountData | null {
  try {
    const raw = localStorage.getItem(storageKey(accountID));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<AccountData>;
    const fallback = emptyAccountData();
    return {
      profile: { ...fallback.profile, ...(parsed.profile ?? {}) },
      sessions: parsed.sessions ?? [],
      mechanicHistory: parsed.mechanicHistory ?? [],
      achievements: parsed.achievements ?? [],
      feedback: parsed.feedback ?? [],
      plan: parsed.plan ?? null,
      settings: { ...fallback.settings, ...(parsed.settings ?? {}) },
      schemaVersion: parsed.schemaVersion ?? 1,
    };
  } catch (error) {
    console.warn("Paddle Up: failed to decode saved data, starting fresh.");
    return null;
  }
}

export function saveAccountData(data: AccountData, accountID: string): void {
  try {
    localStorage.setItem(storageKey(accountID), JSON.stringify(data));
  } catch {
    // Quota exceeded or storage disabled — the session keeps working in memory.
    console.warn("Paddle Up: could not persist data to this browser.");
  }
}

export function deleteAccountData(accountID: string): void {
  try {
    localStorage.removeItem(storageKey(accountID));
  } catch {
    // Nothing to do — storage is already unavailable.
  }
}
