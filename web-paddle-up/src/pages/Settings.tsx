/**
 * Settings, privacy and account, as grouped rows on surface cards.
 * There is no log-out anywhere; the account offers "Delete all data" instead.
 */

import { useState } from "react";
import { useNavigate } from "react-router-dom";

import { Screen } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  MicroLabel,
  PrimaryButton,
  SecondaryButton,
  SectionHeader,
} from "@/components/pu/Primitives";
import {
  sessionLengths,
  voiceCoachingLevels,
  type SessionLength,
  type VoiceCoachingLevel,
} from "@/lib/pu/persistence";
import { duprRanges } from "@/lib/pu/profile";
import { cn } from "@/lib/utils";
import { useAppState } from "@/state/AppStateProvider";
import { useCloud, type SyncStatus } from "@/state/CloudProvider";
import { useStore } from "@/state/StoreProvider";

const statusText: Record<SyncStatus, string> = {
  signedOut: "Off",
  idle: "Up to date",
  syncing: "Syncing…",
  offline: "Offline — will sync on reconnect",
  failed: "Couldn't reach the cloud — retrying",
};

export default function Settings() {
  const navigate = useNavigate();
  const {
    profile,
    settings,
    updateSettings,
    updateProfile,
    deleteAllPracticeData,
    deleteEverything,
    resetOnboarding,
  } = useAppState();
  const store = useStore();
  const cloud = useCloud();
  const [confirming, setConfirming] = useState<string | null>(null);
  const [cloudMessage, setCloudMessage] = useState<string | null>(null);

  return (
    <Screen className="flex flex-col gap-4">
      <div className="flex items-center gap-3 pt-1">
        <button
          type="button"
          onClick={() => navigate(-1)}
          aria-label="Back"
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-pu-hairline bg-pu-surface text-pu-secondary transition-transform active:scale-95"
        >
          <Icon name="ChevronLeft" className="h-4 w-4" strokeWidth={2.6} />
        </button>
        <h1 className="text-xl font-bold text-pu-primary">Settings</h1>
      </div>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Subscription" />
        <Card>
          <div className="flex items-center gap-3">
            <div className="flex flex-1 flex-col gap-0.5">
              <span className="text-[17px] font-semibold text-pu-primary">
                {store.isPro ? "Paddle Up Pro" : "Free plan"}
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                {store.isPro
                  ? (store.activeProduct?.title ?? "Active")
                  : "1 session included"}
              </span>
            </div>
            {!store.isPro && (
              <button
                type="button"
                onClick={() => navigate("/paywall")}
                className="h-9 shrink-0 rounded-full bg-pu-lime px-4 text-[13px] font-bold text-pu-lime-ink"
              >
                UPGRADE
              </button>
            )}
          </div>
        </Card>
      </div>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Cloud backup" />
        {cloud.user ? (
          <Card>
            <div className="flex flex-col gap-1">
              <span className="text-[17px] font-semibold text-pu-primary">
                {cloud.user.email || cloud.user.name || "Your account"}
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                {statusText[cloud.status]}
                {cloud.lastSyncedAt && cloud.status === "idle"
                  ? ` · ${new Date(cloud.lastSyncedAt).toLocaleTimeString([], {
                      hour: "numeric",
                      minute: "2-digit",
                    })}`
                  : ""}
              </span>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => void cloud.syncNow()}
                disabled={cloud.status === "syncing"}
                className="h-9 rounded-full bg-pu-lime px-4 text-[13px] font-bold text-pu-lime-ink disabled:opacity-60"
              >
                SYNC NOW
              </button>
              <button
                type="button"
                onClick={cloud.signOut}
                className="h-9 rounded-full border border-pu-hairline bg-pu-surface px-4 text-[13px] font-semibold text-pu-primary"
              >
                Sign out
              </button>
              <button
                type="button"
                onClick={async () => {
                  const deleted = await cloud.deleteCloudData();
                  setCloudMessage(
                    deleted
                      ? "Cloud copy deleted. Data in this browser is untouched."
                      : "Couldn't delete right now. Try again.",
                  );
                }}
                className="h-9 px-2 text-[13px] font-semibold text-pu-alert"
              >
                Delete cloud data
              </button>
            </div>
            <p className="mt-2.5 text-[11px] leading-relaxed text-pu-tertiary">
              Changes sync automatically. If this browser and the cloud both
              changed while offline, the most recent change wins.
            </p>
          </Card>
        ) : (
          <Card>
            <span className="text-[17px] font-semibold text-pu-primary">
              Keep your progress safe
            </span>
            <p className="mt-1 text-[13px] font-medium leading-relaxed text-pu-secondary">
              Sign in to back up your profile, sessions, reps, mechanic history,
              plans and settings. Optional — Paddle Up works fully without it.
            </p>
            <div className="mt-3 flex flex-col gap-2">
              <PrimaryButton
                onClick={() => void cloud.signIn("apple")}
                disabled={cloud.isSigningIn}
              >
                Continue with Apple
              </PrimaryButton>
              <SecondaryButton
                onClick={() => void cloud.signIn("google")}
                disabled={cloud.isSigningIn}
              >
                Continue with Google
              </SecondaryButton>
            </div>
          </Card>
        )}
        {(cloud.error || cloudMessage) && (
          <p className="text-[13px] font-medium text-pu-amber">
            {cloud.error ?? cloudMessage}
          </p>
        )}
      </div>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Coaching" />
        <Card padding="p-3.5">
          <MicroLabel>Voice coaching</MicroLabel>
          <div className="mt-2 flex flex-col gap-1.5">
            {voiceCoachingLevels.map((level) => (
              <OptionRow
                key={level.id}
                label={level.displayName}
                isSelected={settings.voiceCoaching === level.id}
                onSelect={() =>
                  updateSettings((current) => ({
                    ...current,
                    voiceCoaching: level.id as VoiceCoachingLevel,
                  }))
                }
              />
            ))}
          </div>
        </Card>

        <Card padding="p-3.5">
          <MicroLabel>Default session length</MicroLabel>
          <div className="mt-2 flex flex-wrap gap-2">
            {sessionLengths.map((option) => (
              <button
                key={option.id}
                type="button"
                onClick={() =>
                  updateSettings((current) => ({
                    ...current,
                    defaultSessionLength: option.id as SessionLength,
                  }))
                }
                className={cn(
                  "h-9 rounded-full border px-3.5 text-[13px] font-semibold transition-colors",
                  settings.defaultSessionLength === option.id
                    ? "border-transparent bg-pu-lime text-pu-lime-ink"
                    : "border-pu-hairline bg-pu-surface text-pu-secondary",
                )}
              >
                {option.displayName}
              </button>
            ))}
          </div>
        </Card>
      </div>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Player" />
        <Card padding="p-3.5">
          <MicroLabel>Paddle hand</MicroLabel>
          <div className="mt-2 flex gap-2">
            {(["right", "left"] as const).map((hand) => (
              <button
                key={hand}
                type="button"
                onClick={() =>
                  updateProfile((current) => ({ ...current, handedness: hand }))
                }
                className={cn(
                  "h-9 flex-1 rounded-full border text-[13px] font-semibold capitalize transition-colors",
                  profile.handedness === hand
                    ? "border-transparent bg-pu-lime text-pu-lime-ink"
                    : "border-pu-hairline bg-pu-surface text-pu-secondary",
                )}
              >
                {hand}
              </button>
            ))}
          </div>
          <p className="mt-2.5 text-[11px] leading-relaxed text-pu-tertiary">
            The analyzer measures your paddle arm, so this must match how you
            actually play.
          </p>
        </Card>
        <Card padding="p-3.5">
          <MicroLabel>Level (DUPR)</MicroLabel>
          <div className="mt-2 flex flex-col gap-1.5">
            {duprRanges.map((range) => (
              <OptionRow
                key={range.id}
                label={`${range.rangeLabel} · ${range.displayName}`}
                isSelected={profile.duprRange === range.id}
                onSelect={() =>
                  updateProfile((current) => ({ ...current, duprRange: range.id }))
                }
              />
            ))}
          </div>
        </Card>
      </div>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Privacy" />
        <Card>
          <p className="text-[15px] font-medium leading-relaxed text-pu-primary">
            Video never leaves your device. Pose estimation runs in your browser,
            and only the resulting scores and mechanic measurements are saved.
          </p>
          <p className="mt-2.5 text-[13px] font-medium leading-relaxed text-pu-secondary">
            Your name is stored on this device to personalise coaching. It is
            never sent to analytics.
          </p>
        </Card>

        <ToggleRow
          label="Anonymous usage analytics"
          detail="Helps tune the detector and rubrics."
          isOn={settings.analyticsEnabled}
          onToggle={() =>
            updateSettings((current) => ({
              ...current,
              analyticsEnabled: !current.analyticsEnabled,
            }))
          }
        />
        <ToggleRow
          label="Help improve scoring"
          detail="Off by default. Marks new sessions and reps as OK to include, anonymized, in future scoring work. Nothing is sent today and video is never included."
          isOn={settings.shareAnonymizedData}
          onToggle={() =>
            updateSettings((current) => ({
              ...current,
              shareAnonymizedData: !current.shareAnonymizedData,
            }))
          }
        />
        <ToggleRow
          label="Developer mode"
          detail="Shows detector state and rejection reasons."
          isOn={settings.developerModeEnabled}
          onToggle={() =>
            updateSettings((current) => ({
              ...current,
              developerModeEnabled: !current.developerModeEnabled,
            }))
          }
        />
      </div>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Account" />

        <SecondaryButton onClick={resetOnboarding}>
          <Icon name="RotateCcw" className="h-4 w-4" strokeWidth={2.4} />
          Redo onboarding
        </SecondaryButton>

        {confirming === "practice" ? (
          <Card className="!border-pu-alert/40">
            <p className="text-[15px] font-medium text-pu-primary">
              Delete every session, rep and measurement? Your profile stays.
            </p>
            <div className="mt-3 flex gap-2.5">
              <button
                type="button"
                onClick={() => {
                  deleteAllPracticeData();
                  setConfirming(null);
                }}
                className="h-11 flex-1 rounded-full bg-pu-alert text-sm font-bold text-white"
              >
                DELETE
              </button>
              <button
                type="button"
                onClick={() => setConfirming(null)}
                className="h-11 flex-1 rounded-full border border-pu-hairline bg-pu-surface text-sm font-semibold text-pu-primary"
              >
                Cancel
              </button>
            </div>
          </Card>
        ) : (
          <SecondaryButton onClick={() => setConfirming("practice")}>
            <Icon name="Trash2" className="h-4 w-4" strokeWidth={2.4} />
            Delete practice data
          </SecondaryButton>
        )}

        {confirming === "all" ? (
          <Card className="!border-pu-alert/40">
            <p className="text-[15px] font-medium text-pu-primary">
              Delete all data, including your profile and plan? This cannot be
              undone.
            </p>
            <div className="mt-3 flex gap-2.5">
              <button
                type="button"
                onClick={async () => {
                  // Delete the cloud copy first, or the next sync would restore it.
                  if (cloud.user) await cloud.deleteCloudData();
                  deleteEverything();
                  setConfirming(null);
                  navigate("/");
                }}
                className="h-11 flex-1 rounded-full bg-pu-alert text-sm font-bold text-white"
              >
                DELETE ALL
              </button>
              <button
                type="button"
                onClick={() => setConfirming(null)}
                className="h-11 flex-1 rounded-full border border-pu-hairline bg-pu-surface text-sm font-semibold text-pu-primary"
              >
                Cancel
              </button>
            </div>
          </Card>
        ) : (
          <button
            type="button"
            onClick={() => setConfirming("all")}
            className="text-[13px] font-semibold text-pu-alert"
          >
            Delete all data
          </button>
        )}
      </div>

      {settings.developerModeEnabled && (
        <div className="flex flex-col gap-2.5">
          <SectionHeader title="Developer" />
          <Card>
            <div className="flex items-center gap-3">
              <span className="flex-1 text-[15px] font-medium text-pu-primary">
                Pro entitlement
              </span>
              <button
                type="button"
                onClick={() => store.setPro(!store.isPro)}
                className="h-9 rounded-full border border-pu-hairline bg-pu-surface px-3.5 text-[13px] font-semibold text-pu-primary"
              >
                {store.isPro ? "Turn off" : "Turn on"}
              </button>
            </div>
          </Card>
        </div>
      )}
    </Screen>
  );
}

function OptionRow({
  label,
  isSelected,
  onSelect,
}: {
  label: string;
  isSelected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className="flex items-center gap-3 py-1.5 text-left"
    >
      <span
        className={cn(
          "flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded-full border-[1.5px]",
          isSelected ? "border-pu-lime bg-pu-lime" : "border-pu-tertiary/50",
        )}
      >
        {isSelected && (
          <Icon
            name="Check"
            className="h-2.5 w-2.5 text-pu-lime-ink"
            strokeWidth={3.5}
          />
        )}
      </span>
      <span className="text-[15px] font-medium text-pu-primary">{label}</span>
    </button>
  );
}

function ToggleRow({
  label,
  detail,
  isOn,
  onToggle,
}: {
  label: string;
  detail: string;
  isOn: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      role="switch"
      aria-checked={isOn}
      className="pu-card flex items-center gap-3 p-4 text-left"
    >
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="text-[15px] font-medium text-pu-primary">{label}</span>
        <span className="text-[13px] font-medium text-pu-secondary">
          {detail}
        </span>
      </div>
      <span
        className={cn(
          "flex h-[30px] w-[50px] shrink-0 items-center rounded-full p-[3px] transition-colors",
          isOn ? "bg-pu-lime" : "bg-pu-raised",
        )}
      >
        <span
          className={cn(
            "h-6 w-6 rounded-full bg-white transition-transform",
            isOn ? "translate-x-5" : "translate-x-0",
          )}
        />
      </span>
    </button>
  );
}
