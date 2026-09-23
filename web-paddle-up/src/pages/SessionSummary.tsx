/**
 * Post-session review: headline stats, mechanics breakdown, the single biggest
 * focus, and the drill prescribed to fix it.
 */

import { useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";

import { Screen } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  DrillThumbnail,
  EmptyState,
  IconBadge,
  MechanicRow,
  MicroLabel,
  PrimaryButton,
  SectionHeader,
  StatStrip,
  scoreColor,
} from "@/components/pu/Primitives";
import { BallPaddleData } from "@/components/pu/BallPaddleData";
import { CalloutTile } from "@/pages/Profile";
import { sessionFocus } from "@/lib/pu/coaching";
import { drillById, drillForMechanic, drillPrescription } from "@/lib/pu/drills";
import { formatClock } from "@/lib/pu/format";
import { mechanicName, type MechanicID } from "@/lib/pu/mechanics";
import {
  activeReps,
  averageScore,
  bestScore,
  consistency,
  mechanicAverages,
  orderedMechanicAverages,
  sessionDuration,
  sessionModeName,
  weakestMechanic,
  worstScore,
  type RepRecord,
} from "@/lib/pu/profile";
import { groupOf, shotGroupIcon, shotGroupName } from "@/lib/pu/shots";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

export default function SessionSummary() {
  const { sessionID } = useParams<{ sessionID: string }>();
  const navigate = useNavigate();
  const { sessionById, completedSessions, completedSessionCount, settings } =
    useAppState();
  const store = useStore();

  const session = sessionID ? sessionById(sessionID) : undefined;

  const focus = useMemo(() => (session ? sessionFocus(session) : null), [session]);

  const recommendedDrill = useMemo(() => {
    if (!session) return undefined;
    const fromFocus = drillById(focus?.drillID);
    if (fromFocus) return fromFocus;
    const weakest = weakestMechanic(session);
    return weakest ? drillForMechanic(weakest.mechanic, session.shot) : undefined;
  }, [session, focus]);

  /** Compares this session's mechanics against the previous same-group one. */
  const bestImprovement = useMemo(() => {
    if (!session) return null;
    const previous = completedSessions
      .filter(
        (item) =>
          item.id !== session.id &&
          groupOf(item.shot) === groupOf(session.shot) &&
          item.startedAt < session.startedAt,
      )
      .sort((a, b) => b.startedAt - a.startedAt)[0];
    if (!previous) return null;

    const previousAverages = mechanicAverages(previous);
    const currentAverages = mechanicAverages(session);
    let best: { mechanic: MechanicID; delta: number } | null = null;
    for (const key of Object.keys(currentAverages) as MechanicID[]) {
      const before = previousAverages[key];
      const after = currentAverages[key];
      if (before === undefined || after === undefined) continue;
      const delta = after - before;
      if (delta > 0.5 && (!best || delta > best.delta)) {
        best = { mechanic: key, delta };
      }
    }
    return best;
  }, [session, completedSessions]);

  if (!session) {
    return (
      <Screen>
        <Card className="mt-10">
          <EmptyState
            icon="SearchX"
            title="Session not found"
            message="This session is no longer available."
          />
        </Card>
      </Screen>
    );
  }

  const reps = activeReps(session);
  const startDrill = () => {
    if (!recommendedDrill) return;
    if (!store.canStart(completedSessionCount)) {
      navigate("/paywall");
      return;
    }
    const params = new URLSearchParams({
      shot: recommendedDrill.shot,
      mode: "drill",
      drill: recommendedDrill.id,
      length: settings.defaultSessionLength,
    });
    navigate(`/live?${params.toString()}`);
  };

  return (
    <>
      <Screen className="flex flex-col gap-3.5">
        <div className="flex items-center gap-3 pt-1">
          <button
            type="button"
            onClick={() => navigate("/progress")}
            aria-label="Back"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-pu-hairline bg-pu-surface text-pu-secondary transition-transform active:scale-95"
          >
            <Icon name="ChevronLeft" className="h-4 w-4" strokeWidth={2.6} />
          </button>
          <h1 className="text-xl font-bold text-pu-primary">Session Summary</h1>
        </div>

        <Card>
          <div className="flex items-center gap-3.5">
            <IconBadge icon={shotGroupIcon[groupOf(session.shot)]} size={48} />
            <div className="flex min-w-0 flex-col gap-[3px]">
              <span className="text-[21px] font-bold text-pu-primary">
                {shotGroupName[groupOf(session.shot)]}{" "}
                {sessionModeName[session.mode]}
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                Duration {formatClock(sessionDuration(session))} · {reps.length} reps
              </span>
            </div>
          </div>
        </Card>

        <StatStrip
          items={[
            {
              label: "Average\nScore",
              value: formatOrDash(averageScore(session)),
            },
            { label: "Best\nRep", value: formatOrDash(bestScore(session)) },
            { label: "Worst\nRep", value: formatOrDash(worstScore(session)) },
            {
              label: "Consist\nency",
              value: (() => {
                const value = consistency(session);
                return value === null ? "—" : `${Math.round(value)}%`;
              })(),
            },
          ]}
        />

        <div className="flex flex-col gap-2.5">
          <SectionHeader title="Mechanics breakdown" />
          <Card padding="p-3.5">
            {orderedMechanicAverages(session).map((entry) => (
              <button
                key={entry.mechanic}
                type="button"
                onClick={() =>
                  navigate(`/mechanic/${entry.mechanic}/${groupOf(session.shot)}`)
                }
                className="w-full text-left transition-opacity hover:opacity-80"
              >
                <MechanicRow
                  title={mechanicName[entry.mechanic]}
                  value={entry.score}
                />
              </button>
            ))}
          </Card>
        </div>

        <div className="flex gap-3">
          <CalloutTile
            icon="Crosshair"
            tint="#FF5F52"
            label="Biggest weakness"
            value={
              weakestMechanic(session)
                ? mechanicName[weakestMechanic(session)!.mechanic]
                : "—"
            }
          />
          <CalloutTile
            icon="ChartColumn"
            tint="#C6FF3D"
            label="Biggest improvement"
            value={
              bestImprovement
                ? `${mechanicName[bestImprovement.mechanic]} +${Math.round(
                    bestImprovement.delta,
                  )}`
                : "Building baseline"
            }
          />
        </div>

        {focus && (
          <Card className="!bg-pu-lime/[0.16]">
            <div className="flex flex-col gap-3.5">
              <div className="flex items-start gap-3">
                <IconBadge icon="Lightbulb" size={44} />
                <div className="flex flex-col gap-[3px]">
                  <MicroLabel>Your #1 focus</MicroLabel>
                  <span className="text-[19px] font-bold leading-snug text-pu-primary">
                    {focus.correction}
                  </span>
                </div>
              </div>

              {focus.issue && (
                <p className="text-[13px] font-medium leading-relaxed text-pu-secondary">
                  {focus.issue.explanation}
                </p>
              )}

              {recommendedDrill && (
                <>
                  <div className="h-px w-full bg-pu-hairline" />
                  <div className="flex items-center gap-3.5">
                    <DrillThumbnail />
                    <div className="flex min-w-0 flex-col gap-[3px]">
                      <MicroLabel>Recommended next drill</MicroLabel>
                      <span className="text-[17px] font-semibold text-pu-primary">
                        {recommendedDrill.name}
                      </span>
                      <span className="text-[13px] font-medium text-pu-secondary">
                        {drillPrescription(recommendedDrill)}
                      </span>
                    </div>
                  </div>
                </>
              )}
            </div>
          </Card>
        )}

        {reps.length > 0 && (
          <div className="flex flex-col gap-2.5">
            <SectionHeader title="Reps" accessory={String(reps.length)} />
            <Card padding="p-1.5">
              {reps
                .slice(-12)
                .reverse()
                .map((rep, index, list) => (
                  <div key={rep.id}>
                    <RepSummaryRow rep={rep} />
                    {index < list.length - 1 && (
                      <div className="ml-[52px] h-px bg-pu-hairline" />
                    )}
                  </div>
                ))}
            </Card>
            {reps.length > 12 && (
              <p className="text-xs text-pu-tertiary">
                Showing the 12 most recent reps.
              </p>
            )}
          </div>
        )}

        {reps.length > 0 && <BallPaddleData rep={reps[reps.length - 1] ?? null} />}
      </Screen>

      {recommendedDrill && (
        <div className="pu-action-bar fixed inset-x-0 bottom-[68px] px-5 pb-3 pt-2.5 lg:sticky lg:bottom-4">
          <div className="mx-auto w-full max-w-xl">
            <PrimaryButton onClick={startDrill}>
              <Icon name="Play" className="h-4 w-4" strokeWidth={3} />
              START DRILL
            </PrimaryButton>
          </div>
        </div>
      )}
    </>
  );
}

function RepSummaryRow({ rep }: { rep: RepRecord }) {
  return (
    <div className="flex items-center gap-3 px-2.5 py-2.5">
      <span className="pu-tabular w-7 shrink-0 text-[13px] font-bold text-pu-tertiary">
        {rep.index}
      </span>
      <span
        className="pu-tabular w-8 shrink-0 text-[19px] font-bold"
        style={{ color: scoreColor(rep.score) }}
      >
        {Math.round(rep.score)}
      </span>
      <span className="flex-1 truncate text-sm font-medium text-pu-primary">
        {rep.dominantIssue ? mechanicName[rep.dominantIssue] : "Clean rep"}
      </span>
    </div>
  );
}

function formatOrDash(value: number | null): string {
  return value === null ? "—" : String(Math.round(value));
}
