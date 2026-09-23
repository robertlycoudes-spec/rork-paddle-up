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
  migrateLegacySkillLevel,
  normalizeRep,
  type Achievement,
  type DuprRange,
  type MechanicHistoryPoint,
  type PlayerProfile,
  type RepRecord,
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
  /**
   * Opt-in (default OFF) to share anonymized rep/session data to help improve
   * scoring. Today this only flags new records; no data is sent.
   */
  shareAnonymizedData: boolean;
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
    shareAnonymizedData: false,
  };
}

/**
 * Current schema. v2 introduced DUPR ranges, reserved ball/paddle rep fields,
 * consent flags and `modifiedAt` for cloud sync.
 */
export const CURRENT_SCHEMA_VERSION = 2;

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
  /**
   * Epoch ms of the last local change. Cloud sync is last-write-wins on this
   * value — no merging. 0 means "never changed since v1", so never-synced data
   * cannot beat a newer cloud copy.
   */
  modifiedAt: number;
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
    schemaVersion: CURRENT_SCHEMA_VERSION,
    modifiedAt: 0,
  };
}

type LegacyProfile = Partial<PlayerProfile> & {
  skillLevel?: unknown;
  weaknesses?: unknown;
  motivation?: unknown;
  competitiveness?: unknown;
};

const DUPR_IDS: DuprRange[] = [
  "beginner",
  "lowerIntermediate",
  "intermediate",
  "upperIntermediate",
  "advanced",
  "advancedPlus",
  "pro",
];

/**
 * Tolerant decode + migration of raw saved (or synced) data into the current
 * schema. Every field falls back to its default; retired onboarding fields are
 * dropped; the old five-step level maps onto a DUPR band.
 */
export function migrateAccountData(parsed: Partial<AccountData>): AccountData {
  const fallback = emptyAccountData();
  const {
    skillLevel,
    weaknesses: _weaknesses,
    motivation: _motivation,
    competitiveness: _competitiveness,
    ...profile
  } = (parsed.profile ?? {}) as LegacyProfile;

  const storedRange =
    profile.duprRange && DUPR_IDS.includes(profile.duprRange)
      ? profile.duprRange
      : undefined;

  const sessions: SessionRecord[] = (parsed.sessions ?? []).map((session) => ({
    ...session,
    sharedForResearch: session.sharedForResearch ?? false,
    reps: (session.reps ?? []).map((rep) => normalizeRep(rep as RepRecord)),
  }));

  return {
    profile: {
      ...fallback.profile,
      ...profile,
      duprRange: storedRange ?? migrateLegacySkillLevel(skillLevel),
    },
    sessions,
    mechanicHistory: parsed.mechanicHistory ?? [],
    achievements: parsed.achievements ?? [],
    feedback: parsed.feedback ?? [],
    plan: parsed.plan ?? null,
    settings: { ...fallback.settings, ...(parsed.settings ?? {}) },
    schemaVersion: Math.max(parsed.schemaVersion ?? 1, CURRENT_SCHEMA_VERSION),
    modifiedAt: typeof parsed.modifiedAt === "number" ? parsed.modifiedAt : 0,
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
    try {
      return migrateAccountData(JSON.parse(raw) as Partial<AccountData>);
    } catch {
      // Keep the unreadable copy aside instead of overwriting it.
      localStorage.setItem(`${storageKey(accountID)}.unreadable`, raw);
      console.warn("Paddle Up: saved data unreadable; backed up, starting fresh.");
      return null;
    }
  } catch {
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
