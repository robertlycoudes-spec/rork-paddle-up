/**
 * The brand marks.
 *
 * Two marks exist. `BallMark` is the lime pickleball on its own — a radially
 * symmetric mark whose visual centre is exactly its frame centre (the five
 * holes are evenly spaced, so they cancel out). Use it, never `BallGlyph`,
 * whenever the mark sits inside a ring, disc or circular container that must
 * share its centre. `BallGlyph` adds motion streaks and is for inline,
 * horizontal use only.
 */

import { memo } from "react";

interface MarkProps {
  size?: number;
  className?: string;
}

function BallMarkComponent({ size = 24, className }: MarkProps) {
  const holeSize = size * 0.15;
  const radius = size * 0.26;

  return (
    <div
      className={className}
      style={{ width: size, height: size, position: "relative" }}
      aria-hidden="true"
    >
      <div className="absolute inset-0 rounded-full bg-pu-lime" />
      {Array.from({ length: 5 }).map((_, index) => {
        const angle = (index / 5) * 2 * Math.PI;
        return (
          <div
            key={index}
            className="absolute rounded-full bg-pu-lime-ink/85"
            style={{
              width: holeSize,
              height: holeSize,
              left: size / 2 + Math.cos(angle) * radius - holeSize / 2,
              top: size / 2 + Math.sin(angle) * radius - holeSize / 2,
            }}
          />
        );
      })}
    </div>
  );
}

export const BallMark = memo(BallMarkComponent);

function BallGlyphComponent({ size = 24, className }: MarkProps) {
  const streakHeight = Math.max(1, size * 0.09);
  const streaks = [
    { width: size * 0.42, opacity: 0.85 },
    { width: size * 0.3, opacity: 0.6 },
    { width: size * 0.2, opacity: 0.35 },
  ];

  return (
    <div
      className={`flex items-center gap-[2px] ${className ?? ""}`}
      aria-hidden="true"
    >
      <div
        className="flex flex-col items-end"
        style={{ gap: size * 0.13 }}
      >
        {streaks.map((streak, index) => (
          <div
            key={index}
            className="rounded-full bg-pu-lime"
            style={{
              width: streak.width,
              height: streakHeight,
              opacity: streak.opacity,
            }}
          />
        ))}
      </div>
      <BallMark size={size} />
    </div>
  );
}

export const BallGlyph = memo(BallGlyphComponent);

/** Wordmark used in screen headers. */
export function Wordmark({ showsTagline = true }: { showsTagline?: boolean }) {
  return (
    <div className="flex flex-col items-start gap-[3px]">
      <div className="flex items-center gap-[9px]">
        <BallGlyph size={26} />
        <span className="text-[26px] font-black leading-none text-pu-primary">
          Paddle Up
        </span>
      </div>
      {showsTagline && (
        <span className="text-[11px] font-semibold uppercase tracking-[0.16em] text-pu-tertiary">
          Practice better · Play higher
        </span>
      )}
    </div>
  );
}
