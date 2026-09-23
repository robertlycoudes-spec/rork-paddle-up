/**
 * Where ball and paddle metrics will live once Paddle Up can measure them.
 * Paddle Up tracks the body only today, so every value reads "Not yet
 * available" unless a real measurement is ever stored on the rep.
 */

import { Icon } from "@/components/pu/Icon";
import { Card, SectionHeader } from "@/components/pu/Primitives";
import type { RepRecord } from "@/lib/pu/profile";

function format(value: number | null | undefined, suffix: string, prefix = ""): string | null {
  return value === null || value === undefined ? null : `${prefix}${Math.round(value)}${suffix}`;
}

export function BallPaddleData({ rep }: { rep: RepRecord | null }) {
  const metrics = [
    { title: "Ball speed", icon: "Gauge", value: format(rep?.ballSpeedMPH, " mph") },
    { title: "Spin", icon: "RefreshCw", value: format(rep?.spinRPM, " rpm") },
    { title: "Paddle face angle", icon: "RotateCcwSquare", value: format(rep?.paddleFaceAngleDegrees, "°") },
    { title: "Contact timing", icon: "Timer", value: format(rep?.contactTimingPrecisionMS, " ms", "±") },
  ];

  return (
    <div className="flex flex-col gap-2.5">
      <SectionHeader title="Ball & paddle" />
      <Card padding="px-4 py-1.5">
        {metrics.map((metric, index) => (
          <div key={metric.title}>
            <div className="flex items-center gap-3 py-2.5">
              <Icon name={metric.icon} className="h-3.5 w-3.5 shrink-0 text-pu-tertiary" strokeWidth={2.2} />
              <span className="flex-1 text-[15px] font-medium text-pu-primary">{metric.title}</span>
              {metric.value ? (
                <span className="pu-tabular text-[15px] font-semibold text-pu-primary">{metric.value}</span>
              ) : (
                <span className="text-[13px] font-medium text-pu-tertiary">Not yet available</span>
              )}
            </div>
            {index < metrics.length - 1 && <div className="h-px bg-pu-hairline" />}
          </div>
        ))}
        <p className="pb-2.5 pt-1 text-[11px] leading-relaxed text-pu-tertiary">
          Paddle Up measures your body mechanics today. Ball and paddle tracking are on the way.
        </p>
      </Card>
    </div>
  );
}
