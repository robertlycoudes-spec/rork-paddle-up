/**
 * Full-screen celebration shown immediately after a successful subscription.
 * The brand mark in counter-rotating orbit rings over a lime bloom, a one-shot
 * pulse ring on entrance, a pulsing "PREMIUM ACTIVE" chip, a staged reveal of
 * everything the plan just unlocked, and the way back into the app. Reuses the
 * hook's motion language — flat surfaces, hairlines, one lime fill.
 */

import { useState } from "react";

import { BallMark } from "@/components/pu/BallMark";
import { Icon } from "@/components/pu/Icon";
import { Card, PrimaryButton } from "@/components/pu/Primitives";
import { proFeatures } from "@/lib/pu/store";
import { cn } from "@/lib/utils";

export function WelcomePremiumScreen({
  firstName,
  onContinue,
}: {
  firstName?: string;
  onContinue: () => void;
}) {
  const [pulsed] = useState<boolean>(true);

  const subtitle = firstName
    ? `${firstName}, your plan is live and your coach is ready.`
    : "Your plan is live and your coach is ready.";

  return (
    <div className="relative z-10 flex min-h-dvh flex-col overflow-hidden">
      {/* Soft lime atmosphere behind the hero — depth, never a gradient fill. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-[46vh]"
        style={{
          background:
            "radial-gradient(ellipse 70% 55% at 50% 0%, rgba(198,255,61,0.07) 0%, transparent 70%)",
        }}
      />

      <div className="mx-auto flex w-full max-w-xl flex-1 flex-col items-center px-5 pb-10 pt-[8vh]">
        <PremiumGlyph pulsed={pulsed} />

        <div className="mt-7 flex animate-pu-rise flex-col items-center gap-3 text-center [animation-delay:0.25s]">
          <h1 className="text-[32px] font-black leading-tight text-pu-primary">
            Welcome to
            <br />
            PaddleUp <span className="text-pu-lime">Premium</span>
          </h1>
          <span className="h-[3px] w-[26px] rounded-full bg-pu-lime" />
          <p className="max-w-sm text-[15px] font-medium leading-relaxed text-pu-secondary">
            {subtitle}
          </p>
        </div>

        <div className="mt-5 flex animate-pu-fade items-center gap-1.5 rounded-full border border-pu-lime/20 bg-pu-lime/[0.08] px-3 py-1.5 [animation-delay:0.45s]">
          <span className="h-[5px] w-[5px] animate-pu-pulse rounded-full bg-pu-lime" />
          <span className="text-[10px] font-bold tracking-[0.2em] text-pu-lime">
            PREMIUM ACTIVE
          </span>
        </div>

        <div className="mt-9 w-full">
          <div className="flex animate-pu-rise items-center gap-2.5 [animation-delay:0.65s]">
            <span className="h-[2px] w-4 shrink-0 rounded-full bg-pu-lime" />
            <span className="shrink-0 text-[11px] font-bold tracking-[0.2em] text-pu-lime">
              UNLOCKED JUST NOW
            </span>
            <span className="h-px flex-1 bg-pu-hairline" />
          </div>

          <Card className="mt-3.5">
            <div className="flex flex-col gap-3.5">
              {proFeatures.map((feature, index) => (
                <div
                  key={feature.id}
                  className="flex animate-pu-rise items-center gap-3.5"
                  style={{ animationDelay: `${0.8 + index * 0.07}s` }}
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-pu-hairline bg-pu-lime/[0.14] text-pu-lime">
                    <Icon
                      name={feature.icon}
                      className="h-[17px] w-[17px]"
                      strokeWidth={2.2}
                    />
                  </div>
                  <span className="text-[15px] font-medium text-pu-primary">
                    {feature.title}
                  </span>
                </div>
              ))}
            </div>
          </Card>
        </div>

        <div className="mt-auto w-full pt-9">
          <PrimaryButton
            onClick={onContinue}
            className="animate-pu-rise [animation-delay:1.5s]"
          >
            START TRAINING
          </PrimaryButton>
          <p className="mt-2.5 animate-pu-fade text-center text-[11px] text-pu-tertiary [animation-delay:1.7s]">
            Membership active — manage or cancel any time.
          </p>
        </div>
      </div>
    </div>
  );
}

/**
 * The premium hero: symmetric ball mark in a raised disc, two counter-rotating
 * dashed orbit rings with pinned satellite dots, a faint lime bloom, and a
 * one-shot expanding pulse ring fired once on entrance. Every ring rotates
 * alone around its own centre so nothing wobbles.
 */
function PremiumGlyph({ pulsed }: { pulsed: boolean }) {
  return (
    <div className="relative flex h-[160px] w-[160px] animate-pu-rise-lg items-center justify-center">
      <div
        aria-hidden
        className="absolute inset-0 rounded-full"
        style={{
          background:
            "radial-gradient(circle, rgba(198,255,61,0.16) 0%, transparent 62%)",
        }}
      />

      {/* One-shot expanding pulse ring — the "unlocked" moment. */}
      <span
        aria-hidden
        className={cn(
          "absolute h-[150px] w-[150px] rounded-full border-2 border-pu-lime",
          pulsed && "animate-pu-ring-pulse",
        )}
        style={{ animationDelay: "0.5s", opacity: pulsed ? undefined : 0.55 }}
      />

      <div className="absolute h-[124px] w-[124px] animate-pu-spin rounded-full border border-dashed border-pu-lime/35" />
      <div className="absolute h-[106px] w-[106px] animate-pu-spin-reverse rounded-full border border-dashed border-pu-lime/[0.18]" />

      <span
        aria-hidden
        className="absolute h-[7px] w-[7px] rounded-full bg-pu-lime"
        style={{ transform: "translateX(-62px)" }}
      />
      <span
        aria-hidden
        className="absolute h-[5px] w-[5px] rounded-full bg-pu-lime/50"
        style={{ transform: "translateX(53px)" }}
      />

      <div className="absolute flex h-[84px] w-[84px] items-center justify-center rounded-full border border-pu-hairline bg-pu-raised" />
      <BallMark size={46} className="relative" />
    </div>
  );
}
