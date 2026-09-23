/**
 * Single source for company details shown across the site.
 * Swap `supportEmail` once the real domain is live — every page reads it here.
 */
export const SITE = {
  company: "RDL Development LLC",
  companyShort: "RDL Development",
  product: "Paddle Up",
  supportEmail: "support@[DOMAIN]",
  responseTime: "We reply to every message within 1–2 business days.",
  legalLastUpdated: "September 23, 2026",
  legalLastUpdatedISO: "2026-09-23",
  copyrightYear: 2026,
} as const;

export const NAV_LINKS: ReadonlyArray<{ to: string; label: string; hideOnMobile?: boolean }> = [
  { to: "/", label: "Home", hideOnMobile: true },
  { to: "/support", label: "Support" },
  { to: "/privacy", label: "Privacy" },
  { to: "/terms", label: "Terms" },
];
