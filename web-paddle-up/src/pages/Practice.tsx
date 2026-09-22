/**
 * Shot selection → drill selection → session length, then into camera setup.
 */

import { useNavigate } from "react-router-dom";

import { Screen, TitleHeader } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  AnalyzerBadge,
  Card,
  DrillThumbnail,
  FlowChips,
  IconBadge,
  MicroLabel,
  PrimaryButton,
  SectionHeader,
  scoreColor,
} from "@/components/pu/Primitives";
import { drillPrescription } from "@/lib/pu/drills";
import { mechanicName } from "@/lib/pu/mechanics";
import {
  analyzerStatusOf,
  groupOf,
  practiceableShots,
  shotGroupIcon,
  shotName,
  shotSummary,
  shotTypes,
  type ShotGroup,
  type ShotType,
} from "@/lib/pu/shots";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

export default function Practice() {
  const navigate = useNavigate();
  const { profile, recommendedDrill, weeklyPlan, shotRatings, completedSessionCount, settings } =
    useAppState();
  const store = useStore();

  const ratingFor = (group: ShotGroup): number | undefined =>
    shotRatings.find((rating) => rating.group === group)?.score;

  const start = (shot: ShotType, mode: string, drillID?: string) => {
    if (!store.canStart(completedSessionCount)) {
      navigate("/paywall");
      return;
    }
    const params = new URLSearchParams({
      shot,
      mode,
      length: settings.defaultSessionLength,
    });
    if (drillID) params.set("drill", drillID);
    navigate(`/live?${params.toString()}`);
  };

  const plannedShots = shotTypes.filter(
    (shot) => analyzerStatusOf(shot) === "planned",
  );

  return (
    <Screen className="flex flex-col gap-5">
      <TitleHeader
        title="Practice"
        subtitle="Pick a shot, pick a drill, prop your device up. Paddle Up counts and scores every rep automatically."
      />

      {!profile.hasCompletedBaselineAssessment && (
        <Card className="!bg-pu-lime/[0.16]">
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-3">
              <IconBadge icon="Activity" />
              <div className="flex flex-col gap-[3px]">
                <MicroLabel>Start here</MicroLabel>
                <span className="text-lg font-bold text-pu-primary">
                  Baseline Dink Assessment
                </span>
              </div>
            </div>
            <p className="text-[13px] font-medium leading-relaxed text-pu-secondary">
              20–30 dinks so Paddle Up can measure your starting point and find
              your weakest mechanic.
            </p>
            <PrimaryButton
              onClick={() => start("forehandDink", "assessment")}
            >
              START ASSESSMENT
            </PrimaryButton>
          </div>
        </Card>
      )}

      <div className="flex flex-col gap-2.5">
        <SectionHeader
          title="Choose a shot"
          accessory={`${practiceableShots.length} available`}
        />
        {practiceableShots.map((shot) => {
          const rating = ratingFor(groupOf(shot));
          return (
            <button
              key={shot}
              type="button"
              onClick={() => navigate(`/shot/${shot}`)}
              className="pu-tile flex items-center gap-3.5 p-3.5 text-left transition-colors hover:bg-pu-raised/60"
            >
              <IconBadge icon={shotGroupIcon[groupOf(shot)]} size={42} />
              <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
                <div className="flex items-center gap-2">
                  <span className="text-[17px] font-semibold text-pu-primary">
                    {shotName[shot]}
                  </span>
                  <AnalyzerBadge status={analyzerStatusOf(shot)} />
                </div>
                <span className="truncate text-[13px] font-medium text-pu-secondary">
                  {shotSummary[shot]}
                </span>
              </div>
              {rating !== undefined && (
                <span
                  className="pu-tabular shrink-0 text-xl font-bold"
                  style={{ color: scoreColor(rating) }}
                >
                  {Math.round(rating)}
                </span>
              )}
              <Icon
                name="ChevronRight"
                className="h-3.5 w-3.5 shrink-0 text-pu-tertiary"
              />
            </button>
          );
        })}

        <div className="mt-2 flex flex-col gap-2">
          <MicroLabel>Analyzers in development</MicroLabel>
          <FlowChips items={plannedShots.map((shot) => shotName[shot])} />
          <p className="text-xs leading-relaxed text-pu-tertiary">
            These shots already have rubrics and progress tracking. Their live
            analyzers land after Dink is fully tuned.
          </p>
        </div>
      </div>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Prescribed for you" />
        {recommendedDrill && (
          <button
            type="button"
            onClick={() => navigate(`/drill/${recommendedDrill.id}`)}
            className="pu-card flex items-center gap-3.5 p-4 text-left transition-colors hover:bg-pu-raised/60"
          >
            <DrillThumbnail />
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <span className="text-[17px] font-semibold leading-snug text-pu-primary">
                {recommendedDrill.name}
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                Targets {mechanicName[recommendedDrill.targetMechanic]} ·{" "}
                {drillPrescription(recommendedDrill)}
              </span>
            </div>
            <Icon name="ChevronRight" className="h-3.5 w-3.5 shrink-0 text-pu-tertiary" />
          </button>
        )}

        <button
          type="button"
          onClick={() => navigate("/plan")}
          className="pu-card flex items-center gap-3.5 p-4 text-left transition-colors hover:bg-pu-raised/60"
        >
          <IconBadge icon="Calendar" />
          <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
            <span className="text-[17px] font-semibold text-pu-primary">
              Weekly practice plan
            </span>
            <span className="text-[13px] font-medium text-pu-secondary">
              {weeklyPlan
                ? `${weeklyPlan.entries.length} sessions this week`
                : "Generate a plan from your weaknesses"}
            </span>
          </div>
          <Icon name="ChevronRight" className="h-3.5 w-3.5 shrink-0 text-pu-tertiary" />
        </button>
      </div>
    </Screen>
  );
}
