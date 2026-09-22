/**
 * Top-level routing: splash → onboarding → main tabs, with the practice flow
 * and detail screens layered on top.
 */

import { useEffect, useState } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes,
  useLocation,
} from "react-router-dom";

import { AppShell } from "@/components/pu/AppShell";
import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AppStateProvider, useAppState } from "@/state/AppStateProvider";
import { StoreProvider } from "@/state/StoreProvider";

import DrillDetail from "./pages/DrillDetail";
import Home from "./pages/Home";
import LivePractice from "./pages/LivePractice";
import MechanicDetail from "./pages/MechanicDetail";
import NotFound from "./pages/NotFound";
import Onboarding from "./pages/Onboarding";
import PaywallPage from "./pages/PaywallPage";
import Practice from "./pages/Practice";
import Profile from "./pages/Profile";
import Progress from "./pages/Progress";
import SessionSummary from "./pages/SessionSummary";
import Settings from "./pages/Settings";
import ShotDetail from "./pages/ShotDetail";
import { Splash } from "./pages/Splash";
import SwingMatch from "./pages/SwingMatch";
import WeeklyPlan from "./pages/WeeklyPlan";

const queryClient = new QueryClient();

/** Scrolls to the top whenever the route changes, like a native push. */
function ScrollToTop() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}

function Routed() {
  const { profile, isLoaded } = useAppState();
  const [showSplash, setShowSplash] = useState<boolean>(true);

  useEffect(() => {
    const timer = window.setTimeout(() => setShowSplash(false), 1100);
    return () => window.clearTimeout(timer);
  }, []);

  if (showSplash || !isLoaded) return <Splash />;

  // The whole app lives behind onboarding until the plan is built.
  if (!profile.hasCompletedOnboarding) {
    return (
      <Routes>
        <Route path="*" element={<Onboarding />} />
      </Routes>
    );
  }

  return (
    <Routes>
      {/* Full-bleed screens without the tab chrome. */}
      <Route path="/live" element={<LivePractice />} />
      <Route path="/paywall" element={<PaywallPage />} />

      <Route
        path="*"
        element={
          <AppShell>
            <Routes>
              <Route path="/" element={<Navigate to="/home" replace />} />
              <Route path="/home" element={<Home />} />
              <Route path="/practice" element={<Practice />} />
              <Route path="/progress" element={<Progress />} />
              <Route path="/profile" element={<Profile />} />
              <Route path="/settings" element={<Settings />} />
              <Route path="/plan" element={<WeeklyPlan />} />
              <Route path="/swing-match" element={<SwingMatch />} />
              <Route path="/drill/:drillID" element={<DrillDetail />} />
              <Route path="/shot/:shot" element={<ShotDetail />} />
              <Route path="/group/:group" element={<ShotDetail />} />
              <Route path="/session/:sessionID" element={<SessionSummary />} />
              <Route
                path="/mechanic/:mechanic/:group"
                element={<MechanicDetail />}
              />
              <Route path="*" element={<NotFound />} />
            </Routes>
          </AppShell>
        }
      />
    </Routes>
  );
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AppStateProvider>
      <StoreProvider>
        <TooltipProvider>
          <Toaster />
          <BrowserRouter
            future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
          >
            <ScrollToTop />
            <Routed />
          </BrowserRouter>
        </TooltipProvider>
      </StoreProvider>
    </AppStateProvider>
  </QueryClientProvider>
);

export default App;
