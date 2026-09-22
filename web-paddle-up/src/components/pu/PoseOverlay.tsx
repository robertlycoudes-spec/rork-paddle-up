/** Skeleton overlay drawn on top of the camera feed. */

import { memo } from "react";

import { jointPoint, poseBones, type PoseFrame } from "@/lib/pu/pose";

function PoseOverlayComponent({
  frame,
  color = "#C6FF3D",
  lineWidth = 3,
  jointRadius = 5,
  mirrored = true,
}: {
  frame: PoseFrame | null;
  color?: string;
  lineWidth?: number;
  jointRadius?: number;
  mirrored?: boolean;
}) {
  if (!frame) return null;

  const project = (point: { x: number; y: number }) => ({
    x: (mirrored ? 1 - point.x : point.x) * 100,
    y: point.y * 100,
  });

  return (
    <svg
      viewBox="0 0 100 100"
      preserveAspectRatio="none"
      className="pointer-events-none absolute inset-0 h-full w-full"
      aria-hidden="true"
    >
      {poseBones.map(([from, to]) => {
        const a = jointPoint(frame, from, 0.3);
        const b = jointPoint(frame, to, 0.3);
        if (!a || !b) return null;
        const start = project(a);
        const end = project(b);
        return (
          <line
            key={`${from}-${to}`}
            x1={start.x}
            y1={start.y}
            x2={end.x}
            y2={end.y}
            stroke={color}
            strokeWidth={lineWidth}
            strokeLinecap="round"
            vectorEffect="non-scaling-stroke"
            opacity={0.9}
          />
        );
      })}

      {Object.keys(frame.joints).map((key) => {
        const point = jointPoint(frame, key as never, 0.3);
        if (!point) return null;
        const projected = project(point);
        return (
          <circle
            key={key}
            cx={projected.x}
            cy={projected.y}
            r={jointRadius}
            fill={color}
            vectorEffect="non-scaling-stroke"
            style={{ transformBox: "fill-box" }}
          />
        );
      })}
    </svg>
  );
}

export const PoseOverlay = memo(PoseOverlayComponent);

/** Corner brackets that frame the player during setup and live practice. */
export function FramingBrackets({ isValid }: { isValid: boolean }) {
  const color = isValid ? "#C6FF3D" : "#FFB020";
  const corners = [
    "left-6 top-6 border-l-2 border-t-2 rounded-tl-xl",
    "right-6 top-6 border-r-2 border-t-2 rounded-tr-xl",
    "left-6 bottom-6 border-b-2 border-l-2 rounded-bl-xl",
    "right-6 bottom-6 border-b-2 border-r-2 rounded-br-xl",
  ];

  return (
    <div className="pointer-events-none absolute inset-0" aria-hidden="true">
      {corners.map((corner) => (
        <span
          key={corner}
          className={`absolute h-10 w-10 transition-colors duration-300 ${corner}`}
          style={{ borderColor: color }}
        />
      ))}
    </div>
  );
}
