/**
 * The Paddle Up skill card: overall rating, per-shot scores, strongest and
 * weakest shots, trend, and recent activity.
 */

import { useNavigate } from "react-router-dom";

import { Screen, ScreenHeader } from "@/components/pu/AppShell";
import { TrendChart } from "@/components/pu/Charts";
import { Icon } from "@/components/pu/Icon";
import {
  Card,
  EmptyState,
  IconBadge,
  MicroLabel,
  ScoreBar,
  SectionHeader,
} from "@/components/pu/Primitives";
import { mechanicName } from "@/lib/pu/mechanics";
import { profileInitials } from "@/lib/pu/profile";
import { shotGroupIcon, shotGroupName } from "@/lib/pu/shots";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

export default function Profile() {
  const navigate = useNavigate();
  const {
    profile,
    shotRatings,
    overallRating,
    strongestShot,
    weakestShot,
    weeklyTrend,
    completedSessionCount,
    totalRepCount,
    biggestImprovement,
    practiceStreak,
  } = useAppState();
  const store = useStore();

  const trend = strongestShot ? weeklyTrend(strongestShot.group) : [];

  return (
    <Screen className="flex flex-col gap-3.5">
      <ScreenHeader onSettings={() => navigate("/settings")} />

      <div className="flex items-center gap-4 py-1">
        <span className="flex h-[92px] w-[92px] shrink-0 items-center justify-center rounded-full border border-pu-lime/25 bg-pu-lime/[0.13] text-[28px] font-black text-pu-lime/85">
          {profileInitials(profile)}
        </span>
        <div className="flex min-w-0 flex-col gap-[3px]">
          <span className="truncate text-2xl font-black text-pu-primary">
            {profile.displayName || "Player"}
          </span>
          <MicroLabel>Overall Paddle Up Rating</MicroLabel>
          <span className="pu-tabular text-[44px] font-black leading-none text-pu-primary">
            {overallRating === null ? "—" : Math.round(overallRating)}
          </span>
          {store.isPro && (
            <span className="mt-1 self-start rounded-full bg-pu-lime px-2 py-[3px] text-[10px] font-bold tracking-[0.1em] text-pu-lime-ink">
              PADDLE UP PRO
            </span>
          )}
        </div>
      </div>

      {shotRatings.length === 0 ? (
        <Card>
          <EmptyState
            icon="Activity"
            title="No rating yet"
            message="Complete your first session and Paddle Up will build your skill card."
          />
        </Card>
      ) : (
        <>
          <div className="flex flex-col gap-2.5">
            <SectionHeader title="Shot ratings" />
            <Card padding="p-3.5">
              {shotRatings.map((rating) => (
                <button
                  key={rating.group}
                  type="button"
                  onClick={() => navigate(`/group/${rating.group}`)}
                  className="flex w-full items-center gap-3 py-[7px] text-left transition-opacity hover:opacity-80"
                >
                  <span className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-full bg-pu-lime/[0.12] text-pu-lime">
                    <Icon
                      name={shotGroupIcon[rating.group]}
                      className="h-3.5 w-3.5"
                      strokeWidth={2.2}
                    />
                  </span>
                  <span className="w-24 shrink-0 truncate text-[15px] font-medium text-pu-primary">
                    {shotGroupName[rating.group]}
                  </span>
                  <div className="flex-1">
                    <ScoreBar value={rating.score} />
                  </div>
                  <span className="pu-tabular w-7 shrink-0 text-right text-[15px] font-semibold text-pu-primary">
                    {Math.round(rating.score)}
                  </span>
                  <Icon
                    name="ChevronRight"
                    className="h-3 w-3 shrink-0 text-pu-tertiary"
                  />
                </button>
              ))}
            </Card>
            <p className="text-[11px] leading-relaxed text-pu-tertiary">
              Paddle Up Rating is Paddle Up's own mechanics score. It is not a
              DUPR rating.
            </p>
          </div>

          <div className="flex gap-3">
            <CalloutTile
              icon="Trophy"
              tint="#C6FF3D"
              label="Strongest shot"
              value={strongestShot ? shotGroupName[strongestShot.group] : "—"}
            />
            <CalloutTile
              icon="CircleArrowDown"
              tint="#FF5F52"
              label="Weakest shot"
              value={weakestShot ? shotGroupName[weakestShot.group] : "—"}
            />
          </div>

          {trend.length >= 2 && strongestShot && (
            <Card>
              <SectionHeader
                title="Rating trend"
                accessory={shotGroupName[strongestShot.group]}
              />
              <div className="mt-3">
                <TrendChart points={trend} />
              </div>
            </Card>
          )}
        </>
      )}

      <button
        type="button"
        onClick={() => navigate("/swing-match")}
        className="pu-card flex items-center gap-3.5 p-4 text-left transition-colors hover:bg-pu-raised/60"
      >
        <IconBadge icon="Users" size={44} />
        <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
          <div className="flex items-center gap-2">
            <span className="text-[17px] font-semibold text-pu-primary">
              Swing Match
            </span>
            {store.isLocked("swingMatch") && (
              <Icon name="Lock" className="h-3 w-3 text-pu-amber" />
            )}
          </div>
          <span className="text-[13px] font-medium text-pu-secondary">
            Compare your mechanics to elite references
          </span>
        </div>
        <Icon name="ChevronRight" className="h-3.5 w-3.5 shrink-0 text-pu-tertiary" />
      </button>

      <div className="flex flex-col gap-2.5">
        <SectionHeader title="Recent activity" />
        <Card padding="p-3.5">
          <div className="flex flex-col gap-3.5">
            <ActivityRow
              icon="Dumbbell"
              title={`${completedSessionCount} sessions completed`}
              detail={`${totalRepCount} reps measured`}
            />
            {biggestImprovement && (
              <>
                <div className="h-px w-full bg-pu-hairline" />
                <ActivityRow
                  icon="ChartColumn"
                  title={mechanicName[biggestImprovement.mechanic]}
                  detail={`+${Math.round(biggestImprovement.delta)} this month`}
                  detailIsPositive
                />
              </>
            )}
            {practiceStreak > 0 && (
              <>
                <div className="h-px w-full bg-pu-hairline" />
                <ActivityRow
                  icon="Flame"
                  title={`${practiceStreak}-day practice streak`}
                  detail="Keep it going"
                />
              </>
            )}
          </div>
        </Card>
      </div>
    </Screen>
  );
}

export function CalloutTile({
  icon,
  tint,
  label,
  value,
}: {
  icon: string;
  tint: string;
  label: string;
  value: string;
}) {
  return (
    <div className="pu-tile flex flex-1 items-center gap-3 p-3.5">
      <IconBadge icon={icon} tint={tint} size={36} />
      <div className="flex min-w-0 flex-col gap-0.5">
        <MicroLabel>{label}</MicroLabel>
        <span className="line-clamp-2 text-[15px] font-semibold leading-tight text-pu-primary">
          {value}
        </span>
      </div>
    </div>
  );
}

function ActivityRow({
  icon,
  title,
  detail,
  detailIsPositive = false,
}: {
  icon: string;
  title: string;
  detail: string;
  detailIsPositive?: boolean;
}) {
  return (
    <div className="flex items-center gap-3">
      <IconBadge icon={icon} size={36} />
      <div className="flex min-w-0 flex-col gap-0.5">
        <span className="text-[15px] font-medium text-pu-primary">{title}</span>
        <span
          className={
            detailIsPositive
              ? "text-[13px] font-medium text-pu-lime"
              : "text-[13px] font-medium text-pu-secondary"
          }
        >
          {detail}
        </span>
      </div>
    </div>
  );
}
