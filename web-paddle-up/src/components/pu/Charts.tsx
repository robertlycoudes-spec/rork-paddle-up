/**
 * Flat, hairline-driven charts: the weekly trend line, mechanic sparklines,
 * and the six-axis onboarding skill radar. No gradients beyond the single
 * trend fill the iOS app also uses.
 */

import { memo, useEffect, useState } from "react";

import { Card } from "@/components/pu/Primitives";

export interface TrendPoint {
  label: string;
  score: number;
}

/** Labelled line chart used for the weekly rating trend. */
function TrendChartComponent({
  points,
  height = 150,
}: {
  points: TrendPoint[];
  height?: number;
}) {
  if (points.length < 2) return null;

  const width = 320;
  const chartHeight = height - 22;
  const values = points.map((point) => point.score);
  const minValue = Math.max(0, Math.min(...values) - 12);
  const maxValue = Math.min(100, Math.max(...values) + 12);
  const span = Math.max(1, maxValue - minValue);
  const step = width / (values.length - 1);

  const pointAt = (index: number) => ({
    x: index * step,
    y: chartHeight * (1 - (values[index] - minValue) / span),
  });

  const linePath = values
    .map((_, index) => {
      const { x, y } = pointAt(index);
      return `${index === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(" ");

  const areaPath = `M0 ${chartHeight} ${values
    .map((_, index) => {
      const { x, y } = pointAt(index);
      return `L${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(" ")} L${width} ${chartHeight} Z`;

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="w-full overflow-visible"
      style={{ height }}
      preserveAspectRatio="none"
    >
      <defs>
        <linearGradient id="pu-trend-fill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#C6FF3D" stopOpacity="0.25" />
          <stop offset="100%" stopColor="#C6FF3D" stopOpacity="0" />
        </linearGradient>
      </defs>

      {[0, 1, 2].map((line) => (
        <line
          key={line}
          x1={0}
          x2={width}
          y1={(chartHeight * line) / 2}
          y2={(chartHeight * line) / 2}
          stroke="rgba(255,255,255,0.08)"
          strokeWidth={1}
          vectorEffect="non-scaling-stroke"
        />
      ))}

      <path d={areaPath} fill="url(#pu-trend-fill)" />
      <path
        d={linePath}
        fill="none"
        stroke="#C6FF3D"
        strokeWidth={2.5}
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
      />

      {values.map((value, index) => {
        const { x, y } = pointAt(index);
        return (
          <g key={points[index].label}>
            <circle cx={x} cy={y} r={4} fill="#C6FF3D" />
            <text
              x={x}
              y={Math.max(9, y - 12)}
              textAnchor="middle"
              className="pu-tabular"
              fill="#F4F7F2"
              fontSize={11}
              fontWeight={700}
            >
              {Math.round(value)}
            </text>
            <text
              x={x}
              y={height - 4}
              textAnchor="middle"
              fill="#5E6760"
              fontSize={10}
            >
              {points[index].label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

export const TrendChart = memo(TrendChartComponent);

/** Compact sparkline for a single mechanic's recent history. */
function SparklineComponent({ points }: { points: number[] }) {
  if (points.length < 2) {
    return <div className="h-[34px] flex-1" />;
  }

  const width = 120;
  const height = 34;
  const min = Math.min(...points);
  const max = Math.max(...points);
  const span = Math.max(1, max - min);
  const step = width / (points.length - 1);

  const path = points
    .map((value, index) => {
      const x = index * step;
      const y = height - 4 - ((value - min) / span) * (height - 8);
      return `${index === 0 ? "M" : "L"}${x.toFixed(1)} ${y.toFixed(1)}`;
    })
    .join(" ");

  const last = points[points.length - 1];
  const lastY = height - 4 - ((last - min) / span) * (height - 8);

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="h-[34px] flex-1"
      preserveAspectRatio="none"
    >
      <path
        d={path}
        fill="none"
        stroke="#C6FF3D"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
      />
      <circle cx={width} cy={lastY} r={2.5} fill="#C6FF3D" />
    </svg>
  );
}

export const Sparkline = memo(SparklineComponent);

export interface RadarAxis {
  label: string;
  /** 0...1 relative skill level. */
  value: number;
}

/**
 * Six-axis skill radar for the onboarding story slides. Flat lime polygon,
 * hairline hexagon grid, alert dots for weak axes — grows from the centre on
 * appear so the chart feels measured, not static.
 */
function RadarChartComponent({
  axes,
  caption,
  showsLegend = false,
}: {
  axes: RadarAxis[];
  caption: string;
  showsLegend?: boolean;
}) {
  const [progress, setProgress] = useState<number>(0);

  useEffect(() => {
    const timer = window.setTimeout(() => setProgress(1), 150);
    return () => window.clearTimeout(timer);
  }, []);

  const size = 290;
  const radius = 84;
  const center = size / 2;
  // Axes below this level read as "needs work" — mirrors the score ramp's 60.
  const solidThreshold = 0.6;

  const pointAt = (index: number, fraction: number) => {
    const angle = ((index * 60 - 90) * Math.PI) / 180;
    return {
      x: center + Math.cos(angle) * radius * fraction,
      y: center + Math.sin(angle) * radius * fraction,
    };
  };

  const polygon = (fractions: number[]) =>
    fractions
      .map((fraction, index) => {
        const { x, y } = pointAt(index, fraction);
        return `${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(" ");

  return (
    <Card>
      <div className="flex flex-col items-center gap-4">
        <svg
          width={size}
          height={size}
          className="max-w-full"
          role="img"
          aria-label={`Skill radar: ${axes
            .map((axis) => `${axis.label} ${Math.round(axis.value * 100)} percent`)
            .join(", ")}`}
        >
          {[0.33, 0.66, 1].map((fraction) => (
            <polygon
              key={fraction}
              points={polygon(Array(6).fill(fraction))}
              fill="none"
              stroke="rgba(255,255,255,0.08)"
              strokeWidth={1}
            />
          ))}
          {Array.from({ length: 6 }).map((_, index) => {
            const { x, y } = pointAt(index, 1);
            return (
              <line
                key={index}
                x1={center}
                y1={center}
                x2={x}
                y2={y}
                stroke="rgba(255,255,255,0.08)"
                strokeWidth={1}
              />
            );
          })}

          <g
            style={{
              transform: `scale(${progress})`,
              transformOrigin: `${center}px ${center}px`,
              transition: "transform 0.85s cubic-bezier(0.2, 0.8, 0.2, 1)",
            }}
          >
            <polygon
              points={polygon(axes.map((axis) => axis.value))}
              fill="rgba(198,255,61,0.16)"
              stroke="#C6FF3D"
              strokeWidth={2}
              strokeLinejoin="round"
            />
          </g>

          {axes.map((axis, index) => {
            const { x, y } = pointAt(index, axis.value);
            return (
              <circle
                key={axis.label}
                cx={x}
                cy={y}
                r={5.5}
                fill={axis.value >= solidThreshold ? "#C6FF3D" : "#FF5F52"}
                stroke="#0B0F0C"
                strokeWidth={2}
                style={{
                  transform: `scale(${progress})`,
                  transformOrigin: `${center}px ${center}px`,
                  transition: `transform 0.4s cubic-bezier(0.2, 1.4, 0.4, 1) ${
                    0.35 + index * 0.07
                  }s`,
                }}
              />
            );
          })}

          {axes.map((axis, index) => {
            const { x, y } = pointAt(index, (radius + 34) / radius);
            return (
              <text
                key={`${axis.label}-label`}
                x={x}
                y={y}
                textAnchor="middle"
                dominantBaseline="middle"
                fill="#8C968D"
                fontSize={13}
                fontWeight={500}
              >
                {axis.label}
              </text>
            );
          })}
        </svg>

        <p
          className="text-center text-[15px] font-medium text-pu-secondary transition-opacity duration-500"
          style={{ opacity: progress }}
        >
          {caption}
        </p>

        {showsLegend && (
          <div
            className="flex items-center gap-[18px] text-[13px] font-medium text-pu-secondary transition-opacity duration-500"
            style={{ opacity: progress }}
          >
            <span className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-full bg-pu-alert" />
              Needs work
            </span>
            <span className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-full bg-pu-lime" />
              Solid
            </span>
          </div>
        )}
      </div>
    </Card>
  );
}

export const RadarChart = memo(RadarChartComponent);
