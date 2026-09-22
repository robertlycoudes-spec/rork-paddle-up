/**
 * The main app chrome: a bottom tab bar on phones, a left rail on wider
 * screens, with the lime accent marking the active tab.
 */

import { NavLink, useLocation } from "react-router-dom";
import type { ReactNode } from "react";

import { Icon } from "@/components/pu/Icon";
import { Wordmark } from "@/components/pu/BallMark";
import { cn } from "@/lib/utils";

const tabs: { to: string; label: string; icon: string }[] = [
  { to: "/home", label: "Home", icon: "House" },
  { to: "/practice", label: "Practice", icon: "Dumbbell" },
  { to: "/progress", label: "Progress", icon: "ChartColumn" },
  { to: "/profile", label: "Profile", icon: "User" },
];

export function AppShell({ children }: { children: ReactNode }) {
  const location = useLocation();

  return (
    <div className="relative z-10 flex min-h-dvh">
      {/* Left rail on desktop — the tab bar's wide-screen form. */}
      <aside className="sticky top-0 hidden h-dvh w-60 shrink-0 flex-col gap-1 border-r border-pu-hairline px-4 py-6 lg:flex">
        <div className="px-2 pb-6">
          <Wordmark />
        </div>
        {tabs.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            className={({ isActive }) =>
              cn(
                "flex items-center gap-3 rounded-pu-tile px-3 py-3 text-[15px] font-semibold transition-colors",
                isActive
                  ? "bg-pu-lime/[0.12] text-pu-lime"
                  : "text-pu-secondary hover:bg-white/[0.04] hover:text-pu-primary",
              )
            }
          >
            <Icon name={tab.icon} className="h-[18px] w-[18px]" strokeWidth={2.2} />
            {tab.label}
          </NavLink>
        ))}
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <main className="flex-1 pb-24 lg:pb-8">{children}</main>

        {/* Bottom tab bar on phones and tablets. */}
        <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-pu-hairline bg-pu-canvas/85 backdrop-blur-xl lg:hidden">
          <div className="mx-auto flex w-full max-w-xl items-stretch">
            {tabs.map((tab) => {
              const isActive = location.pathname.startsWith(tab.to);
              return (
                <NavLink
                  key={tab.to}
                  to={tab.to}
                  className="flex flex-1 flex-col items-center gap-1 py-2.5"
                >
                  <Icon
                    name={tab.icon}
                    className={cn(
                      "h-[22px] w-[22px] transition-colors",
                      isActive ? "text-pu-lime" : "text-pu-secondary",
                    )}
                    strokeWidth={isActive ? 2.6 : 2}
                  />
                  <span
                    className={cn(
                      "text-[10px] font-semibold transition-colors",
                      isActive ? "text-pu-lime" : "text-pu-secondary",
                    )}
                  >
                    {tab.label}
                  </span>
                </NavLink>
              );
            })}
          </div>
        </nav>
      </div>
    </div>
  );
}

/** Shared page frame: standard margins and a max width that matches iOS. */
export function Screen({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("mx-auto w-full max-w-xl px-5 py-4", className)}>
      {children}
    </div>
  );
}

/** Header used by Home and Profile: wordmark plus a settings button. */
export function ScreenHeader({ onSettings }: { onSettings: () => void }) {
  return (
    <div className="flex items-start justify-between pt-2">
      <Wordmark />
      <button
        type="button"
        onClick={onSettings}
        aria-label="Settings"
        className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-pu-hairline bg-pu-surface text-pu-primary transition-transform active:scale-95 hover:bg-pu-raised"
      >
        <Icon name="Settings" className="h-[17px] w-[17px]" strokeWidth={2.2} />
      </button>
    </div>
  );
}

/** Title header for the list-style tabs. */
export function TitleHeader({
  title,
  subtitle,
}: {
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="flex flex-col gap-2 pt-2">
      <h1 className="text-[34px] font-black leading-tight text-pu-primary">
        {title}
      </h1>
      {subtitle && (
        <p className="text-[15px] font-medium leading-relaxed text-pu-secondary">
          {subtitle}
        </p>
      )}
    </div>
  );
}
