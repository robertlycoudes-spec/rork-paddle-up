/**
 * Onboarding building blocks: the hero card, promise rows, question scaffold,
 * selection rows, the advantage comparison and the staged analysis screen.
 */

import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import { BallMark } from "@/components/pu/BallMark";
import { Icon } from "@/components/pu/Icon";
import { MicroLabel, PrimaryButton } from "@/components/pu/Primitives";
import { cn } from "@/lib/utils";

/**
 * The hero brand card: glyph in counter-rotating orbit rings, wordmark, system
 * tagline, live chip, pitch copy, and a hairline-divided stat strip.
 */
export function HeroCard() {
  return (
    <div className="pu-card animate-pu-rise-lg overflow-hidden">
      <div className="flex flex-col items-center gap-4 px-5 pb-[22px] pt-7">
        <HeroGlyph />

        <div className="flex flex-col items-center gap-2.5">
          <h1 className="text-[30px] font-black tracking-[0.1em] text-pu-primary">
            PADDLE UP
          </h1>
          <span className="h-[3px] w-[26px] rounded-full bg-pu-lime" />
          <span className="text-[10px] font-bold tracking-[0.2em] text-pu-lime">
            AI PICKLEBALL DEVELOPMENT SYSTEM
          </span>
        </div>

        <div className="flex items-center gap-1.5 rounded-full border border-pu-lime/20 bg-pu-lime/[0.08] px-3 py-1.5">
          <span className="h-[5px] w-[5px] animate-pu-pulse rounded-full bg-pu-lime" />
          <span className="text-[10px] font-bold tracking-[0.2em] text-pu-lime">
            SYSTEM ONLINE
          </span>
        </div>

        <p className="max-w-sm text-center text-[15px] font-medium leading-relaxed text-pu-secondary">
          Your coach builds the plan, reads your game, and pushes you every
          single day. All you have to do is show up.
        </p>
      </div>

      <div className="h-px w-full bg-pu-hairline" />

      <div className="flex items-stretch py-3.5">
        <HeroStat value="Daily" label="NEW PLAN" delay="0.55s" />
        <div className="h-10 w-px self-center bg-pu-hairline" />
        <HeroStat value="24/7" label="AI COACH" delay="0.65s" />
        <div className="h-10 w-px self-center bg-pu-hairline" />
        <HeroStat value="100%" label="BUILT FOR YOU" delay="0.75s" />
      </div>
    </div>
  );
}

/**
 * Ball mark inside a raised disc, wrapped in two counter-rotating dashed orbit
 * rings over a faint lime bloom — the "live coach" motif. Every ring rotates
 * alone around its own centre; the satellite dots stay pinned so nothing
 * wobbles. The mark is symmetric, so rings, disc and ball share one centre.
 */
function HeroGlyph() {
  return (
    <div className="relative flex h-[132px] w-[132px] items-center justify-center">
      <div
        className="absolute inset-0 rounded-full"
        style={{
          background:
            "radial-gradient(circle, rgba(198,255,61,0.16) 0%, transparent 62%)",
        }}
      />

      <div className="absolute h-[104px] w-[104px] animate-pu-spin rounded-full border border-dashed border-pu-lime/35" />
      <div className="absolute h-[88px] w-[88px] animate-pu-spin-reverse rounded-full border border-dashed border-pu-lime/[0.18]" />

      <span
        className="absolute h-[7px] w-[7px] rounded-full bg-pu-lime"
        style={{ transform: "translateX(-52px)" }}
      />
      <span
        className="absolute h-1 w-1 rounded-full bg-pu-lime/50"
        style={{ transform: "translateX(44px)" }}
      />

      <div className="absolute flex h-[72px] w-[72px] items-center justify-center rounded-full border border-pu-hairline bg-pu-raised" />
      <BallMark size={40} className="relative" />
    </div>
  );
}

function HeroStat({
  value,
  label,
  delay,
}: {
  value: string;
  label: string;
  delay: string;
}) {
  return (
    <div
      className="flex flex-1 animate-pu-rise flex-col items-center gap-1"
      style={{ animationDelay: delay }}
    >
      <span className="text-[17px] font-black text-pu-primary">{value}</span>
      <span className="text-[10px] font-bold tracking-[0.12em] text-pu-tertiary">
        {label}
      </span>
    </div>
  );
}

/** A numbered promise row under the hero card. */
export function PromiseRow({
  index,
  icon,
  title,
  detail,
  delay,
}: {
  index: string;
  icon: string;
  title: string;
  detail: string;
  delay: number;
}) {
  return (
    <div
      className="pu-tile flex animate-pu-rise items-center gap-3.5 p-4"
      style={{ animationDelay: `${delay}s` }}
    >
      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-pu-hairline bg-pu-lime/[0.14] text-pu-lime">
        <Icon name={icon} className="h-[18px] w-[18px]" strokeWidth={2.2} />
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
        <span className="text-[17px] font-semibold text-pu-primary">{title}</span>
        <span className="text-[13px] font-medium leading-snug text-pu-secondary">
          {detail}
        </span>
      </div>
      <span className="pu-tabular shrink-0 text-xs font-bold text-pu-lime/85">
        {index}
      </span>
    </div>
  );
}

/** Segmented lime progress bar + back chevron shown above every question. */
export function QuestionHeader({
  index,
  total,
  onBack,
}: {
  index: number;
  total: number;
  onBack: () => void;
}) {
  return (
    <div className="flex items-center gap-3 px-5 pt-2">
      <button
        type="button"
        onClick={onBack}
        aria-label="Back"
        className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-pu-hairline bg-pu-surface text-pu-secondary transition-transform active:scale-95 hover:text-pu-primary"
      >
        <Icon name="ChevronLeft" className="h-4 w-4" strokeWidth={2.6} />
      </button>

      <div className="flex flex-1 items-center gap-1.5">
        {Array.from({ length: total }).map((_, segment) => (
          <span
            key={segment}
            className={cn(
              "h-1 flex-1 rounded-full transition-colors duration-300",
              segment <= index ? "bg-pu-lime" : "bg-white/[0.09]",
            )}
          />
        ))}
      </div>

      <span className="pu-tabular shrink-0 text-[11px] font-semibold text-pu-tertiary">
        {index + 1}/{total}
      </span>
    </div>
  );
}

/**
 * Shared question scaffold: eyebrow with a leading lime dash and trailing
 * hairline, heavy title, subtitle, then the options block. The title lands
 * first and the options follow on a short delay.
 */
export function QuestionScreen({
  title,
  subtitle,
  eyebrow,
  canContinue = true,
  continueLabel = "NEXT",
  onContinue,
  children,
}: {
  title: string;
  subtitle: string;
  eyebrow?: string;
  canContinue?: boolean;
  continueLabel?: string;
  onContinue: () => void;
  children: ReactNode;
}) {
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-xl px-5 pb-28 pt-6">
          <div className="animate-pu-rise flex flex-col gap-2">
            {eyebrow && (
              <div className="flex items-center gap-2.5">
                <span className="h-[2px] w-4 shrink-0 rounded-full bg-pu-lime" />
                <span className="shrink-0 text-[11px] font-bold tracking-[0.2em] text-pu-lime">
                  {eyebrow}
                </span>
                <span className="h-px flex-1 bg-pu-hairline" />
              </div>
            )}
            <h2 className="text-[28px] font-black leading-tight text-pu-primary">
              {title}
            </h2>
            <p className="text-[15px] font-medium leading-relaxed text-pu-secondary">
              {subtitle}
            </p>
          </div>

          <div
            className="animate-pu-rise mt-5 flex flex-col gap-2.5"
            style={{ animationDelay: "0.16s" }}
          >
            {children}
          </div>
        </div>
      </div>

      <div className="pu-action-bar px-5 pb-3 pt-2.5">
        <div className="mx-auto w-full max-w-xl">
          <PrimaryButton
            onClick={onContinue}
            disabled={!canContinue}
            className={cn(
              "transition-all duration-300",
              canContinue ? "opacity-100" : "pointer-events-none opacity-0",
            )}
          >
            {continueLabel}
            <Icon name="ArrowRight" className="h-3.5 w-3.5" strokeWidth={3} />
          </PrimaryButton>
        </div>
      </div>
    </div>
  );
}

/** One tappable answer row with a springing lime check. */
export function SelectionRow({
  title,
  detail,
  icon,
  isSelected,
  onSelect,
}: {
  title: string;
  detail?: string;
  icon?: string;
  isSelected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={isSelected}
      className={cn(
        "flex w-full items-center gap-3.5 rounded-pu-tile border p-4 text-left transition-all duration-200 active:scale-[0.985]",
        isSelected
          ? "border-pu-lime/55 bg-pu-raised"
          : "border-pu-hairline bg-pu-surface hover:bg-pu-raised/70",
      )}
    >
      {icon && (
        <Icon
          name={icon}
          className={cn(
            "h-4 w-4 shrink-0 transition-colors",
            isSelected ? "text-pu-lime" : "text-pu-tertiary",
          )}
          strokeWidth={2.2}
        />
      )}
      <div className="flex min-w-0 flex-1 flex-col gap-[3px]">
        <span className="text-[17px] font-semibold text-pu-primary">{title}</span>
        {detail && (
          <span className="text-[13px] font-medium text-pu-secondary">
            {detail}
          </span>
        )}
      </div>
      <span
        className={cn(
          "flex h-[22px] w-[22px] shrink-0 items-center justify-center rounded-full border-[1.5px] transition-all duration-200",
          isSelected
            ? "scale-100 border-pu-lime bg-pu-lime"
            : "border-pu-tertiary/50",
        )}
      >
        {isSelected && (
          <Icon
            name="Check"
            className="h-3 w-3 text-pu-lime-ink"
            strokeWidth={3.5}
          />
        )}
      </span>
    </button>
  );
}

/**
 * Premium name entry: elevated card with a micro label, a large field and a
 * live validation check that springs in once a name is present.
 */
export function NameField({
  value,
  onChange,
}: {
  value: string;
  onChange: (next: string) => void;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const hasName = value.trim().length > 0;
  const [isFocused, setIsFocused] = useState<boolean>(false);

  useEffect(() => {
    const timer = window.setTimeout(() => inputRef.current?.focus(), 450);
    return () => window.clearTimeout(timer);
  }, []);

  return (
    <div
      className={cn(
        "rounded-pu-card border bg-pu-surface px-[18px] pb-[17px] pt-[15px] transition-colors duration-200",
        isFocused ? "border-pu-lime/55" : "border-pu-hairline",
      )}
    >
      <div className="flex items-center justify-between">
        <MicroLabel>First name</MicroLabel>
        <span
          className={cn(
            "flex h-5 w-5 items-center justify-center rounded-full bg-pu-lime transition-all duration-300",
            hasName ? "scale-100 opacity-100" : "scale-[0.3] opacity-0",
          )}
        >
          <Icon
            name="Check"
            className="h-2.5 w-2.5 text-pu-lime-ink"
            strokeWidth={3.5}
          />
        </span>
      </div>
      <input
        ref={inputRef}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        onFocus={() => setIsFocused(true)}
        onBlur={() => setIsFocused(false)}
        placeholder="Type your first name"
        autoComplete="given-name"
        aria-label="First name"
        className="mt-1.5 w-full border-none bg-transparent text-[28px] font-black text-pu-primary outline-none placeholder:text-pu-tertiary"
      />
    </div>
  );
}

/**
 * Live preview of the coach greeting — makes the name's purpose tangible
 * while the player types. Echoes the hook's dashed-orbit motif.
 */
export function CoachGreetingPreview({ name }: { name: string }) {
  const firstName = name.trim();
  return (
    <div className="flex items-center gap-3.5 rounded-pu-tile border border-dashed border-pu-hairline bg-pu-surface p-4">
      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-pu-lime/[0.14] text-pu-lime">
        <Icon name="AudioWaveform" className="h-[18px] w-[18px]" strokeWidth={2.2} />
      </div>
      <div className="flex min-w-0 flex-col gap-1">
        <MicroLabel>Your coach will say</MicroLabel>
        <span
          className={cn(
            "text-[17px] font-semibold transition-colors duration-200",
            firstName ? "text-pu-primary" : "text-pu-tertiary",
          )}
        >
          {firstName
            ? `\u201CLet's get to work, ${firstName}.\u201D`
            : "\u201CLet's get to work.\u201D"}
        </span>
      </div>
    </div>
  );
}

/**
 * "The advantage" story slide: a flat two-bar comparison. Only the lime 2X bar
 * animates, growing upward from the shared baseline; the 20% bar renders
 * static at full height. Nothing ever drops down from the top.
 */
export function AdvantageCard() {
  const [appeared, setAppeared] = useState<boolean>(false);

  useEffect(() => {
    const timer = window.setTimeout(() => setAppeared(true), 300);
    return () => window.clearTimeout(timer);
  }, []);

  return (
    <div className="pu-card px-5 pb-5 pt-6">
      <div className="flex items-end justify-center gap-7">
        <AdvantageBar
          label="GOING IT ALONE"
          value="20%"
          barHeight={104}
          isLime={false}
          appeared
        />
        <AdvantageBar
          label="WITH PADDLE UP"
          value="2X"
          barHeight={216}
          isLime
          appeared={appeared}
        />
      </div>

      <p className="mt-4 text-center text-[13px] font-medium text-pu-secondary">
        Paddle Up keeps you consistent and accelerates your development.
      </p>
    </div>
  );
}

function AdvantageBar({
  label,
  value,
  barHeight,
  isLime,
  appeared,
}: {
  label: string;
  value: string;
  barHeight: number;
  isLime: boolean;
  appeared: boolean;
}) {
  return (
    <div className="flex flex-1 flex-col items-center gap-3">
      <span className="text-[10px] font-bold tracking-[0.12em] text-pu-tertiary">
        {label}
      </span>
      {/* Fixed-height container anchored to the bottom so growth reads upward. */}
      <div className="flex h-[216px] w-full max-w-[104px] items-end">
        <div
          className={cn(
            "relative flex w-full items-end justify-center rounded-[18px] transition-[height] duration-1600 ease-out",
            isLime ? "bg-pu-lime" : "border border-pu-hairline bg-pu-raised",
          )}
          style={{ height: appeared ? barHeight : Math.max(8, barHeight * 0.02) }}
        >
          <span
            className={cn(
              "pb-3.5 text-2xl font-black transition-opacity duration-300",
              isLime ? "text-pu-lime-ink" : "text-pu-primary",
            )}
            style={{
              opacity: appeared ? 1 : 0,
              transitionDelay: isLime ? "1.4s" : "0s",
            }}
          >
            {value}
          </span>
        </div>
      </div>
    </div>
  );
}

/** Brand mark with slow breathing rings — the app's "live coach" motif. */
export function BallRings() {
  return (
    <div className="relative flex h-[180px] w-[180px] items-center justify-center">
      {[0, 1, 2].map((ring) => (
        <span
          key={ring}
          className="absolute animate-pu-breathe rounded-full border border-pu-lime/20"
          style={{
            width: 108 + ring * 34,
            height: 108 + ring * 34,
            animationDelay: `${ring * 0.25}s`,
            animationDuration: `${1.9 + ring * 0.35}s`,
          }}
        />
      ))}
      <BallMark size={52} className="relative" />
    </div>
  );
}

const ANALYSIS_STAGES: { icon: string; label: string }[] = [
  { icon: "Crosshair", label: "Reading your game profile" },
  { icon: "BarChart3", label: "Comparing against benchmark ranges" },
  { icon: "Footprints", label: "Mapping your movement priorities" },
  { icon: "Layers", label: "Selecting drills for your level" },
  { icon: "Calendar", label: "Sequencing your first week" },
];

/**
 * Staged reveal so the analysis feels like real work, not a spinner. The copy
 * is personalised with the player's first name; names stay on-device.
 */
export function AnalyzingScreen({
  firstName,
  onDone,
}: {
  firstName: string;
  onDone: () => void;
}) {
  const [completed, setCompleted] = useState<number>(0);
  const [isReady, setIsReady] = useState<boolean>(false);
  const displayName = firstName.trim();

  const title = useMemo(() => {
    if (!displayName) {
      return isReady ? "Your plan is ready." : "Creating your plan…";
    }
    return isReady
      ? `${displayName}'s plan is ready.`
      : `Creating ${displayName}'s plan…`;
  }, [displayName, isReady]);

  useEffect(() => {
    let cancelled = false;
    const timers: number[] = [];

    const run = async () => {
      for (let index = 0; index < ANALYSIS_STAGES.length; index += 1) {
        await new Promise<void>((resolve) => {
          timers.push(window.setTimeout(resolve, index === 2 ? 700 : 560));
        });
        if (cancelled) return;
        setCompleted(index + 1);
      }
      if (cancelled) return;
      setIsReady(true);
      // Hold the personalised ready line for a beat before the plan slides in.
      await new Promise<void>((resolve) => {
        timers.push(window.setTimeout(resolve, 1000));
      });
      if (!cancelled) onDone();
    };

    void run();
    return () => {
      cancelled = true;
      timers.forEach((timer) => window.clearTimeout(timer));
    };
  }, [onDone]);

  return (
    <div className="flex flex-1 flex-col items-center justify-center px-5 py-10">
      <BallRings />

      <div className="mt-8 flex flex-col items-center gap-2 text-center">
        <h2 className="text-2xl font-bold text-pu-primary transition-opacity duration-300">
          {title}
        </h2>
        <p className="text-[13px] font-medium text-pu-secondary">
          Your AI coach is turning your answers into a plan
        </p>
      </div>

      <div className="pu-card mt-7 w-full max-w-[330px] px-5 py-2">
        {ANALYSIS_STAGES.map((stage, index) => {
          const isDone = index < completed;
          const isActive = index === completed;
          return (
            <div
              key={stage.label}
              className={cn(
                "flex items-center gap-3 py-[9px] transition-all duration-300",
                index <= completed
                  ? "translate-y-0 opacity-100"
                  : "translate-y-1.5 opacity-45",
              )}
            >
              <span className="flex h-[22px] w-[22px] shrink-0 items-center justify-center">
                {isDone ? (
                  <span className="flex h-[22px] w-[22px] items-center justify-center rounded-full bg-pu-lime">
                    <Icon
                      name="Check"
                      className="h-3 w-3 text-pu-lime-ink"
                      strokeWidth={3.5}
                    />
                  </span>
                ) : isActive ? (
                  <Icon
                    name="LoaderCircle"
                    className="h-4 w-4 animate-spin text-pu-lime"
                  />
                ) : (
                  <Icon
                    name={stage.icon}
                    className="h-2.5 w-2.5 text-pu-tertiary"
                  />
                )}
              </span>
              <span
                className={cn(
                  "text-[15px] font-medium",
                  index <= completed ? "text-pu-primary" : "text-pu-tertiary",
                )}
              >
                {stage.label}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
