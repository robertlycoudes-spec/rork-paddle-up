/** Drill detail with instructions and a bottom START action. */

import { useNavigate, useParams } from "react-router-dom";

import { Screen } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  DrillThumbnail,
  EmptyState,
  MicroLabel,
  PrimaryButton,
  SectionHeader,
} from "@/components/pu/Primitives";
import { drillById, drillPrescription, drillTargetReps } from "@/lib/pu/drills";
import { mechanicName } from "@/lib/pu/mechanics";
import { sessionLengths, type SessionLength } from "@/lib/pu/persistence";
import { shotName } from "@/lib/pu/shots";
import { cn } from "@/lib/utils";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";
import { useState } from "react";

export default function DrillDetail() {
  const { drillID } = useParams<{ drillID: string }>();
  const navigate = useNavigate();
  const { settings, completedSessionCount } = useAppState();
  const store = useStore();
  const [length, setLength] = useState<SessionLength>(
    settings.defaultSessionLength,
  );

  const drill = drillById(drillID);

  if (!drill) {
    return (
      <Screen>
        <Card className="mt-10">
          <EmptyState
            icon="SearchX"
            title="Drill not found"
            message="This drill is no longer in the library."
          />
        </Card>
      </Screen>
    );
  }

  const start = () => {
    if (!store.canStart(completedSessionCount)) {
      navigate("/paywall");
      return;
    }
    const params = new URLSearchParams({
      shot: drill.shot,
      mode: "drill",
      drill: drill.id,
      length,
    });
    navigate(`/live?${params.toString()}`);
  };

  return (
    <>
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
          <h1 className="text-xl font-bold text-pu-primary">Drill</h1>
        </div>

        <Card>
          <div className="flex items-start gap-3.5">
            <DrillThumbnail />
            <div className="flex min-w-0 flex-col gap-1">
              <span className="text-[22px] font-bold leading-tight text-pu-primary">
                {drill.name}
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                {shotName[drill.shot]} · Targets{" "}
                {mechanicName[drill.targetMechanic]}
              </span>
            </div>
          </div>

          <div className="mt-4 flex items-stretch">
            <SummaryCell label="Prescription" value={drillPrescription(drill)} />
            <div className="w-px bg-pu-hairline" />
            <SummaryCell label="Total reps" value={String(drillTargetReps(drill))} />
            <div className="w-px bg-pu-hairline" />
            <SummaryCell label="Time" value={`${drill.estimatedMinutes} min`} />
          </div>
        </Card>

        <Card>
          <MicroLabel>The goal</MicroLabel>
          <p className="mt-2 text-[15px] font-medium leading-relaxed text-pu-primary">
            {drill.goal}
          </p>
        </Card>

        <div className="flex flex-col gap-2.5">
          <SectionHeader title="How to run it" />
          <Card>
            <ol className="flex flex-col gap-3">
              {drill.instructions.map((instruction, index) => (
                <li key={instruction} className="flex items-start gap-3">
                  <span className="pu-tabular mt-0.5 flex h-[22px] w-[22px] shrink-0 items-center justify-center rounded-full bg-pu-lime/[0.14] text-[11px] font-bold text-pu-lime">
                    {index + 1}
                  </span>
                  <span className="text-[15px] font-medium leading-relaxed text-pu-primary">
                    {instruction}
                  </span>
                </li>
              ))}
            </ol>
          </Card>
        </div>

        <Card className="!bg-pu-lime/[0.16]">
          <MicroLabel>Focus cue</MicroLabel>
          <p className="mt-1 text-[19px] font-bold text-pu-lime">
            {drill.focusCue}
          </p>
          <p className="mt-2 text-[13px] font-medium leading-relaxed text-pu-secondary">
            {drill.successCriteria}
          </p>
        </Card>

        <div className="flex flex-col gap-2.5">
          <SectionHeader title="Session length" />
          <div className="flex flex-wrap gap-2">
            {sessionLengths.map((option) => (
              <button
                key={option.id}
                type="button"
                onClick={() => setLength(option.id)}
                className={cn(
                  "h-[38px] rounded-full border px-4 text-sm font-semibold transition-colors",
                  length === option.id
                    ? "border-transparent bg-pu-lime text-pu-lime-ink"
                    : "border-pu-hairline bg-pu-surface text-pu-secondary hover:text-pu-primary",
                )}
              >
                {option.displayName}
              </button>
            ))}
          </div>
        </div>
      </Screen>

      <div className="pu-action-bar fixed inset-x-0 bottom-[68px] px-5 pb-3 pt-2.5 lg:sticky lg:bottom-4">
        <div className="mx-auto w-full max-w-xl">
          <PrimaryButton onClick={start}>
            <Icon name="Play" className="h-4 w-4" strokeWidth={3} />
            START DRILL
          </PrimaryButton>
        </div>
      </div>
    </>
  );
}

function SummaryCell({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-1 flex-col items-center gap-1 text-center">
      <MicroLabel>{label}</MicroLabel>
      <span className="text-[15px] font-semibold text-pu-primary">{value}</span>
    </div>
  );
}
