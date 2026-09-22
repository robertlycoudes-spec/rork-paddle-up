/**
 * Paddle Up Pro subscription entitlement.
 *
 * TEMPORARY — LOCAL ENTITLEMENT: no billing SDK is wired yet, so purchases
 * resolve against a locally stored entitlement. Everything else is production
 * shaped: gating rules, product catalogue and restore all flow through here,
 * so switching to real billing means replacing `purchase` / `restore` only.
 */

export interface SubscriptionProduct {
  id: string;
  title: string;
  price: string;
  period: string;
  subtitle?: string;
  badge?: string;
  /** Monthly-equivalent price, for the savings line. */
  monthlyEquivalent?: string;
}

export const monthlyProduct: SubscriptionProduct = {
  id: "paddleup_pro_monthly",
  title: "Monthly",
  price: "$9.99",
  period: "per month",
  subtitle: "Cancel anytime",
};

export const annualProduct: SubscriptionProduct = {
  id: "paddleup_pro_annual",
  title: "Annual",
  price: "$59.99",
  period: "per year",
  subtitle: "Billed once a year",
  badge: "Save 50%",
  monthlyEquivalent: "$5.00 / month",
};

export const allProducts: SubscriptionProduct[] = [annualProduct, monthlyProduct];

/** What the free tier allows before Pro is required. */
export const FREE_TIER_SESSIONS = 1;
export const FREE_TIER_HISTORY = 3;

export type ProFeature =
  | "unlimitedSessions"
  | "fullShotAnalysis"
  | "completeHistory"
  | "personalizedPlans"
  | "advancedTrends"
  | "swingMatch"
  | "advancedLiveCoaching";

export const proFeatures: { id: ProFeature; title: string; icon: string }[] = [
  {
    id: "unlimitedSessions",
    title: "Unlimited practice sessions",
    icon: "Infinity",
  },
  {
    id: "fullShotAnalysis",
    title: "Full shot analysis on every rep",
    icon: "Crosshair",
  },
  {
    id: "completeHistory",
    title: "Complete session & rep history",
    icon: "History",
  },
  {
    id: "personalizedPlans",
    title: "Personalised weekly practice plans",
    icon: "Calendar",
  },
  { id: "advancedTrends", title: "Advanced mechanic trends", icon: "TrendingUp" },
  {
    id: "swingMatch",
    title: "Swing Match & benchmark comparison",
    icon: "Users",
  },
  {
    id: "advancedLiveCoaching",
    title: "Advanced live audio coaching",
    icon: "AudioWaveform",
  },
];

const ENTITLEMENT_KEY = "app.paddleup.pro.entitlement";
const PRODUCT_KEY = "app.paddleup.pro.product";

export function readEntitlement(): { isPro: boolean; productID: string | null } {
  try {
    return {
      isPro: localStorage.getItem(ENTITLEMENT_KEY) === "true",
      productID: localStorage.getItem(PRODUCT_KEY),
    };
  } catch {
    return { isPro: false, productID: null };
  }
}

export function writeEntitlement(isPro: boolean, productID?: string): void {
  try {
    localStorage.setItem(ENTITLEMENT_KEY, String(isPro));
    if (isPro && productID) {
      localStorage.setItem(PRODUCT_KEY, productID);
    } else if (!isPro) {
      localStorage.removeItem(PRODUCT_KEY);
    }
  } catch {
    // Storage unavailable — entitlement stays in memory for this session.
  }
}

/** Whether the player may start another session. */
export function canStartSession(
  isPro: boolean,
  completedSessions: number,
): boolean {
  return isPro || completedSessions < FREE_TIER_SESSIONS;
}

export function sessionHistoryLimit(isPro: boolean): number | null {
  return isPro ? null : FREE_TIER_HISTORY;
}
