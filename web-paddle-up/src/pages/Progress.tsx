/**
 * History and trends: are you actually improving?
 */

import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";

import { Screen, TitleHeader } from "@/components/pu/AppShell";
import { Sparkline, TrendChart } from "@/components/pu/Charts";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  EmptyState,
  IconBadge,
  MicroLabel,
  SectionHeader,
  scoreColor,
} from "@/components/pu/Primitives";
import { drillById } from "@/lib/pu/drills";
import { formatDateTime, formatSigned } from "@/lib/pu/format";
import { mechanicName, rubricFor } from "@/lib/pu/mechanics";
import {
  activeReps,
  averageScore,
  sessionModeName,
  type SessionRecord,
} from "@/lib/pu/profile";
import { groupOf, shotGroupName, type ShotGroup } from "@/lib/pu/shots";
import { cn } from "@/lib/utils";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

export default function Progress() {
  const navigate = useNavigate();
  const {
    completedSessions,
    shotRatings,
    weeklyTrend,
    historyFor,
    improvementFor,
    recurringWeaknesses,
    repsFor,
  } = useAppState();
  const store = useStore();

  const ratedGroups = useMemo<ShotGroup[]>(() => {
    const rated = shotRatings.map((rating) => rating.group);
    return rated.length > 0 ? rated : ["dink"];
  }, [shotRatings]);

  const [selectedGroup, setSelectedGroup] = useState<ShotGroup>(ratedGroups[0]);

  useEffect(() => {
    if (!ratedGroups.includes(selectedGroup)) setSelectedGroup(ratedGroups[0]);
  }, [ratedGroups, selectedGroup]);

  const limit = store.historyLimit();
  const visibleSessions =
    limit === null ? completedSessions : completedSessions.slice(0, limit);

  if (completedSessions.length === 0) {
    return (
      <Screen className="flex flex-col gap-5">
        <TitleHeader title="Progress" />
        <Card className="mt-8">
          <EmptyState
            icon="TrendingUp"
            title="No progress yet"
            message="Finish a practice session and Paddle Up will start tracking every mechanic over time."
          />
        </Card>
      </Screen>
    );
  }

  const trend = weeklyTrend(selectedGroup);
  const selectedRating = shotRatings.find(
    (rating) => rating.group === selectedGroup,
  );
  const primaryShot = repsFor(selectedGroup).slice(-1)[0]?.shot ?? "forehandDink";
  const mechanics = rubricFor(primaryShot).components.map(
    (component) => component.mechanic,
  );

  return (
    <Screen className="flex flex-col gap-4">
      <TitleHeader title="Progress" />

      <div className="-mx-5 flex gap-2 overflow-x-auto px-5 pb-1">
        {ratedGroups.map((group) => (
          <button
            key={group}
            type="button"
            onClick={() => setSelectedGroup(group)}
            className={cn(
              "h-[38px] shrink-0 rounded-full border px-4 text-sm font-semibold transition-colors",
              selectedGroup === group
                ? "border-transparent bg-pu-lime text-pu-lime-ink"
                : "border-pu-hairline bg-pu-surface text-pu-secondary hover:text-pu-primary",
            )}
          >
            {shotGroupName[group]}
          </button>
        ))}
      </div>

      <Card>
        <div className="flex items-center justify-between">
          <MicroLabel>{shotGroupName[selectedGroup]} score trend</MicroLabel>
          {selectedRating && (
            <span
              className="pu-tabular text-xl font-bold"
              style={{ color: scoreColor(selectedRating.score) }}
            >
              {Math.round(selectedRating.score)}
            </span>
          )}
        </div>
        <div className="mt-3">
          {trend.length >= 2 ? (
            <TrendChart points={trend} />
          ) : (
            <p className="py-5 text-[13px] font-medium text-pu-secondary">
              Complete sessions across more than one week to see a trend.
            </p>
          )}
        </div>
      </Card>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Mechanic history" />
        <Card padding="p-3.5">
          {mechanics.map((mechanic) => {
            const history = historyFor(mechanic, selectedGroup);
            const latest = history[history.length - 1];
            if (!latest) return null;
            const delta = improvementFor(mechanic, selectedGroup);
            return (
              <button
                key={mechanic}
                type="button"
                onClick={() => navigate(`/mechanic/${mechanic}/${selectedGroup}`)}
                className="flex w-full items-center gap-3 py-1.5 text-left transition-opacity hover:opacity-80"
              >
                <div className="flex w-32 shrink-0 flex-col gap-0.5">
                  <span className="text-[15px] font-medium text-pu-primary">
                    {mechanicName[mechanic]}
                  </span>
                  {delta !== null && (
                    <span
                      className={cn(
                        "text-[11px] font-medium",
                        delta >= 0 ? "text-pu-lime" : "text-pu-alert",
                      )}
                    >
                      {formatSigned(delta)} this month
                    </span>
                  )}
                </div>
                <Sparkline points={history.slice(-8).map((point) => point.score)} />
                <span className="pu-tabular w-8 shrink-0 text-right text-[15px] font-semibold text-pu-primary">
                  {Math.round(latest.score)}
                </span>
                <Icon
                  name="ChevronRight"
                  className="h-3 w-3 shrink-0 text-pu-tertiary"
                />
              </button>
            );
          })}
        </Card>
      </div>

      {recurringWeaknesses.length > 0 && (
        <div className="flex flex-col gap-2.5">
          <SectionHeader title="Patterns" />
          {recurringWeaknesses.slice(0, 3).map((insight) => {
            const drill = drillById(insight.drillID);
            return (
              <Card key={insight.id}>
                <div className="flex items-start gap-3">
                  <IconBadge
                    icon={insight.trend > 0 ? "ArrowUpRight" : "TriangleAlert"}
                    tint={insight.trend > 0 ? "#C6FF3D" : "#FFB020"}
                  />
                  <div className="flex flex-col gap-2">
                    <p className="text-[15px] font-medium leading-relaxed text-pu-primary">
                      {insight.message}
                    </p>
                    {drill && (
                      <button
                        type="button"
                        onClick={() => navigate(`/drill/${drill.id}`)}
                        className="self-start text-[13px] font-semibold text-pu-lime"
                      >
                        Open {drill.name}
                      </button>
                    )}
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <div className="flex flex-col gap-2.5">
        <SectionHeader
          title="Session history"
          accessory={`${completedSessions.length} total`}
        />
        {visibleSessions.map((session) => (
          <SessionHistoryRow
            key={session.id}
            session={session}
            onOpen={() => navigate(`/session/${session.id}`)}
          />
        ))}

        {limit !== null && completedSessions.length > visibleSessions.length && (
          <button
            type="button"
            onClick={() => navigate("/paywall")}
            className="pu-card flex items-center gap-3 !bg-pu-lime/[0.16] p-4 text-left"
          >
            <Icon name="Lock" className="h-4 w-4 shrink-0 text-pu-lime" />
            <div className="flex flex-col gap-0.5">
              <span className="text-[17px] font-semibold text-pu-primary">
                {completedSessions.length - visibleSessions.length} more sessions
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                Unlock your complete history with Pro
              </span>
            </div>
          </button>
        )}
      </div>
    </Screen>
  );
}

export function SessionHistoryRow({
  session,
  onOpen,
}: {
  session: SessionRecord;
  onOpen: () => void;
}) {
  const average = averageScore(session);
  return (
    <button
      type="button"
      onClick={onOpen}
      className="pu-tile flex items-center gap-3.5 p-3.5 text-left transition-colors hover:bg-pu-raised/60"
    >
      <div className="flex w-11 shrink-0 flex-col items-center">
        <span
          className="pu-tabular text-[19px] font-bold"
          style={{ color: scoreColor(average ?? 0) }}
        >
          {average === null ? "—" : Math.round(average)}
        </span>
        <span className="text-[9px] text-pu-tertiary">avg</span>
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
        <span className="text-[17px] font-semibold text-pu-primary">
          {shotGroupName[groupOf(session.shot)]} {sessionModeName[session.mode]}
        </span>
        <span className="text-[13px] font-medium text-pu-secondary">
          {formatDateTime(session.startedAt)} · {activeReps(session).length} reps
        </span>
      </div>
      <Icon name="ChevronRight" className="h-3.5 w-3.5 shrink-0 text-pu-tertiary" />
    </button>
  );
}
