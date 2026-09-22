/**
 * The Rating Hero home: dominant rating dial, recommended drill, a tight stat
 * row, pattern callout, milestone chips, and a single Start Practice action.
 */

import { useNavigate } from "react-router-dom";

import { Screen, ScreenHeader } from "@/components/pu/AppShell";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  DrillThumbnail,
  IconBadge,
  MicroLabel,
  PrimaryButton,
  ScoreDial,
  SectionHeader,
} from "@/components/pu/Primitives";
import { drillPrescription } from "@/lib/pu/drills";
import { cn } from "@/lib/utils";
import { useAppState } from "@/state/AppStateProvider";

export default function Home() {
  const navigate = useNavigate();
  const {
    overallRating,
    overallRatingDelta,
    totalRepCount,
    recommendedDrill,
    weakestShot,
    biggestImprovement,
    practiceStreak,
    recurringWeaknesses,
    achievements,
  } = useAppState();

  const ratingSubtitle = (() => {
    if (overallRatingDelta !== null && Math.abs(overallRatingDelta) >= 0.5) {
      const sign = overallRatingDelta > 0 ? "+" : "";
      return `${sign}${Math.round(overallRatingDelta)} this month`;
    }
    if (overallRating === null) return "Practise to get rated";
    return `${totalRepCount} reps measured`;
  })();

  const insight = recurringWeaknesses[0];

  return (
    <>
      <Screen className="flex flex-col gap-4">
        <ScreenHeader onSettings={() => navigate("/settings")} />

        <div className="py-1">
          <ScoreDial
            value={overallRating}
            caption="Paddle Up Rating"
            subtitle={ratingSubtitle}
            subtitleIsPositive={(overallRatingDelta ?? 0) > 0}
            size={250}
          />
        </div>

        {recommendedDrill && (
          <button
            type="button"
            onClick={() => navigate(`/drill/${recommendedDrill.id}`)}
            className="pu-card flex items-center gap-3.5 p-4 text-left transition-colors hover:bg-pu-raised/60"
          >
            <DrillThumbnail />
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <MicroLabel>Today's recommended drill</MicroLabel>
              <span className="line-clamp-2 text-[19px] font-bold leading-snug text-pu-primary">
                {recommendedDrill.name}
              </span>
              <span className="text-[13px] font-medium text-pu-secondary">
                {drillPrescription(recommendedDrill)}
              </span>
            </div>
            <Icon name="ChevronRight" className="h-4 w-4 shrink-0 text-pu-tertiary" />
          </button>
        )}

        <div className="flex gap-3">
          <StatTile
            icon="Crosshair"
            iconColor="#FF5F52"
            label="Weakest shot"
            value={weakestShot ? shotLabel(weakestShot.group) : "—"}
            detail={weakestShot ? `· ${Math.round(weakestShot.score)}` : undefined}
            detailIsPositive={false}
          />
          <StatTile
            icon="ChartColumn"
            iconColor="#C6FF3D"
            label="Recent improvement"
            value={
              biggestImprovement
                ? mechanicLabel(biggestImprovement.mechanic)
                : "—"
            }
            detail={
              biggestImprovement
                ? `+${Math.round(biggestImprovement.delta)} this month`
                : undefined
            }
          />
          <StatTile
            icon="Flame"
            iconColor="#FFB020"
            label="Practice streak"
            value={practiceStreak > 0 ? `${practiceStreak}-day` : "Start one"}
            detail={practiceStreak > 0 ? "streak" : undefined}
          />
        </div>

        {insight && (
          <Card className="!bg-pu-lime/[0.16]">
            <div className="flex items-start gap-3">
              <IconBadge icon="Lightbulb" />
              <div className="flex flex-col gap-1.5">
                <MicroLabel>Pattern spotted</MicroLabel>
                <p className="text-[15px] font-medium leading-relaxed text-pu-primary">
                  {insight.message}
                </p>
              </div>
            </div>
          </Card>
        )}

        {achievements.length > 0 && (
          <div className="flex flex-col gap-2.5">
            <SectionHeader title="Milestones" />
            <div className="-mx-5 flex gap-2.5 overflow-x-auto px-5 pb-1">
              {achievements.slice(0, 6).map((achievement) => (
                <div
                  key={achievement.id}
                  className="flex shrink-0 items-center gap-2.5 rounded-full border border-pu-hairline bg-pu-surface px-3.5 py-2.5"
                >
                  <Icon
                    name={achievement.icon}
                    className="h-3.5 w-3.5 shrink-0 text-pu-lime"
                    strokeWidth={2.2}
                  />
                  <div className="flex flex-col">
                    <span className="whitespace-nowrap text-[13px] font-semibold text-pu-primary">
                      {achievement.title}
                    </span>
                    <span className="whitespace-nowrap text-[11px] text-pu-secondary">
                      {achievement.detail}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </Screen>

      <div className="pu-action-bar fixed inset-x-0 bottom-[68px] border-t-0 bg-transparent px-5 pb-2 backdrop-blur-none lg:sticky lg:bottom-4">
        <div className="mx-auto w-full max-w-xl">
          <PrimaryButton onClick={() => navigate("/practice")}>
            <Icon name="Play" className="h-4 w-4" strokeWidth={3} />
            START PRACTICE
          </PrimaryButton>
        </div>
      </div>
    </>
  );
}

function StatTile({
  icon,
  iconColor,
  label,
  value,
  detail,
  detailIsPositive = true,
}: {
  icon: string;
  iconColor: string;
  label: string;
  value: string;
  detail?: string;
  detailIsPositive?: boolean;
}) {
  return (
    <div className="pu-tile flex flex-1 flex-col items-center gap-1.5 px-2 py-3.5 text-center">
      <span style={{ color: iconColor }}>
        <Icon name={icon} className="h-[19px] w-[19px]" strokeWidth={2.2} />
      </span>
      <MicroLabel className="leading-tight">{label}</MicroLabel>
      <span className="line-clamp-2 text-[15px] font-semibold leading-tight text-pu-primary">
        {value}
      </span>
      {detail && (
        <span
          className={cn(
            "truncate text-[13px] font-medium",
            detailIsPositive ? "text-pu-lime" : "text-pu-secondary",
          )}
        >
          {detail}
        </span>
      )}
    </div>
  );
}

function shotLabel(group: string): string {
  return group
    .replace(/([A-Z])/g, " $1")
    .replace(/^./, (char) => char.toUpperCase())
    .trim();
}

function mechanicLabel(mechanic: string): string {
  return mechanic
    .replace(/([A-Z])/g, " $1")
    .replace(/^./, (char) => char.toUpperCase())
    .trim();
}
