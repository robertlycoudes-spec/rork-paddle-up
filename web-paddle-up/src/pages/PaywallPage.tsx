/** Standalone paywall, reached from gated actions across the app. */

import { useState } from "react";
import { useNavigate } from "react-router-dom";

import { Icon } from "@/components/pu/Icon";
import { PaywallPanel } from "@/components/pu/Paywall";
import { WelcomePremiumScreen } from "@/components/pu/WelcomePremium";
import { useAppState } from "@/state/AppStateProvider";
import { useStore } from "@/state/StoreProvider";

export default function PaywallPage() {
  const navigate = useNavigate();
  const store = useStore();
  const { profile } = useAppState();
  const [justPurchased, setJustPurchased] = useState<boolean>(false);

  // A successful purchase hands off to the full-screen welcome celebration
  // instead of bouncing straight back to wherever the paywall was opened.
  if (justPurchased) {
    return (
      <WelcomePremiumScreen
        firstName={profile.displayName || undefined}
        onContinue={() => navigate("/home", { replace: true })}
      />
    );
  }

  return (
    <div className="relative z-10 flex min-h-dvh flex-col">
      <div className="flex items-center justify-between px-5 pt-3">
        <button
          type="button"
          onClick={() => navigate(-1)}
          aria-label="Close"
          className="flex h-10 w-10 items-center justify-center rounded-full border border-pu-hairline bg-pu-surface text-pu-secondary transition-transform active:scale-95"
        >
          <Icon name="X" className="h-4 w-4" strokeWidth={2.6} />
        </button>
        <button
          type="button"
          onClick={() => void store.restore()}
          className="text-[13px] font-semibold text-pu-secondary transition-colors hover:text-pu-primary"
        >
          Restore
        </button>
      </div>

      <PaywallPanel
        headline="Unlock your full Paddle Up plan."
        onComplete={() => setJustPurchased(true)}
        onSkip={() => navigate(-1)}
        skipLabel="Not now"
      />
    </div>
  );
}
