/** Splash: ball glyph + wordmark, springs in, hands off after ~1.1s. */

import { BallGlyph } from "@/components/pu/BallMark";

export function Splash() {
  return (
    <div className="relative z-10 flex min-h-dvh flex-col items-center justify-center gap-[18px]">
      <div className="animate-pu-rise-lg">
        <BallGlyph size={62} />
      </div>
      <div
        className="animate-pu-rise flex flex-col items-center gap-1.5"
        style={{ animationDelay: "0.1s" }}
      >
        <span className="text-[34px] font-black text-pu-primary">Paddle Up</span>
        <span className="text-[11px] font-semibold uppercase tracking-[0.2em] text-pu-tertiary">
          Practice better · Play higher
        </span>
      </div>
    </div>
  );
}
