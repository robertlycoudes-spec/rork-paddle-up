import { useEffect } from "react";
import { Link, NavLink, Outlet, useLocation } from "react-router-dom";

import { cn } from "@/lib/utils";
import { NAV_LINKS, SITE } from "@/lib/site";

function Wordmark() {
  return (
    <Link to="/" className="group flex items-center gap-2.5" aria-label={`${SITE.company} home`}>
      <span className="grid h-8 w-8 place-items-center rounded-[9px] bg-lime text-[13px] font-black tracking-tight text-lime-ink transition-transform group-hover:-rotate-6">
        R
      </span>
      <span className="flex items-baseline gap-2">
        <span className="text-[17px] font-extrabold tracking-tight text-fg-primary">RDL</span>
        <span className="micro hidden sm:inline">Development</span>
      </span>
    </Link>
  );
}

function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b border-hairline bg-canvas/75 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-5">
        <Wordmark />
        <nav aria-label="Primary" className="flex items-center gap-1">
          {NAV_LINKS.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.to === "/"}
              className={({ isActive }) =>
                cn(
                  "rounded-full px-3 py-2 text-[14px] font-medium transition-colors",
                  link.hideOnMobile && "hidden sm:inline-flex",
                  isActive ? "bg-surface-raised text-fg-primary" : "text-fg-secondary hover:text-fg-primary",
                )
              }
            >
              {link.label}
            </NavLink>
          ))}
        </nav>
      </div>
    </header>
  );
}

function SiteFooter() {
  return (
    <footer className="relative border-t border-hairline bg-canvas-deep/70">
      <div className="mx-auto grid max-w-6xl gap-10 px-5 py-12 md:grid-cols-[1.4fr_1fr_1fr]">
        <div className="space-y-3">
          <Wordmark />
          <p className="max-w-sm text-[14px] leading-relaxed text-fg-secondary">
            {SITE.product} is a product of {SITE.company}, an independent software company building focused tools
            for athletes.
          </p>
        </div>

        <div className="space-y-3">
          <p className="micro">Company</p>
          <ul className="space-y-2 text-[14px]">
            <li>
              <Link to="/support" className="text-fg-primary transition-colors hover:text-lime">
                Support
              </Link>
            </li>
            <li>
              <Link to="/privacy" className="text-fg-primary transition-colors hover:text-lime">
                Privacy Policy
              </Link>
            </li>
            <li>
              <Link to="/terms" className="text-fg-primary transition-colors hover:text-lime">
                Terms of Use
              </Link>
            </li>
          </ul>
        </div>

        <div className="space-y-3">
          <p className="micro">Contact</p>
          <a href={`mailto:${SITE.supportEmail}`} className="block break-all text-[14px] text-fg-primary hover:text-lime">
            {SITE.supportEmail}
          </a>
          <p className="text-[13px] text-fg-tertiary">{SITE.responseTime}</p>
        </div>
      </div>

      <div className="border-t border-hairline">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-5 py-6 text-[12px] text-fg-tertiary sm:flex-row sm:items-center sm:justify-between">
          <p>
            © {SITE.copyrightYear} {SITE.company}. All rights reserved.
          </p>
          <p>Apple, iPhone and App Store are trademarks of Apple Inc.</p>
        </div>
      </div>
    </footer>
  );
}

/** Shared chrome for every page: atmosphere, sticky header, footer. */
export default function SiteLayout() {
  const { pathname } = useLocation();

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return (
    <div className="relative flex min-h-screen flex-col overflow-x-clip">
      <div aria-hidden className="atmosphere pointer-events-none fixed inset-0 -z-10" />
      <SiteHeader />
      <main className="relative flex-1">
        <Outlet />
      </main>
      <SiteFooter />
    </div>
  );
}
