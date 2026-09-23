/**
 * The evaluation flow: the hook, twelve quick questions, two radar story
 * slides, a staged "AI analysis", the personalised game plan, and the paywall
 * as its natural conclusion. Answers are saved after every selection so
 * nothing is lost if the tab is closed mid-flow.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { Icon } from "@/components/pu/Icon";
import {
  AdvantageCard,
  AnalyzingScreen,
  CoachGreetingPreview,
  HeroCard,
  NameField,
  PromiseRow,
  QuestionHeader,
  QuestionScreen,
  SelectionRow,
} from "@/components/pu/Onboarding";
import { RadarChart, type RadarAxis } from "@/components/pu/Charts";
import {
  Card,
  IconBadge,
  MicroLabel,
  PrimaryButton,
} from "@/components/pu/Primitives";
import { PaywallPanel } from "@/components/pu/Paywall";
import { WelcomePremiumScreen } from "@/components/pu/WelcomePremium";
import {
  emptyAnswers,
  generateGamePlan,
  type OnboardingAnswers,
} from "@/lib/pu/game-plan";
import {
  biggestStruggles,
  duprRanges,
  playFrequencies,
  playerStyles,
  practiceDaysPerWeek,
  successMetrics,
  trainingGoals,
  weeklyTrainingTimes,
} from "@/lib/pu/profile";
import { cn } from "@/lib/utils";
import { useAppState } from "@/state/AppStateProvider";

type Step =
  | "hook"
  | "name"
  | "level"
  | "playerType"
  | "frequency"
  | "goals"
  | "struggles"
  | "radarGaps"
  | "radarPath"
  | "time"
  | "advantage"
  | "successMetric"
  | "analyzing"
  | "plan"
  | "paywall"
  | "welcome";

/** The counted question screens, in order. */
const questionSteps: Step[] = [
  "name",
  "level",
  "playerType",
  "frequency",
  "goals",
  "struggles",
  "radarGaps",
  "radarPath",
  "time",
  "advantage",
  "successMetric",
];

const nextStep: Record<Step, Step | null> = {
  hook: "name",
  name: "level",
  level: "playerType",
  playerType: "frequency",
  frequency: "goals",
  goals: "struggles",
  struggles: "radarGaps",
  radarGaps: "radarPath",
  radarPath: "time",
  time: "advantage",
  advantage: "successMetric",
  successMetric: "analyzing",
  analyzing: null, // the analyzing screen advances itself
  plan: "paywall",
  paywall: "welcome", // a successful purchase leads into the welcome screen
  welcome: null, // completion routes out of onboarding
};

/** Skill map with visible gaps — the honest baseline. */
const gapAxes: RadarAxis[] = [
  { label: "Dinking", value: 0.62 },
  { label: "Drops", value: 0.45 },
  { label: "Drives", value: 0.8 },
  { label: "Volleys", value: 0.5 },
  { label: "Serves", value: 0.72 },
  { label: "Footwork", value: 0.4 },
];

/** The same map fully developed — the promise the plan works toward. */
const fullAxes: RadarAxis[] = [
  { label: "Dinking", value: 0.95 },
  { label: "Drops", value: 0.9 },
  { label: "Drives", value: 0.93 },
  { label: "Volleys", value: 0.9 },
  { label: "Serves", value: 0.92 },
  { label: "Footwork", value: 0.9 },
];

const promises: { index: string; icon: string; title: string; detail: string }[] =
  [
    {
      index: "01",
      icon: "Target",
      title: "Daily training, built for you",
      detail:
        "Drills that attack your weak spots — chosen from your own answers.",
    },
    {
      index: "02",
      icon: "Brain",
      title: "Think the game",
      detail: "Court-craft lessons pulled from real pickleball situations.",
    },
    {
      index: "03",
      icon: "ScanFace",
      title: "Every rep, scored",
      detail:
        "Your camera spots each rep hands-free and scores its mechanics 1–100.",
    },
    {
      index: "04",
      icon: "AudioWaveform",
      title: "Your AI coach, 24/7",
      detail: "One fix at a time, spoken between reps — tuned to your game.",
    },
  ];

function toggleValue<T>(list: T[], value: T, max?: number): T[] {
  if (list.includes(value)) return list.filter((item) => item !== value);
  if (max !== undefined && list.length >= max) return list;
  return [...list, value];
}

export default function Onboarding() {
  const { profile, saveOnboardingDraft, completeOnboarding } = useAppState();

  const [step, setStep] = useState<Step>("hook");
  const [answers, setAnswers] = useState<OnboardingAnswers>(() => emptyAnswers());
  // Single-select mirrors stay null on a fresh run so no option looks
  // pre-picked and NEXT only appears after a real tap.
  const [answeredSteps, setAnsweredSteps] = useState<Set<Step>>(
    () => new Set<Step>(),
  );
  const hydrated = useRef<boolean>(false);

  /** Restores a partially-completed flow so answers survive a reload. */
  useEffect(() => {
    if (hydrated.current) return;
    hydrated.current = true;
    setAnswers((current) => ({
      ...current,
      name: profile.displayName,
      playerTypes: profile.playerTypes,
      goals: profile.goals,
      struggles: profile.struggles,
      successMetric: profile.successMetric,
      duprRange: profile.duprRange,
      ...(profile.hasCompletedOnboarding
        ? {
            frequency: profile.frequency,
            trainingTime: profile.trainingTime,
          }
        : {}),
    }));
    const answered = new Set<Step>();
    if (profile.duprRange) answered.add("level");
    if (profile.hasCompletedOnboarding) {
      answered.add("name");
      answered.add("frequency");
      answered.add("time");
    }
    setAnsweredSteps(answered);
  }, [profile]);

  const questionIndex = questionSteps.indexOf(step);
  const isQuestion = questionIndex >= 0;

  const commit = useCallback(
    (next: OnboardingAnswers, markAnswered?: Step) => {
      setAnswers(next);
      if (markAnswered) {
        setAnsweredSteps((current) => new Set(current).add(markAnswered));
      }
      saveOnboardingDraft(next);
    },
    [saveOnboardingDraft],
  );

  const advance = useCallback(() => {
    const next = nextStep[step];
    if (next) setStep(next);
  }, [step]);

  const goBack = useCallback(() => {
    if (questionIndex <= 0) {
      setStep("hook");
      return;
    }
    setStep(questionSteps[questionIndex - 1]);
  }, [questionIndex]);

  const plan = useMemo(
    () => (step === "plan" ? generateGamePlan(answers) : null),
    [step, answers],
  );

  return (
    <div className="relative z-10 flex min-h-dvh flex-col">
      {isQuestion && (
        <QuestionHeader
          index={questionIndex}
          total={questionSteps.length}
          onBack={goBack}
        />
      )}

      <div key={step} className="flex min-h-0 flex-1 animate-pu-fade flex-col">
        {step === "hook" && <HookScreen onStart={advance} />}

        {step === "name" && (
          <QuestionScreen
            title="What's your name?"
            subtitle="Your coach uses it to personalise your sessions."
            eyebrow="LET'S BEGIN"
            canContinue={answers.name.trim().length > 0}
            onContinue={advance}
          >
            <NameField
              value={answers.name}
              onChange={(name) => commit({ ...answers, name })}
            />
            <CoachGreetingPreview name={answers.name} />
          </QuestionScreen>
        )}

        {step === "level" && (
          <QuestionScreen
            title="What's your level?"
            subtitle="Know your DUPR? Pick the range it falls in. If not, pick the description that fits best."
            eyebrow="YOUR BASELINE"
            canContinue={answeredSteps.has("level") && answers.duprRange !== undefined}
            onContinue={advance}
          >
            {duprRanges.map((range) => (
              <SelectionRow
                key={range.id}
                title={`${range.rangeLabel}  ·  ${range.displayName}`}
                detail={range.detail}
                isSelected={answeredSteps.has("level") && answers.duprRange === range.id}
                onSelect={() => commit({ ...answers, duprRange: range.id }, "level")}
              />
            ))}
          </QuestionScreen>
        )}

        {step === "playerType" && (
          <QuestionScreen
            title="What type of player are you?"
            subtitle="Pick up to 3 — your coach balances your plan across them."
            eyebrow="YOUR IDENTITY"
            canContinue={answers.playerTypes.length > 0}
            onContinue={advance}
          >
            {playerStyles.map((style) => (
              <SelectionRow
                key={style.id}
                title={style.displayName}
                icon={style.icon}
                isSelected={answers.playerTypes.includes(style.id)}
                onSelect={() =>
                  commit({
                    ...answers,
                    playerTypes: toggleValue(answers.playerTypes, style.id, 3),
                  })
                }
              />
            ))}
          </QuestionScreen>
        )}

        {step === "frequency" && (
          <QuestionScreen
            title="How often do you play?"
            subtitle="Your plan fits around your court time."
            eyebrow="YOUR ROUTINE"
            canContinue={answeredSteps.has("frequency")}
            onContinue={advance}
          >
            {playFrequencies.map((option) => (
              <SelectionRow
                key={option.id}
                title={option.displayName}
                isSelected={
                  answeredSteps.has("frequency") && answers.frequency === option.id
                }
                onSelect={() =>
                  commit({ ...answers, frequency: option.id }, "frequency")
                }
              />
            ))}
          </QuestionScreen>
        )}

        {step === "goals" && (
          <QuestionScreen
            title="What do you want to improve most?"
            subtitle="Pick as many as you like — your coach prioritises them."
            eyebrow="YOUR FOCUS"
            canContinue={answers.goals.length > 0}
            onContinue={advance}
          >
            {trainingGoals.map((goal) => (
              <SelectionRow
                key={goal.id}
                title={goal.displayName}
                icon={goal.icon}
                isSelected={answers.goals.includes(goal.id)}
                onSelect={() =>
                  commit({ ...answers, goals: toggleValue(answers.goals, goal.id) })
                }
              />
            ))}
          </QuestionScreen>
        )}

        {step === "struggles" && (
          <QuestionScreen
            title="What's holding your game back?"
            subtitle="Be honest — Paddle Up verifies these against your measured reps."
            eyebrow="HONEST CHECK"
            canContinue={answers.struggles.length > 0}
            onContinue={advance}
          >
            {biggestStruggles.map((struggle) => (
              <SelectionRow
                key={struggle.id}
                title={struggle.displayName}
                isSelected={answers.struggles.includes(struggle.id)}
                onSelect={() =>
                  commit({
                    ...answers,
                    struggles: toggleValue(answers.struggles, struggle.id),
                  })
                }
              />
            ))}
          </QuestionScreen>
        )}

        {step === "radarGaps" && (
          <QuestionScreen
            title="Find exactly what's holding you back"
            subtitle="Paddle Up measures every rep, so your plan targets the zones that actually cost you points."
            eyebrow="YOUR SKILL MAP"
            onContinue={advance}
          >
            <RadarChart
              axes={gapAxes}
              caption="Your plan finds your hidden gaps and turns them into strengths."
              showsLegend
            />
          </QuestionScreen>
        )}

        {step === "radarPath" && (
          <QuestionScreen
            title="Unlock your fastest path"
            subtitle="Your plan trains every skill that matters — not just the ones you already like."
            eyebrow="THE DESTINATION"
            onContinue={advance}
          >
            <RadarChart
              axes={fullAxes}
              caption="Paddle Up develops every skill area — not just your favorites."
            />
          </QuestionScreen>
        )}

        {step === "time" && (
          <QuestionScreen
            title="How much time can you train each week?"
            subtitle="We'll size your weekly plan to fit."
            eyebrow="YOUR WEEK"
            canContinue={answeredSteps.has("time")}
            onContinue={advance}
          >
            {weeklyTrainingTimes.map((option) => (
              <SelectionRow
                key={option.id}
                title={option.displayName}
                detail={`${practiceDaysPerWeek[option.id]} practice days a week`}
                isSelected={
                  answeredSteps.has("time") && answers.trainingTime === option.id
                }
                onSelect={() =>
                  commit({ ...answers, trainingTime: option.id }, "time")
                }
              />
            ))}
          </QuestionScreen>
        )}

        {step === "advantage" && (
          <QuestionScreen
            title="The advantage"
            subtitle="Players who train with a structured plan improve faster than players who go it alone."
            eyebrow="YOUR ADVANTAGE"
            onContinue={advance}
          >
            <AdvantageCard />
          </QuestionScreen>
        )}

        {step === "successMetric" && (
          <QuestionScreen
            title="What would make you say this app is working?"
            subtitle="Your coach measures progress the way you define it."
            eyebrow="THE FINISH LINE"
            canContinue={answers.successMetric !== undefined}
            onContinue={advance}
          >
            {successMetrics.map((option) => (
              <SelectionRow
                key={option.id}
                title={option.displayName}
                isSelected={answers.successMetric === option.id}
                onSelect={() => commit({ ...answers, successMetric: option.id })}
              />
            ))}
          </QuestionScreen>
        )}

        {step === "analyzing" && (
          <AnalyzingScreen
            firstName={answers.name}
            onDone={() => setStep("plan")}
          />
        )}

        {step === "plan" && plan && (
          <PlanScreen plan={plan} onContinue={advance} />
        )}

        {step === "paywall" && (
          <PaywallPanel
            headline="Your personalized game plan is ready."
            onComplete={() => setStep("welcome")}
            onSkip={() => completeOnboarding(answers)}
          />
        )}

        {step === "welcome" && (
          <WelcomePremiumScreen
            firstName={answers.name || undefined}
            onContinue={() => completeOnboarding(answers)}
          />
        )}
      </div>
    </div>
  );
}

/**
 * Opening slide: hero brand card with a stat strip, then four numbered promise
 * rows. CONTINUE stays disabled until the final promise row is half on screen;
 * a reading-progress stub doubles as the header bar.
 */
function HookScreen({ onStart }: { onStart: () => void }) {
  const [unlocked, setUnlocked] = useState<boolean>(false);
  const [pulsed, setPulsed] = useState<boolean>(false);
  const [scrollProgress, setScrollProgress] = useState<number>(0);
  const scrollRef = useRef<HTMLDivElement>(null);
  const lastPromiseRef = useRef<HTMLDivElement>(null);

  // Unlock when the last promise row is half visible — not at page bottom.
  useEffect(() => {
    const target = lastPromiseRef.current;
    if (!target) return;
    const observer = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (entry?.isIntersecting) {
          setUnlocked(true);
          setPulsed(true);
        }
      },
      { threshold: 0.5 },
    );
    observer.observe(target);
    return () => observer.disconnect();
  }, []);

  const handleScroll = useCallback(() => {
    const element = scrollRef.current;
    if (!element) return;
    const max = element.scrollHeight - element.clientHeight;
    if (max <= 40) {
      setScrollProgress(1);
      return;
    }
    setScrollProgress(Math.min(1, Math.max(0, element.scrollTop / max)));
  }, []);

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div
        ref={scrollRef}
        onScroll={handleScroll}
        className="flex-1 overflow-y-auto"
      >
        <div className="mx-auto w-full max-w-xl px-5 pb-8 pt-3">
          <div className="flex flex-col items-center gap-3">
            <span className="text-xs font-bold tracking-[0.24em] text-pu-primary">
              GETTING STARTED
            </span>
            <div className="h-1 w-full overflow-hidden rounded-full bg-white/[0.09]">
              <div
                className="h-full rounded-full bg-pu-lime transition-[width] duration-300 ease-out"
                style={{ width: `${Math.max(12, scrollProgress * 100)}%` }}
              />
            </div>
          </div>

          <div className="mt-3">
            <HeroCard />
          </div>

          <div className="mt-3 flex flex-col gap-3">
            {promises.map((promise, index) => (
              <div
                key={promise.index}
                ref={index === promises.length - 1 ? lastPromiseRef : undefined}
              >
                <PromiseRow
                  index={promise.index}
                  icon={promise.icon}
                  title={promise.title}
                  detail={promise.detail}
                  delay={0.15 + index * 0.07}
                />
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="pu-action-bar px-5 pb-3 pt-2.5">
        <div className="mx-auto flex w-full max-w-xl flex-col items-center gap-2.5">
          {!unlocked && (
            <div className="flex items-center gap-1.5 text-pu-tertiary">
              <Icon
                name="ChevronDown"
                className="h-2.5 w-2.5 animate-pu-hint"
                strokeWidth={3}
              />
              <span className="text-[11px] font-semibold uppercase tracking-[0.11em]">
                Scroll to meet your coach
              </span>
            </div>
          )}

          <div className="relative w-full">
            {/* One-shot expanding ring the moment CONTINUE unlocks. */}
            {pulsed && (
              <span className="pointer-events-none absolute inset-0 animate-pu-ring-pulse rounded-full border-2 border-pu-lime" />
            )}
            <PrimaryButton onClick={onStart} disabled={!unlocked}>
              CONTINUE
              <Icon name="ArrowRight" className="h-3.5 w-3.5" strokeWidth={3} />
            </PrimaryButton>
          </div>
        </div>
      </div>
    </div>
  );
}

/** The personalised result: biggest opportunity plus a this-week prescription. */
function PlanScreen({
  plan,
  onContinue,
}: {
  plan: ReturnType<typeof generateGamePlan>;
  onContinue: () => void;
}) {
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-xl animate-pu-rise px-5 pb-28 pt-6">
          <MicroLabel>Your game plan</MicroLabel>

          <div className="mt-4 flex flex-col gap-2.5">
            <span className="text-[17px] font-semibold text-pu-secondary">
              Your biggest opportunity:
            </span>
            <h2 className="text-[30px] font-black leading-tight text-pu-lime">
              {plan.opportunity}
            </h2>
            <p className="text-[15px] font-medium leading-relaxed text-pu-secondary">
              {plan.opportunityDetail}
            </p>
          </div>

          <div className="mt-6 flex items-center justify-between">
            <MicroLabel>This week</MicroLabel>
            <span className="pu-tabular text-[11px] font-semibold text-pu-tertiary">
              {plan.practiceDays} days · ~{plan.weeklyMinutes} min
            </span>
          </div>

          <Card className="mt-2.5" padding="px-4 py-1.5">
            {plan.items.map((item, index) => (
              <div key={item.id}>
                <div
                  className="flex animate-pu-rise items-center gap-3.5 py-3"
                  style={{ animationDelay: `${0.3 + index * 0.13}s` }}
                >
                  <IconBadge icon={item.icon} size={38} />
                  <span className="flex-1 text-[17px] font-semibold leading-snug text-pu-primary">
                    {item.title}
                  </span>
                  <span className="shrink-0 text-pu-primary">
                    <span className="pu-tabular text-[22px] font-black">
                      {item.amount}
                    </span>
                    <span className="ml-1 text-[11px] font-semibold">
                      {item.unit}
                    </span>
                  </span>
                </div>
                {index < plan.items.length - 1 && (
                  <div className="h-px w-full bg-pu-hairline" />
                )}
              </div>
            ))}
          </Card>

          <p className="mt-4 text-[13px] font-medium leading-relaxed text-pu-secondary">
            Your AI coach continuously adapts this plan based on your goals and
            measured progress — every rep sharpens it.
          </p>
        </div>
      </div>

      <div className="pu-action-bar px-5 pb-3 pt-2.5">
        <div className="mx-auto w-full max-w-xl">
          <PrimaryButton onClick={onContinue}>SEE MY FULL PLAN</PrimaryButton>
        </div>
      </div>
    </div>
  );
}
