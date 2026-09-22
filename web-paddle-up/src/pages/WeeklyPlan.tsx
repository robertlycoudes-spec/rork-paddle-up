/**
 * The personalised weekly plan: one session per slot, ending in an assessment
 * so improvement can actually be measured.
 */

import { useNavigate } from "react-router-dom";

import { Screen } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  EmptyState,
  IconBadge,
  MicroLabel,
  PrimaryButton,
  SecondaryButton,
  SectionHeader,
} from "@/components/pu/Primitives";
import { drillById } from "@/lib/pu/drills";
import { weekdayNames } from "@/lib/pu/game-plan";
import { mechanicName } from "@/lib/pu/mechanics";
import { shotName } from "@/lib/pu/shots";
import { cn } from "@/lib/utils";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

export default function WeeklyPlan() {
  const navigate = useNavigate();
  const {
    weeklyPlan,
    regeneratePlan,
    markPlanEntryComplete,
    settings,
    completedSessionCount,
  } = useAppState();
  const store = useStore();

  const start = (shot: string, drillID: string, isAssessment: boolean) => {
    if (!store.canStart(completedSessionCount)) {
      navigate("/paywall");
      return;
    }
    const params = new URLSearchParams({
      shot,
      mode: isAssessment ? "assessment" : "drill",
      drill: drillID,
      length: settings.defaultSessionLength,
    });
    navigate(`/live?${params.toString()}`);
  };

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
        <h1 className="text-xl font-bold text-pu-primary">Weekly plan</h1>
      </div>

      {!weeklyPlan ? (
        <Card>
          <EmptyState
            icon="Calendar"
            title="No plan yet"
            message="Generate a plan built from your weaknesses and a closing assessment."
          />
          <PrimaryButton onClick={regeneratePlan}>GENERATE PLAN</PrimaryButton>
        </Card>
      ) : (
        <>
          <Card className="!bg-pu-lime/[0.16]">
            <div className="flex items-start gap-3">
              <IconBadge icon="Sparkles" />
              <div className="flex flex-col gap-1">
                <MicroLabel>Why this week</MicroLabel>
                <p className="text-[15px] font-medium leading-relaxed text-pu-primary">
                  {weeklyPlan.rationale}
                </p>
              </div>
            </div>
          </Card>

          <div className="flex flex-col gap-2.5">
            <SectionHeader
              title="This week"
              accessory={`${weeklyPlan.entries.length} sessions`}
            />
            {weeklyPlan.entries.map((entry) => {
              const drill = drillById(entry.drillID);
              const isDone = entry.completedAt !== undefined;
              return (
                <div
                  key={entry.id}
                  className={cn(
                    "pu-tile flex items-center gap-3.5 p-3.5",
                    isDone && "opacity-60",
                  )}
                >
                  <div className="flex w-11 shrink-0 flex-col items-center">
                    <span className="text-[11px] font-bold uppercase tracking-[0.08em] text-pu-tertiary">
                      {weekdayNames[entry.weekday - 1]?.slice(0, 3)}
                    </span>
                    {entry.isAssessment && (
                      <Icon
                        name="ClipboardCheck"
                        className="mt-1 h-3.5 w-3.5 text-pu-amber"
                      />
                    )}
                  </div>

                  <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
                    <span className="text-[17px] font-semibold leading-snug text-pu-primary">
                      {entry.isAssessment
                        ? "Assessment"
                        : (drill?.name ?? shotName[entry.shot])}
                    </span>
                    <span className="text-[13px] font-medium text-pu-secondary">
                      {shotName[entry.shot]} · {mechanicName[entry.mechanic]}
                    </span>
                  </div>

                  {isDone ? (
                    <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-pu-lime">
                      <Icon
                        name="Check"
                        className="h-4 w-4 text-pu-lime-ink"
                        strokeWidth={3}
                      />
                    </span>
                  ) : (
                    <button
                      type="button"
                      onClick={() => {
                        markPlanEntryComplete(entry.id);
                        start(entry.shot, entry.drillID, entry.isAssessment);
                      }}
                      className="flex h-9 shrink-0 items-center gap-1.5 rounded-full bg-pu-lime px-3.5 text-[13px] font-bold text-pu-lime-ink transition-transform active:scale-95"
                    >
                      <Icon name="Play" className="h-3 w-3" strokeWidth={3} />
                      START
                    </button>
                  )}
                </div>
              );
            })}
          </div>

          <SecondaryButton onClick={regeneratePlan}>
            <Icon name="RefreshCw" className="h-4 w-4" strokeWidth={2.4} />
            Rebuild from my latest data
          </SecondaryButton>
        </>
      )}
    </Screen>
  );
}
