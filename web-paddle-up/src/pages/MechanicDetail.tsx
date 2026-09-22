/**
 * Mechanic detail: what it measures, the benchmark band, the trend over time,
 * and the drill that moves it.
 */

import { useNavigate, useParams } from "react-router-dom";

import { Screen } from "@/components/pu/AppShell";
import { TrendChart, type TrendPoint } from "@/components/pu/Charts";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  DrillThumbnail,
  EmptyState,
  MicroLabel,
  SectionHeader,
  scoreColor,
} from "@/components/pu/Primitives";
import { drillForMechanic, drillPrescription } from "@/lib/pu/drills";
import { formatDate, formatSigned } from "@/lib/pu/format";
import {
  allMechanics,
  benchmarkRange,
  mechanicCue,
  mechanicName,
  type MechanicID,
} from "@/lib/pu/mechanics";
import { coachingIssues } from "@/lib/pu/coaching-knowledge";
import { shotGroupName, shotGroups, type ShotGroup } from "@/lib/pu/shots";
import { cn } from "@/lib/utils";
import { useAppState } from "@/state/AppStateProvider";

export default function MechanicDetail() {
  const { mechanic: mechanicParam, group: groupParam } = useParams<{
    mechanic: string;
    group: string;
  }>();
  const navigate = useNavigate();
  const { historyFor, improvementFor, repsFor } = useAppState();

  const mechanic = allMechanics.find((item) => item === mechanicParam) as
    | MechanicID
    | undefined;
  const group = shotGroups.find((item) => item === groupParam) as
    | ShotGroup
    | undefined;

  if (!mechanic || !group) {
    return (
      <Screen>
        <Card className="mt-10">
          <EmptyState
            icon="SearchX"
            title="Mechanic not found"
            message="This mechanic isn't part of the Paddle Up rubric."
          />
        </Card>
      </Screen>
    );
  }

  const history = historyFor(mechanic, group);
  const delta = improvementFor(mechanic, group);
  const latest = history[history.length - 1];
  const shot = repsFor(group).slice(-1)[0]?.shot ?? "forehandDink";
  const range = benchmarkRange(shot, mechanic);
  const drill = drillForMechanic(mechanic, shot);
  const issues = coachingIssues.filter((issue) => issue.mechanic === mechanic);

  const points: TrendPoint[] = history.slice(-8).map((point) => ({
    label: formatDate(point.date),
    score: point.score,
  }));

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
        <h1 className="text-xl font-bold text-pu-primary">
          {mechanicName[mechanic]}
        </h1>
      </div>

      <Card>
        <MicroLabel>{shotGroupName[group]} · current</MicroLabel>
        <div className="mt-1 flex items-end gap-3">
          <span
            className="pu-tabular text-[56px] font-black leading-none"
            style={{ color: scoreColor(latest?.score ?? 0) }}
          >
            {latest ? Math.round(latest.score) : "—"}
          </span>
          {delta !== null && (
            <span
              className={cn(
                "mb-2 text-[15px] font-semibold",
                delta >= 0 ? "text-pu-lime" : "text-pu-alert",
              )}
            >
              {formatSigned(delta)} this month
            </span>
          )}
        </div>
        <div className="mt-3 rounded-xl bg-pu-lime/[0.12] p-3">
          <MicroLabel>Cue</MicroLabel>
          <p className="mt-0.5 text-base font-black tracking-[0.03em] text-pu-lime">
            {mechanicCue[mechanic]}
          </p>
        </div>
      </Card>

      {points.length >= 2 && (
        <Card>
          <SectionHeader title="History" />
          <div className="mt-3">
            <TrendChart points={points} />
          </div>
        </Card>
      )}

      {range && (
        <Card>
          <MicroLabel>Benchmark range</MicroLabel>
          <div className="mt-2 flex flex-col gap-2">
            <div className="flex items-center justify-between text-[15px] font-medium">
              <span className="text-pu-secondary">Ideal</span>
              <span className="pu-tabular text-pu-lime">
                {range.idealLow}–{range.idealHigh} {range.unit}
              </span>
            </div>
            <div className="h-px w-full bg-pu-hairline" />
            <div className="flex items-center justify-between text-[15px] font-medium">
              <span className="text-pu-secondary">Acceptable</span>
              <span className="pu-tabular text-pu-primary">
                {range.acceptableLow}–{range.acceptableHigh} {range.unit}
              </span>
            </div>
          </div>
          <p className="mt-3 text-[11px] leading-relaxed text-pu-tertiary">
            Coaching heuristic, not validated sports science.
          </p>
        </Card>
      )}

      {issues.length > 0 && (
        <div className="flex flex-col gap-2.5">
          <SectionHeader title="What can go wrong" />
          {issues.map((issue) => (
            <Card key={issue.id}>
              <span className="text-[17px] font-semibold text-pu-primary">
                {issue.title}
              </span>
              <p className="mt-1.5 text-[13px] font-medium leading-relaxed text-pu-secondary">
                {issue.explanation}
              </p>
              <p className="mt-2 text-[15px] font-medium leading-relaxed text-pu-primary">
                {issue.correction}
              </p>
            </Card>
          ))}
        </div>
      )}

      {drill && (
        <div className="flex flex-col gap-2.5">
          <SectionHeader title="Drill that moves it" />
          <button
            type="button"
            onClick={() => navigate(`/drill/${drill.id}`)}
            className="pu-card flex items-center gap-3.5 p-4 text-left transition-colors hover:bg-pu-raised/60"
          >
            <DrillThumbnail />
            <div className="flex min-w-0 flex-1 flex-col gap-0.5">
              <span className="text-[17px] font-semibold text-pu-primary">
                {drill.name}
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                {drillPrescription(drill)}
              </span>
            </div>
            <Icon
              name="ChevronRight"
              className="h-3.5 w-3.5 shrink-0 text-pu-tertiary"
            />
          </button>
        </div>
      )}
    </Screen>
  );
}
