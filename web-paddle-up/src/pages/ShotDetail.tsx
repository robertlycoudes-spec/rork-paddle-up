/**
 * Shot detail: the rubric behind the score, the drills that train it, and a
 * start action. Also serves the per-group view opened from the skill card.
 */

import { useNavigate, useParams } from "react-router-dom";

import { Screen } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  AnalyzerBadge,
  Card,
  DrillThumbnail,
  EmptyState,
  IconBadge,
  MicroLabel,
  PrimaryButton,
  ScoreBar,
  SectionHeader,
} from "@/components/pu/Primitives";
import { drillPrescription, drillsForShot } from "@/lib/pu/drills";
import { benchmarkRange, mechanicName, rubricFor } from "@/lib/pu/mechanics";
import {
  analyzerStatusOf,
  groupOf,
  shotGroupIcon,
  shotGroupName,
  shotName,
  shotSummary,
  shotTypes,
  type ShotGroup,
  type ShotType,
} from "@/lib/pu/shots";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

export default function ShotDetail() {
  const { shot: shotParam, group: groupParam } = useParams<{
    shot?: string;
    group?: string;
  }>();
  const navigate = useNavigate();
  const { shotRatings, repsFor, settings, completedSessionCount } = useAppState();
  const store = useStore();

  // The route either names a specific shot or a rating group.
  const shot: ShotType | undefined = shotParam
    ? (shotTypes.find((item) => item === shotParam) as ShotType | undefined)
    : groupParam
      ? (shotTypes.find(
          (item) => groupOf(item) === (groupParam as ShotGroup),
        ) as ShotType | undefined)
      : undefined;

  if (!shot) {
    return (
      <Screen>
        <Card className="mt-10">
          <EmptyState
            icon="SearchX"
            title="Shot not found"
            message="This shot isn't part of the Paddle Up taxonomy."
          />
        </Card>
      </Screen>
    );
  }

  const group = groupOf(shot);
  const rating = shotRatings.find((item) => item.group === group);
  const reps = repsFor(group);
  const rubric = rubricFor(shot);
  const drills = drillsForShot(shot);

  const start = () => {
    if (!store.canStart(completedSessionCount)) {
      navigate("/paywall");
      return;
    }
    const params = new URLSearchParams({
      shot,
      mode: "freePractice",
      length: settings.defaultSessionLength,
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
          <h1 className="text-xl font-bold text-pu-primary">
            {shotGroupName[group]}
          </h1>
        </div>

        <Card>
          <div className="flex items-start gap-3.5">
            <IconBadge icon={shotGroupIcon[group]} size={48} />
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-[22px] font-bold text-pu-primary">
                  {shotName[shot]}
                </span>
                <AnalyzerBadge status={analyzerStatusOf(shot)} />
              </div>
              <span className="text-[13px] font-medium leading-relaxed text-pu-secondary">
                {shotSummary[shot]}
              </span>
            </div>
          </div>

          {rating && (
            <div className="mt-4 flex items-center gap-3">
              <span className="pu-tabular text-[44px] font-black leading-none text-pu-primary">
                {Math.round(rating.score)}
              </span>
              <div className="flex flex-1 flex-col gap-1.5">
                <MicroLabel>{reps.length} reps measured</MicroLabel>
                <ScoreBar value={rating.score} />
              </div>
            </div>
          )}
        </Card>

        <div className="flex flex-col gap-2.5">
          <SectionHeader title="How this shot is scored" />
          <Card padding="p-3.5">
            {rubric.components.map((component) => {
              const range = benchmarkRange(shot, component.mechanic);
              return (
                <div
                  key={component.mechanic}
                  className="flex items-center gap-3 py-2"
                >
                  <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span className="text-[15px] font-medium text-pu-primary">
                      {mechanicName[component.mechanic]}
                    </span>
                    <span className="text-[11px] text-pu-tertiary">
                      {component.isMeasured
                        ? range
                          ? `Ideal ${range.idealLow}–${range.idealHigh}${range.unit}`
                          : "Measured from pose"
                        : "Defined — analyzer in development"}
                    </span>
                  </div>
                  <span className="pu-tabular shrink-0 text-[15px] font-semibold text-pu-primary">
                    {Math.round(component.weight * 100)}%
                  </span>
                </div>
              );
            })}
          </Card>
          <p className="text-[11px] leading-relaxed text-pu-tertiary">
            Benchmark ranges are coaching heuristics, not validated sports
            science.
          </p>
        </div>

        <div className="flex flex-col gap-2.5">
          <SectionHeader title="Drills for this shot" />
          {drills.map((drill) => (
            <button
              key={drill.id}
              type="button"
              onClick={() => navigate(`/drill/${drill.id}`)}
              className="pu-tile flex items-center gap-3.5 p-3.5 text-left transition-colors hover:bg-pu-raised/60"
            >
              <DrillThumbnail />
              <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                <span className="text-[17px] font-semibold leading-snug text-pu-primary">
                  {drill.name}
                </span>
                <span className="text-[13px] font-medium text-pu-secondary">
                  {mechanicName[drill.targetMechanic]} ·{" "}
                  {drillPrescription(drill)}
                </span>
              </div>
              <Icon
                name="ChevronRight"
                className="h-3.5 w-3.5 shrink-0 text-pu-tertiary"
              />
            </button>
          ))}
        </div>
      </Screen>

      <div className="pu-action-bar fixed inset-x-0 bottom-[68px] px-5 pb-3 pt-2.5 lg:sticky lg:bottom-4">
        <div className="mx-auto w-full max-w-xl">
          <PrimaryButton onClick={start}>
            <Icon name="Play" className="h-4 w-4" strokeWidth={3} />
            PRACTISE {shotName[shot].toUpperCase()}
          </PrimaryButton>
        </div>
      </div>
    </>
  );
}
