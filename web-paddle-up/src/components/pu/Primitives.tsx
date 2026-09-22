/**
 * Shared component language: cards, dials, bars, tiles, buttons.
 * Flat surfaces with hairline borders — no shadows anywhere except the lime
 * glow on the rating dial ring.
 */

import { memo, type ButtonHTMLAttributes, type ReactNode } from "react";

import { Icon } from "@/components/pu/Icon";
import { cn } from "@/lib/utils";

export function scoreColor(value: number): string {
  if (value < 60) return "#FF5F52";
  if (value < 75) return "#FFB020";
  return "#C6FF3D";
}

export function MicroLabel({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return <div className={cn("pu-micro", className)}>{children}</div>;
}

export function Card({
  children,
  className,
  padding = "p-4",
}: {
  children: ReactNode;
  className?: string;
  padding?: string;
}) {
  return <div className={cn("pu-card", padding, className)}>{children}</div>;
}

export function SectionHeader({
  title,
  accessory,
}: {
  title: string;
  accessory?: string;
}) {
  return (
    <div className="flex items-center justify-between">
      <MicroLabel>{title}</MicroLabel>
      {accessory && (
        <span className="text-[11px] font-semibold text-pu-tertiary">
          {accessory}
        </span>
      )}
    </div>
  );
}

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  children: ReactNode;
};

export function PrimaryButton({
  children,
  className,
  disabled,
  ...rest
}: ButtonProps) {
  return (
    <button
      type="button"
      disabled={disabled}
      className={cn(
        "flex h-[58px] w-full items-center justify-center gap-[9px] rounded-full text-[17px] font-black tracking-[0.03em] transition-all duration-200",
        "active:scale-[0.97]",
        disabled
          ? "cursor-not-allowed bg-pu-raised text-pu-tertiary"
          : "bg-pu-lime text-pu-lime-ink hover:brightness-105",
        className,
      )}
      {...rest}
    >
      {children}
    </button>
  );
}

export function SecondaryButton({ children, className, ...rest }: ButtonProps) {
  return (
    <button
      type="button"
      className={cn(
        "flex h-[52px] w-full items-center justify-center gap-2 rounded-full border border-pu-hairline bg-pu-raised text-base font-semibold text-pu-primary transition-all duration-200 active:scale-[0.97] hover:bg-white/[0.06]",
        className,
      )}
      {...rest}
    >
      {children}
    </button>
  );
}

/** Small circular icon badge used in lists and callouts. */
export function IconBadge({
  icon,
  size = 40,
  tint = "#C6FF3D",
  bordered = false,
}: {
  icon: string;
  size?: number;
  tint?: string;
  bordered?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex shrink-0 items-center justify-center rounded-full",
        bordered && "border border-pu-hairline",
      )}
      style={{
        width: size,
        height: size,
        backgroundColor: `${tint}24`,
        color: tint,
      }}
    >
      <Icon name={icon} className="shrink-0" strokeWidth={2.2} />
    </div>
  );
}

/** The signature circular rating dial: thin lime ring around a huge numeral. */
function ScoreDialComponent({
  value,
  maxValue = 100,
  caption,
  subtitle,
  subtitleIsPositive = true,
  size = 230,
  lineWidth = 14,
}: {
  value: number | null;
  maxValue?: number;
  caption: string;
  subtitle?: string;
  subtitleIsPositive?: boolean;
  size?: number;
  lineWidth?: number;
}) {
  const fraction =
    value === null || maxValue <= 0
      ? 0
      : Math.min(1, Math.max(0.02, value / maxValue));
  const radius = (size - lineWidth) / 2;
  const circumference = 2 * Math.PI * radius;

  return (
    <div
      className="relative mx-auto"
      style={{ width: size, height: size }}
      role="img"
      aria-label={`${caption}: ${value === null ? "not rated" : Math.round(value)}`}
    >
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="rgba(255,255,255,0.07)"
          strokeWidth={lineWidth}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="#C6FF3D"
          strokeWidth={lineWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - fraction)}
          style={{
            transition: "stroke-dashoffset 1.1s cubic-bezier(0.2, 0.8, 0.2, 1)",
            filter: "drop-shadow(0 0 12px rgba(198,255,61,0.35))",
          }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center px-6 text-center">
        <MicroLabel>{caption}</MicroLabel>
        <div className="pu-tabular text-[88px] font-black leading-none text-pu-primary">
          {value === null ? "—" : Math.round(value)}
        </div>
        {subtitle && (
          <div
            className={cn(
              "mt-1 flex items-center gap-1 text-[13px] font-medium",
              subtitleIsPositive ? "text-pu-lime" : "text-pu-secondary",
            )}
          >
            {subtitleIsPositive && (
              <Icon name="ArrowUp" className="h-3 w-3" strokeWidth={2.6} />
            )}
            {subtitle}
          </div>
        )}
      </div>
    </div>
  );
}

export const ScoreDial = memo(ScoreDialComponent);

export function ScoreBar({
  value,
  height = 8,
}: {
  value: number;
  height?: number;
}) {
  const clamped = Math.min(100, Math.max(0, value));
  return (
    <div
      className="w-full overflow-hidden rounded-full bg-white/[0.09]"
      style={{ height }}
    >
      <div
        className="h-full rounded-full transition-[width] duration-700 ease-out"
        style={{
          width: `${Math.max(6, clamped)}%`,
          backgroundColor: scoreColor(clamped),
        }}
      />
    </div>
  );
}

export function MechanicRow({
  title,
  value,
  showsChevron = true,
}: {
  title: string;
  value: number;
  showsChevron?: boolean;
}) {
  return (
    <div className="flex items-center gap-3 py-1.5">
      <span className="w-32 shrink-0 truncate text-[15px] font-medium text-pu-primary">
        {title}
      </span>
      <div className="flex-1">
        <ScoreBar value={value} />
      </div>
      <span className="pu-tabular w-8 shrink-0 text-right text-[15px] font-semibold text-pu-primary">
        {Math.round(value)}
      </span>
      {showsChevron && (
        <Icon name="ChevronRight" className="h-3.5 w-3.5 text-pu-tertiary" />
      )}
    </div>
  );
}

export function StatTile({
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
      <Icon
        name={icon}
        className="h-[19px] w-[19px]"
        strokeWidth={2.2}
        // Colour comes from the domain (alert / lime / amber).
      />
      <MicroLabel className="leading-tight">{label}</MicroLabel>
      <span className="line-clamp-2 text-[15px] font-semibold text-pu-primary">
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
      <style>{`.pu-stat-icon { color: ${iconColor}; }`}</style>
    </div>
  );
}

/** Four equal columns divided by hairlines — session summary headline stats. */
export function StatStrip({
  items,
}: {
  items: { label: string; value: string }[];
}) {
  return (
    <div className="pu-card flex items-stretch py-4">
      {items.map((item, index) => (
        <div key={item.label} className="flex flex-1 items-center">
          <div className="flex flex-1 flex-col items-center gap-1.5 text-center">
            <MicroLabel className="whitespace-pre-line leading-tight">
              {item.label}
            </MicroLabel>
            <span className="pu-tabular text-2xl font-bold text-pu-primary">
              {item.value}
            </span>
          </div>
          {index < items.length - 1 && (
            <div className="h-10 w-px shrink-0 bg-pu-hairline" />
          )}
        </div>
      ))}
    </div>
  );
}

/** Inline empty-state block for screens with no data yet. */
export function EmptyState({
  icon,
  title,
  message,
}: {
  icon: string;
  title: string;
  message: string;
}) {
  return (
    <div className="flex flex-col items-center gap-2.5 py-7 text-center">
      <Icon name={icon} className="h-7 w-7 text-pu-tertiary" strokeWidth={1.4} />
      <span className="text-[17px] font-semibold text-pu-primary">{title}</span>
      <span className="max-w-sm text-[13px] font-medium text-pu-secondary">
        {message}
      </span>
    </div>
  );
}

export function AnalyzerBadge({
  status,
}: {
  status: "production" | "preview" | "planned";
}) {
  const tint =
    status === "production"
      ? "#C6FF3D"
      : status === "preview"
        ? "#FFB020"
        : "#5E6760";
  const label =
    status === "production"
      ? "Live"
      : status === "preview"
        ? "Preview"
        : "Coming soon";

  return (
    <span
      className="rounded-full px-[7px] py-[3px] text-[10px] font-bold uppercase tracking-[0.06em]"
      style={{ color: tint, backgroundColor: `${tint}26` }}
    >
      {label}
    </span>
  );
}

/** Abstract court-trajectory thumbnail used on drill cards. */
export function DrillThumbnail() {
  return (
    <div
      className="relative shrink-0 overflow-hidden rounded-[10px]"
      style={{ width: 74, height: 62, backgroundColor: "#10200E" }}
      aria-hidden="true"
    >
      <svg viewBox="0 0 74 62" className="h-full w-full p-2">
        <path
          d="M0 38 H74 M37 0 V62"
          stroke="rgba(198,255,61,0.18)"
          strokeWidth="1"
        />
        <path
          d="M9 45 Q34 12 61 34"
          fill="none"
          stroke="#C6FF3D"
          strokeWidth="2"
          strokeLinecap="round"
          strokeDasharray="3 3"
        />
        <circle cx="61" cy="34" r="5" fill="#C6FF3D" />
      </svg>
    </div>
  );
}

/** Simple wrapping chip layout. */
export function FlowChips({ items }: { items: string[] }) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item) => (
        <span
          key={item}
          className="rounded-full border border-pu-hairline bg-pu-surface px-2.5 py-[7px] text-xs font-medium text-pu-secondary"
        >
          {item}
        </span>
      ))}
    </div>
  );
}
