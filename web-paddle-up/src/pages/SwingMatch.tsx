/**
 * Swing Match: compares the player's measured mechanics against anonymised
 * elite archetypes. References are never real professional names or likenesses.
 */

import { useMemo } from "react";
import { useNavigate } from "react-router-dom";

import { Screen } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  EmptyState,
  IconBadge,
  MicroLabel,
  PrimaryButton,
  ScoreBar,
  SectionHeader,
} from "@/components/pu/Primitives";
import { mechanicName, rubricFor, type MechanicID } from "@/lib/pu/mechanics";
import { mechanicOf } from "@/lib/pu/profile";
import { shotGroupName } from "@/lib/pu/shots";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

/** Anonymised reference archetypes — never real players. */
const references: {
  id: string;
  name: string;
  detail: string;
  targets: Partial<Record<MechanicID, number>>;
}[] = [
  {
    id: "elite_a",
    name: "Elite Reference A",
    detail: "Kitchen-dominant soft game",
    targets: {
      kneeBend: 92,
      contactPosition: 94,
      armStructure: 90,
      headStability: 95,
      followThrough: 88,
    },
  },
  {
    id: "coach",
    name: "Coach Reference",
    detail: "Textbook teaching mechanics",
    targets: {
      kneeBend: 88,
      contactPosition: 90,
      armStructure: 92,
      headStability: 90,
      followThrough: 90,
    },
  },
];

export default function SwingMatch() {
  const navigate = useNavigate();
  const { strongestShot, repsFor } = useAppState();
  const store = useStore();

  const group = strongestShot?.group ?? "dink";
  const reps = repsFor(group);

  /** Average each measured mechanic across the player's reps for this group. */
  const playerAverages = useMemo(() => {
    const shot = reps.slice(-1)[0]?.shot ?? "forehandDink";
    const mechanics = rubricFor(shot)
      .components.filter((component) => component.isMeasured)
      .map((component) => component.mechanic);

    const result: { mechanic: MechanicID; score: number }[] = [];
    for (const mechanic of mechanics) {
      const scores = reps
        .map((rep) => mechanicOf(rep, mechanic)?.score)
        .filter((score): score is number => score !== undefined);
      if (scores.length === 0) continue;
      result.push({
        mechanic,
        score: scores.reduce((sum, value) => sum + value, 0) / scores.length,
      });
    }
    return result;
  }, [reps]);

  if (store.isLocked("swingMatch")) {
    return (
      <Screen className="flex flex-col gap-4">
        <BackHeader title="Swing Match" onBack={() => navigate(-1)} />
        <Card className="!bg-pu-lime/[0.16]">
          <div className="flex items-start gap-3">
            <IconBadge icon="Lock" tint="#FFB020" />
            <div className="flex flex-col gap-1">
              <MicroLabel>Pro feature</MicroLabel>
              <p className="text-[15px] font-medium leading-relaxed text-pu-primary">
                Swing Match compares every measured mechanic against elite
                reference archetypes, so you can see exactly where your shape
                differs.
              </p>
            </div>
          </div>
        </Card>
        <PrimaryButton onClick={() => navigate("/paywall")}>
          UNLOCK WITH PRO
        </PrimaryButton>
      </Screen>
    );
  }

  if (playerAverages.length === 0) {
    return (
      <Screen className="flex flex-col gap-4">
        <BackHeader title="Swing Match" onBack={() => navigate(-1)} />
        <Card>
          <EmptyState
            icon="Users"
            title="Not enough data yet"
            message="Complete a session so Paddle Up has mechanics to compare against the references."
          />
        </Card>
      </Screen>
    );
  }

  return (
    <Screen className="flex flex-col gap-4">
      <BackHeader title="Swing Match" onBack={() => navigate(-1)} />

      <p className="text-[15px] font-medium leading-relaxed text-pu-secondary">
        Your {shotGroupName[group].toLowerCase()} mechanics measured against
        anonymised reference archetypes.
      </p>

      {references.map((reference) => {
        const rows = playerAverages
          .map((entry) => ({
            ...entry,
            target: reference.targets[entry.mechanic],
          }))
          .filter(
            (row): row is { mechanic: MechanicID; score: number; target: number } =>
              row.target !== undefined,
          );
        if (rows.length === 0) return null;

        const closeness =
          100 -
          rows.reduce((sum, row) => sum + Math.abs(row.target - row.score), 0) /
            rows.length;

        return (
          <div key={reference.id} className="flex flex-col gap-2.5">
            <SectionHeader
              title={reference.name}
              accessory={`${Math.max(0, Math.round(closeness))}% match`}
            />
            <Card padding="p-3.5">
              <p className="mb-2 text-[13px] font-medium text-pu-secondary">
                {reference.detail}
              </p>
              {rows.map((row) => (
                <div key={row.mechanic} className="flex flex-col gap-1.5 py-2">
                  <div className="flex items-center justify-between">
                    <span className="text-[15px] font-medium text-pu-primary">
                      {mechanicName[row.mechanic]}
                    </span>
                    <span className="pu-tabular text-[13px] font-semibold text-pu-secondary">
                      you {Math.round(row.score)} · ref {row.target}
                    </span>
                  </div>
                  <ScoreBar value={row.score} />
                </div>
              ))}
            </Card>
          </div>
        );
      })}

      <p className="text-[11px] leading-relaxed text-pu-tertiary">
        References are anonymised archetypes built from coaching heuristics, not
        real professional players.
      </p>
    </Screen>
  );
}

function BackHeader({ title, onBack }: { title: string; onBack: () => void }) {
  return (
    <div className="flex items-center gap-3 pt-1">
      <button
        type="button"
        onClick={onBack}
        aria-label="Back"
        className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-pu-hairline bg-pu-surface text-pu-secondary transition-transform active:scale-95"
      >
        <Icon name="ChevronLeft" className="h-4 w-4" strokeWidth={2.6} />
      </button>
      <h1 className="text-xl font-bold text-pu-primary">{title}</h1>
    </div>
  );
}
