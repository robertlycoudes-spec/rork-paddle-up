/**
 * Resolves the lucide icon names stored alongside domain data (drills, goals,
 * plan items) into components, with a safe fallback.
 */

import * as Lucide from "lucide-react";
import { memo } from "react";

interface IconProps {
  name: string;
  className?: string;
  strokeWidth?: number;
}

type LucideIconComponent = React.ComponentType<{
  className?: string;
  strokeWidth?: number;
}>;

function IconComponent({ name, className, strokeWidth = 2 }: IconProps) {
  const icons = Lucide as unknown as Record<string, LucideIconComponent>;
  const Resolved = icons[name] ?? Lucide.Circle;
  return <Resolved className={className} strokeWidth={strokeWidth} />;
}

export const Icon = memo(IconComponent);
