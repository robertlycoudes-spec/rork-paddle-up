import type { ReactNode } from "react";

import { SITE } from "@/lib/site";

export interface LegalSection {
  id: string;
  title: string;
  body: ReactNode;
}

interface LegalPageProps {
  eyebrow: string;
  title: string;
  intro: ReactNode;
  sections: ReadonlyArray<LegalSection>;
}

/** Long-form legal layout: dated header, sticky contents rail on desktop. */
export default function LegalPage({ eyebrow, title, intro, sections }: LegalPageProps) {
  return (
    <div className="mx-auto max-w-6xl px-5 pb-24 pt-14 sm:pt-20">
      <header className="max-w-3xl motion-safe:animate-rise-in">
        <p className="micro text-lime">{eyebrow}</p>
        <h1 className="mt-3 text-[40px] font-extrabold leading-[1.05] tracking-tight text-fg-primary sm:text-[56px]">
          {title}
        </h1>
        <p className="mt-5 inline-flex items-center gap-2 rounded-full border border-hairline bg-surface px-3.5 py-1.5 text-[13px] font-medium text-fg-primary">
          <span className="h-1.5 w-1.5 rounded-full bg-lime" aria-hidden />
          Last updated <time dateTime={SITE.legalLastUpdatedISO}>{SITE.legalLastUpdated}</time>
        </p>
        <div className="mt-6 space-y-4 text-[16px] leading-relaxed text-fg-secondary">{intro}</div>
      </header>

      <div className="mt-14 grid gap-12 lg:grid-cols-[220px_1fr]">
        <nav aria-label="On this page" className="hidden lg:block">
          <div className="sticky top-24">
            <p className="micro">On this page</p>
            <ol className="mt-4 space-y-2.5 border-l border-hairline">
              {sections.map((section, index) => (
                <li key={section.id}>
                  <a
                    href={`#${section.id}`}
                    className="-ml-px flex gap-2 border-l border-transparent pl-4 text-[13px] leading-snug text-fg-secondary transition-colors hover:border-lime hover:text-fg-primary"
                  >
                    <span className="tabular-nums text-fg-tertiary">{String(index + 1).padStart(2, "0")}</span>
                    {section.title}
                  </a>
                </li>
              ))}
            </ol>
          </div>
        </nav>

        <div className="max-w-3xl space-y-4">
          {sections.map((section, index) => (
            <section key={section.id} id={section.id} className="hairline-card scroll-mt-24 p-6 sm:p-8">
              <h2 className="flex items-baseline gap-3 text-[20px] font-bold tracking-tight text-fg-primary sm:text-[22px]">
                <span className="text-[13px] font-semibold tabular-nums text-lime">
                  {String(index + 1).padStart(2, "0")}
                </span>
                {section.title}
              </h2>
              <div className="legal-body mt-4 space-y-4 text-[15px] leading-[1.7] text-fg-secondary">{section.body}</div>
            </section>
          ))}
        </div>
      </div>
    </div>
  );
}

/** Bulleted list styled for legal copy. */
export function LegalList({ items }: { items: ReadonlyArray<ReactNode> }) {
  return (
    <ul className="space-y-2.5">
      {items.map((item, index) => (
        <li key={index} className="flex gap-3">
          <span className="mt-[0.7em] h-1.5 w-1.5 flex-none rounded-full bg-lime/70" aria-hidden />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}

/** Emphasised term inside legal copy. */
export function Strong({ children }: { children: ReactNode }) {
  return <strong className="font-semibold text-fg-primary">{children}</strong>;
}
