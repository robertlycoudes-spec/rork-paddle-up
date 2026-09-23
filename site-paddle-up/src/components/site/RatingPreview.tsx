import { memo } from "react";

const RADIUS = 88;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;
const SCORE = 82;

/**
 * Static illustration of the app's "Rating Hero" — dial, main issue, fix —
 * reading in the same Score → Main Issue → Fix order the app uses.
 */
function RatingPreview() {
  const offset = CIRCUMFERENCE * (1 - SCORE / 100);

  return (
    <figure
      aria-label="Illustration of a Paddle Up rep score: 82, with one mechanic to fix next"
      className="relative mx-auto w-full max-w-[380px]"
    >
      <div className="hairline-card relative overflow-hidden p-6">
        <div className="flex items-center justify-between">
          <span className="micro">Forehand dink · Rep 24</span>
          <span className="flex items-center gap-1.5 rounded-full bg-lime/15 px-2.5 py-1 text-[11px] font-semibold text-lime">
            <span className="h-1.5 w-1.5 rounded-full bg-lime" />
            Live
          </span>
        </div>

        <div className="relative mx-auto my-6 aspect-square w-[220px]">
          <svg viewBox="0 0 200 200" className="h-full w-full -rotate-90" aria-hidden>
            <circle cx="100" cy="100" r={RADIUS} fill="none" stroke="rgb(255 255 255 / 0.07)" strokeWidth="12" />
            <circle
              cx="100"
              cy="100"
              r={RADIUS}
              fill="none"
              stroke="hsl(var(--lime))"
              strokeWidth="12"
              strokeLinecap="round"
              strokeDasharray={CIRCUMFERENCE}
              strokeDashoffset={offset}
              className="drop-shadow-[0_0_10px_rgba(198,255,61,0.45)] motion-safe:animate-dial-fill"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-[76px] font-black leading-none tracking-tight tabular-nums text-fg-primary">
              {SCORE}
            </span>
            <span className="micro mt-2">Rep score</span>
          </div>
        </div>

        <div className="space-y-3">
          <div className="rounded-2xl border border-hairline bg-surface-raised p-4">
            <p className="micro text-[#FF5F52]">Main issue</p>
            <p className="mt-1.5 text-[15px] font-semibold text-fg-primary">Paddle face opens at contact</p>
          </div>
          <div className="rounded-2xl border border-lime/25 bg-lime/10 p-4">
            <p className="micro text-lime">Fix · next rep</p>
            <p className="mt-1.5 text-[15px] font-medium text-fg-primary">
              Keep the face square and lift from the legs, not the wrist.
            </p>
          </div>
        </div>
      </div>
    </figure>
  );
}

export default memo(RatingPreview);
