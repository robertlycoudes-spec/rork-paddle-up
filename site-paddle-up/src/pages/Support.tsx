import { Clock, Mail } from "lucide-react";
import { Link } from "react-router-dom";

import { usePageTitle } from "@/hooks/use-page-title";
import { SITE } from "@/lib/site";

const QUICK_ANSWERS: ReadonlyArray<{ q: string; a: string }> = [
  {
    q: "How do I cancel my subscription?",
    a: "Subscriptions are billed by Apple. On your iPhone, open Settings → your name → Subscriptions → Paddle Up, then tap Cancel Subscription. You keep Pro until the end of the current billing period.",
  },
  {
    q: "I bought Pro but it isn't showing.",
    a: "In Paddle Up, open Settings and tap Restore purchases while signed in to the same Apple Account you used to subscribe.",
  },
  {
    q: "How do I redeem a code?",
    a: "Open Settings → Redeem Code. App Store offer codes open Apple's redemption sheet; friend codes go in the Friend code field and need a Paddle Up Cloud sign-in.",
  },
  {
    q: "How do I delete my data?",
    a: "Open Settings → Account → Delete all data. If you're signed in to Paddle Up Cloud, your cloud copy is deleted too. You can also email us and we'll delete it for you.",
  },
];

export default function Support() {
  usePageTitle("Support");

  return (
    <div className="mx-auto max-w-6xl px-5 pb-24 pt-14 sm:pt-20">
      <header className="max-w-3xl motion-safe:animate-rise-in">
        <p className="micro text-lime">{SITE.product} Support</p>
        <h1 className="mt-3 text-[40px] font-extrabold leading-[1.05] tracking-tight text-fg-primary sm:text-[56px]">
          How can we help?
        </h1>
        <p className="mt-5 text-[17px] leading-relaxed text-fg-secondary">
          For help with {SITE.product}, including your account, subscription, practice sessions or a bug, email our
          support team. A real person reads every message.
        </p>
      </header>

      <div className="mt-12 grid gap-4 lg:grid-cols-[1.2fr_1fr]">
        <div className="hairline-card relative overflow-hidden p-8 sm:p-10">
          <div aria-hidden className="absolute -right-24 -top-24 h-64 w-64 rounded-full bg-lime/[0.08] blur-3xl" />
          <span className="grid h-12 w-12 place-items-center rounded-full bg-lime">
            <Mail className="h-5 w-5 text-lime-ink" aria-hidden />
          </span>
          <p className="micro mt-7">Email support</p>
          <a
            href={`mailto:${SITE.supportEmail}?subject=${encodeURIComponent(`${SITE.product} support`)}`}
            className="mt-2 block break-all text-[26px] font-bold tracking-tight text-fg-primary transition-colors hover:text-lime sm:text-[32px]"
          >
            {SITE.supportEmail}
          </a>
          <p className="mt-6 flex items-center gap-2.5 text-[15px] text-fg-secondary">
            <Clock className="h-4 w-4 flex-none text-lime" aria-hidden />
            {SITE.responseTime}
          </p>
          <p className="mt-6 border-t border-hairline pt-6 text-[14px] leading-relaxed text-fg-tertiary">
            To help us fix things faster, include your iPhone model, your iOS version and the app version (find it on
            Paddle Up's App Store page under Version History), plus what you were doing when the problem happened.
          </p>
        </div>

        <div className="hairline-card p-8 sm:p-10">
          <p className="micro">Privacy requests</p>
          <p className="mt-3 text-[15px] leading-relaxed text-fg-secondary">
            To access, export or delete your data, email{" "}
            <a href={`mailto:${SITE.supportEmail}`} className="text-link break-all">
              {SITE.supportEmail}
            </a>{" "}
            with the subject "Privacy request". See our{" "}
            <Link to="/privacy" className="text-link">
              Privacy Policy
            </Link>{" "}
            for details.
          </p>
          <p className="micro mt-8">Legal</p>
          <p className="mt-3 text-[15px] leading-relaxed text-fg-secondary">
            Use of {SITE.product} is covered by our{" "}
            <Link to="/terms" className="text-link">
              Terms of Use
            </Link>
            .
          </p>
        </div>
      </div>

      <section aria-labelledby="quick-answers" className="mt-16 max-w-3xl">
        <h2 id="quick-answers" className="text-[24px] font-bold tracking-tight text-fg-primary">
          Quick answers
        </h2>
        <dl className="mt-6 divide-y divide-hairline border-y border-hairline">
          {QUICK_ANSWERS.map((item) => (
            <div key={item.q} className="py-6">
              <dt className="text-[16px] font-semibold text-fg-primary">{item.q}</dt>
              <dd className="mt-2 text-[15px] leading-relaxed text-fg-secondary">{item.a}</dd>
            </div>
          ))}
        </dl>
      </section>
    </div>
  );
}
