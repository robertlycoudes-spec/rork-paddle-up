import { ArrowRight, Cpu, LifeBuoy, ShieldCheck, Target } from "lucide-react";
import { Link } from "react-router-dom";

import RatingPreview from "@/components/site/RatingPreview";
import { usePageTitle } from "@/hooks/use-page-title";
import { SITE } from "@/lib/site";

const PILLARS = [
  {
    icon: Target,
    label: "Scored reps",
    text: "Every rep gets a 1–100 score and the one thing to fix next.",
  },
  {
    icon: Cpu,
    label: "On-device",
    text: "Your iPhone does the analysis. Practice video is never uploaded.",
  },
  {
    icon: ShieldCheck,
    label: "Private",
    text: "No ads, no data sales. Delete your data at any time.",
  },
] as const;

export default function Home() {
  usePageTitle();

  return (
    <>
      <section className="mx-auto grid max-w-6xl items-center gap-14 px-5 pb-20 pt-14 sm:pt-20 lg:grid-cols-[1.15fr_1fr] lg:gap-10 lg:pb-28">
        <div className="motion-safe:animate-rise-in">
          <p className="micro">{SITE.company}</p>

          <div className="mt-8 flex items-center gap-4">
            <img
              src="/paddle-up-mark.png"
              alt=""
              width={64}
              height={64}
              className="h-16 w-16 rounded-[18px] border border-hairline"
            />
            <div>
              <p className="micro text-lime">Our product</p>
              <p className="text-[22px] font-bold tracking-tight text-fg-primary">{SITE.product}</p>
            </div>
          </div>

          <h1 className="mt-6 text-[44px] font-extrabold leading-[1.02] tracking-[-0.03em] text-fg-primary sm:text-[64px]">
            Practice with purpose.
            <br />
            <span className="text-lime">Every rep counts.</span>
          </h1>

          <p className="mt-6 max-w-xl text-[17px] leading-relaxed text-fg-secondary">
            {SITE.product} is an AI pickleball practice coach for iPhone. Set your phone up courtside and it watches
            your practice session, picks out every swing and analyzes your mechanics: paddle face, contact point,
            footwork and follow-through. After each rep you get a score and one clear fix, plus a practice plan built
            around your level, so you improve rep by rep.
          </p>

          <div className="mt-9 flex flex-wrap items-center gap-3">
            <Link
              to="/support"
              className="group inline-flex h-12 items-center gap-2 rounded-full bg-lime px-6 text-[15px] font-bold text-lime-ink transition-transform active:scale-[0.97]"
            >
              Get support
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" aria-hidden />
            </Link>
            <Link
              to="/privacy"
              className="inline-flex h-12 items-center rounded-full border border-hairline bg-surface px-6 text-[15px] font-semibold text-fg-primary transition-colors hover:bg-surface-raised"
            >
              How we handle your data
            </Link>
          </div>
        </div>

        <div className="relative motion-safe:animate-rise-in [animation-delay:120ms]">
          <div
            aria-hidden
            className="absolute left-1/2 top-1/2 -z-10 h-[420px] w-[420px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-lime/[0.07] blur-3xl"
          />
          <RatingPreview />
        </div>
      </section>

      <section aria-label={`What ${SITE.product} does`} className="border-y border-hairline bg-canvas-deep/50">
        <div className="mx-auto grid max-w-6xl divide-y divide-hairline px-5 sm:grid-cols-3 sm:divide-x sm:divide-y-0">
          {PILLARS.map(({ icon: Icon, label, text }) => (
            <div key={label} className="flex gap-4 py-8 sm:px-8 sm:first:pl-0 sm:last:pr-0">
              <Icon className="mt-0.5 h-5 w-5 flex-none text-lime" aria-hidden />
              <div>
                <p className="micro">{label}</p>
                <p className="mt-2 text-[15px] leading-relaxed text-fg-primary">{text}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-5 py-20 lg:py-24">
        <div className="hairline-card flex flex-col gap-6 p-8 sm:flex-row sm:items-center sm:justify-between sm:p-10">
          <div className="flex items-start gap-4">
            <span className="grid h-11 w-11 flex-none place-items-center rounded-full bg-lime/15">
              <LifeBuoy className="h-5 w-5 text-lime" aria-hidden />
            </span>
            <div>
              <p className="text-[20px] font-bold tracking-tight text-fg-primary">About {SITE.company}</p>
              <p className="mt-2 max-w-xl text-[15px] leading-relaxed text-fg-secondary">
                We're a small, independent studio that builds focused software for athletes. Questions, feedback or
                business enquiries? Email us.
              </p>
            </div>
          </div>
          <a
            href={`mailto:${SITE.supportEmail}`}
            className="inline-flex h-12 flex-none items-center justify-center rounded-full border border-lime/30 px-6 text-[15px] font-semibold text-lime transition-colors hover:bg-lime/10"
          >
            {SITE.supportEmail}
          </a>
        </div>
      </section>
    </>
  );
}
