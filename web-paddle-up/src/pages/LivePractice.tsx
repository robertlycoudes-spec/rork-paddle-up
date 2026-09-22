/**
 * The signature screen: continuous camera with pose overlay on top, and the
 * most recent rep's Score → Main Issue → Fix → Next Focus stacked below.
 * A framing check runs first so the analyzer sees what it needs.
 */

import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";

import { Icon } from "@/components/pu/Icon";
import { FramingBrackets, PoseOverlay } from "@/components/pu/PoseOverlay";
import {
  Card,
  MicroLabel,
  PrimaryButton,
  SecondaryButton,
  scoreColor,
} from "@/components/pu/Primitives";
import { drillById } from "@/lib/pu/drills";
import { formatClock } from "@/lib/pu/format";
import {
  framingCoverage,
  hipCenter,
  jointPoint,
  meanConfidence,
  shoulderCenter,
  type PoseFrame,
} from "@/lib/pu/pose";
import type { SessionLength } from "@/lib/pu/persistence";
import type { SessionMode } from "@/lib/pu/profile";
import { shotName, type ShotType } from "@/lib/pu/shots";
import { stopSpeaking } from "@/lib/pu/voice";
import { cn } from "@/lib/utils";
import {
  usePracticeEngine,
  type PracticeConfiguration,
} from "@/state/usePracticeEngine";
import { sessionLengthName } from "@/lib/pu/persistence";

interface SetupCheck {
  id: string;
  title: string;
  passing: boolean;
  guidance?: string;
}

/** Evaluates the live framing requirements from the pose stream. */
function evaluateChecks(
  frame: PoseFrame | null,
  centers: { x: number; y: number }[],
): SetupCheck[] {
  const pending: SetupCheck[] = [
    { id: "player", title: "Player detected", passing: false, guidance: "Step into frame" },
    { id: "fullBody", title: "Full body visible", passing: false },
    { id: "distance", title: "Far enough away", passing: false },
    { id: "stable", title: "Camera stable", passing: false },
    { id: "lighting", title: "Lighting acceptable", passing: false },
    { id: "orientation", title: "Orientation correct", passing: false },
  ];

  if (!frame || meanConfidence(frame) <= 0.15) return pending;

  const confidence = meanConfidence(frame);
  const checks: SetupCheck[] = [];

  // 1. Player detected
  const detected = confidence > 0.3;
  checks.push({
    id: "player",
    title: "Player detected",
    passing: detected,
    guidance: detected ? undefined : "Step into the frame",
  });

  // 2. Full body visible — need ankles and head inside the frame.
  const hasFeet =
    jointPoint(frame, "leftAnkle", 0.2) !== null ||
    jointPoint(frame, "rightAnkle", 0.2) !== null;
  const hasHead = jointPoint(frame, "nose", 0.2) !== null;
  const coverage = framingCoverage(frame);
  const fullBody = hasFeet && hasHead && coverage > 0.88;
  let bodyGuidance: string | undefined;
  if (!hasFeet) bodyGuidance = "Your feet are outside the frame";
  else if (!hasHead) bodyGuidance = "Tilt the camera down — your head is cut off";
  else if (coverage <= 0.88) bodyGuidance = "Part of you is out of frame";
  checks.push({
    id: "fullBody",
    title: "Full body visible",
    passing: fullBody,
    guidance: bodyGuidance,
  });

  // 3. Distance — judged by how much of the frame height the body fills.
  const ys = Object.values(frame.joints)
    .filter((point) => point && point.confidence > 0.2)
    .map((point) => point!.y);
  const bodyHeight = ys.length ? Math.max(...ys) - Math.min(...ys) : 0;
  const distanceOK = bodyHeight > 0.32 && bodyHeight < 0.92;
  checks.push({
    id: "distance",
    title: "Far enough away",
    passing: distanceOK,
    guidance:
      bodyHeight >= 0.92
        ? "Move farther back"
        : bodyHeight <= 0.32
          ? "Move closer to the camera"
          : undefined,
  });

  // 4. Camera stability — the skeleton shifting while the player stands still.
  const jitter =
    centers.length > 2
      ? Math.hypot(
          Math.max(...centers.map((c) => c.x)) - Math.min(...centers.map((c) => c.x)),
          Math.max(...centers.map((c) => c.y)) - Math.min(...centers.map((c) => c.y)),
        )
      : 0;
  const stable = centers.length < 6 || jitter < 0.05;
  checks.push({
    id: "stable",
    title: "Camera stable",
    passing: stable,
    guidance: stable ? undefined : "Prop the camera against something solid",
  });

  // 5. Lighting — low light collapses joint confidence.
  const lighting = confidence > 0.45;
  checks.push({
    id: "lighting",
    title: "Lighting acceptable",
    passing: lighting,
    guidance: lighting ? undefined : "Too dark — find brighter light",
  });

  // 6. Orientation — the torso should read as upright.
  const shoulders = shoulderCenter(frame);
  const hips = hipCenter(frame);
  const upright =
    !shoulders || !hips
      ? true
      : Math.abs(hips.y - shoulders.y) > Math.abs(hips.x - shoulders.x);
  checks.push({
    id: "orientation",
    title: "Orientation correct",
    passing: upright,
    guidance: upright ? undefined : "Stand so your whole body is upright in frame",
  });

  return checks;
}

export default function LivePractice() {
  const [params] = useSearchParams();
  const navigate = useNavigate();

  const configuration = useMemo<PracticeConfiguration>(() => {
    const drill = drillById(params.get("drill") ?? undefined);
    return {
      shot: (params.get("shot") as ShotType) ?? "forehandDink",
      mode: (params.get("mode") as SessionMode) ?? "freePractice",
      drill: drill ?? null,
      length: (params.get("length") as SessionLength) ?? "tenMinutes",
    };
  }, [params]);

  const engine = usePracticeEngine(configuration);
  const [phase, setPhase] = useState<"setup" | "live">("setup");
  const [centers, setCenters] = useState<{ x: number; y: number }[]>([]);
  const [goodStreak, setGoodStreak] = useState<number>(0);
  const [showEndConfirm, setShowEndConfirm] = useState<boolean>(false);

  // Track recent hip centres so the stability check has a window to judge.
  useEffect(() => {
    const center = engine.currentPose ? hipCenter(engine.currentPose) : null;
    if (!center) return;
    setCenters((current) => [...current, center].slice(-12));
  }, [engine.currentPose]);

  const checks = useMemo(
    () => evaluateChecks(engine.currentPose, centers),
    [engine.currentPose, centers],
  );

  const allPassing = checks.every((check) => check.passing);

  // Require a few consecutive good frames so one lucky frame doesn't unlock.
  useEffect(() => {
    setGoodStreak((current) => (allPassing ? current + 1 : 0));
  }, [allPassing, engine.currentPose]);

  const isReady = goodStreak >= 4;

  useEffect(() => {
    if (!engine.isFinished) return;
    stopSpeaking();
    navigate(`/session/${engine.sessionID}`, { replace: true });
  }, [engine.isFinished, engine.sessionID, navigate]);

  useEffect(() => () => stopSpeaking(), []);

  const cancel = useCallback(() => {
    stopSpeaking();
    navigate("/practice", { replace: true });
  }, [navigate]);

  const guidance = checks.find((check) => !check.passing)?.guidance;

  if (engine.authorization === "denied") {
    return (
      <PermissionState
        icon="VideoOff"
        title="Camera access needed"
        message="Paddle Up analyses your body position from the camera to score each rep. Nothing is uploaded — analysis happens in your browser."
        actionLabel="TRY AGAIN"
        onAction={() => window.location.reload()}
        onCancel={cancel}
      />
    );
  }

  if (engine.authorization === "noDeviceFound" || engine.authorization === "failed") {
    return (
      <PermissionState
        icon="CameraOff"
        title="No camera available"
        message="Paddle Up couldn't find a camera on this device. Connect or enable a camera and try again."
        actionLabel="GO BACK"
        onAction={cancel}
        onCancel={cancel}
      />
    );
  }

  return (
    <div className="relative z-10 flex h-dvh flex-col bg-black">
      <div className="relative min-h-0 flex-1 overflow-hidden">
        <video
          ref={engine.videoRef}
          playsInline
          muted
          className="h-full w-full scale-x-[-1] object-cover"
        />

        <PoseOverlay
          frame={engine.currentPose}
          color={phase === "setup" && !isReady ? "#FFB020" : "#C6FF3D"}
          lineWidth={phase === "setup" ? 2.5 : 3}
          jointRadius={phase === "setup" ? 1.1 : 1.3}
        />
        <FramingBrackets isValid={phase === "live" || isReady} />

        {/* Top bar */}
        <div className="absolute inset-x-0 top-0 flex items-center gap-2.5 p-4">
          <button
            type="button"
            onClick={() => (phase === "setup" ? cancel() : setShowEndConfirm(true))}
            aria-label={phase === "setup" ? "Cancel setup" : "End session"}
            className="flex h-10 w-10 items-center justify-center rounded-full bg-black/45 text-white backdrop-blur-xl transition-transform active:scale-95"
          >
            <Icon name="X" className="h-4 w-4" strokeWidth={2.6} />
          </button>

          {phase === "setup" ? (
            <span className="mx-auto rounded-full bg-black/45 px-3.5 py-2 text-[17px] font-semibold text-white backdrop-blur-xl">
              Camera Setup
            </span>
          ) : (
            <>
              <div className="flex-1" />
              <div className="flex h-10 items-center gap-1.5 rounded-full bg-black/45 px-3.5 backdrop-blur-xl">
                <span className="text-[13px] font-medium text-pu-secondary">Rep</span>
                <span className="pu-tabular text-[17px] font-bold text-pu-lime">
                  {engine.repCount}
                </span>
              </div>
              <div className="flex h-10 items-center gap-1.5 rounded-full bg-black/45 px-3.5 text-white backdrop-blur-xl">
                <Icon name="Timer" className="h-3 w-3" strokeWidth={2.4} />
                <span className="pu-tabular text-[15px] font-semibold">
                  {formatClock(engine.elapsed)}
                </span>
              </div>
            </>
          )}

          {phase === "setup" && <span className="h-10 w-10" />}
        </div>

        {/* Bottom overlay */}
        <div className="absolute inset-x-0 bottom-0 flex flex-col items-center gap-3 p-4">
          {engine.isModelLoading && (
            <span className="flex items-center gap-2 rounded-full bg-black/55 px-4 py-2.5 text-sm font-semibold text-white backdrop-blur-xl">
              <Icon name="LoaderCircle" className="h-4 w-4 animate-spin" />
              Loading the on-device analyzer…
            </span>
          )}

          {phase === "setup" && !engine.isModelLoading && (
            <>
              {guidance ? (
                <span className="rounded-full bg-pu-amber px-4.5 py-3 text-[17px] font-bold text-pu-lime-ink">
                  {guidance}
                </span>
              ) : isReady ? (
                <span className="rounded-full bg-pu-lime px-4.5 py-3 text-[17px] font-bold text-pu-lime-ink">
                  Camera angle looks good
                </span>
              ) : null}
            </>
          )}

          {phase === "live" && engine.repCount === 0 && !engine.isModelLoading && (
            <span className="rounded-full bg-black/55 px-4 py-2.5 text-sm font-semibold text-white backdrop-blur-xl">
              {engine.currentPose ? "Ready — start hitting" : "Looking for you…"}
            </span>
          )}

          {phase === "live" && engine.targetSeconds && (
            <div className="h-[3px] w-full overflow-hidden rounded-full bg-black/35">
              <div
                className="h-full rounded-full bg-pu-lime transition-[width] duration-200 ease-linear"
                style={{ width: `${engine.progress * 100}%` }}
              />
            </div>
          )}
        </div>
      </div>

      {/* Lower pane */}
      {phase === "setup" ? (
        <div className="shrink-0 bg-pu-canvas-deep px-5 pb-6 pt-4">
          <div className="mx-auto w-full max-w-xl">
            <div className="grid grid-cols-2 gap-x-2.5 gap-y-2">
              {checks.map((check) => (
                <div key={check.id} className="flex items-center gap-2">
                  <Icon
                    name={check.passing ? "CircleCheck" : "CircleDashed"}
                    className={cn(
                      "h-3.5 w-3.5 shrink-0 transition-colors",
                      check.passing ? "text-pu-lime" : "text-pu-tertiary",
                    )}
                    strokeWidth={2.4}
                  />
                  <span
                    className={cn(
                      "truncate text-[13px] font-medium",
                      check.passing ? "text-pu-primary" : "text-pu-secondary",
                    )}
                  >
                    {check.title}
                  </span>
                </div>
              ))}
            </div>

            <div className="mt-4">
              <PrimaryButton onClick={() => setPhase("live")} disabled={!isReady}>
                START SESSION
              </PrimaryButton>
            </div>

            <p className="mt-2.5 text-center text-[13px] font-medium text-pu-secondary">
              {configuration.drill
                ? `${configuration.drill.name} · ${sessionLengthName(configuration.length)}`
                : `${shotName[configuration.shot]} · ${sessionLengthName(configuration.length)}`}
            </p>
          </div>
        </div>
      ) : (
        <div className="shrink-0 bg-pu-canvas px-5 pb-6 pt-3.5">
          <div className="mx-auto flex w-full max-w-xl flex-col gap-2.5">
            {engine.latestFeedback ? (
              <>
                <ScoreCard feedback={engine.latestFeedback} />
                <CorrectionCard feedback={engine.latestFeedback} />
              </>
            ) : (
              <Card padding="p-5">
                <MicroLabel>
                  {configuration.drill?.focusCue.toUpperCase() ?? "FOCUS"}
                </MicroLabel>
                <p className="mt-2 text-[19px] font-bold leading-snug text-pu-primary">
                  {configuration.drill?.focusCue ??
                    "Hit naturally — Paddle Up will find your reps."}
                </p>
                <p className="mt-2 text-[13px] font-medium text-pu-secondary">
                  Your first scored rep will appear here.
                </p>
              </Card>
            )}

            <PrimaryButton onClick={() => setShowEndConfirm(true)}>
              <Icon name="Square" className="h-4 w-4" strokeWidth={3} />
              End Session
            </PrimaryButton>
          </div>
        </div>
      )}

      {showEndConfirm && (
        <div className="absolute inset-0 z-50 flex items-end justify-center bg-black/60 p-5 backdrop-blur-sm">
          <Card className="w-full max-w-md animate-pu-rise">
            <h3 className="text-xl font-bold text-pu-primary">End this session?</h3>
            <p className="mt-2 text-[15px] font-medium text-pu-secondary">
              {engine.repCount} reps recorded so far.
            </p>
            <div className="mt-4 flex flex-col gap-2.5">
              <PrimaryButton
                onClick={() => {
                  setShowEndConfirm(false);
                  engine.end();
                }}
              >
                END SESSION
              </PrimaryButton>
              <SecondaryButton onClick={() => setShowEndConfirm(false)}>
                Keep practising
              </SecondaryButton>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}

function ScoreCard({
  feedback,
}: {
  feedback: NonNullable<ReturnType<typeof usePracticeEngine>["latestFeedback"]>;
}) {
  const score = feedback.rep.score;
  const radius = 37;
  const circumference = 2 * Math.PI * radius;

  return (
    <Card padding="p-4">
      <div className="flex items-center gap-4">
        <div className="flex flex-1 flex-col gap-0.5">
          <MicroLabel>Paddle Up Score</MicroLabel>
          <div className="flex items-baseline gap-1">
            <span className="pu-tabular text-[52px] font-black leading-none text-pu-primary">
              {Math.round(score)}
            </span>
            <span className="text-[17px] font-semibold text-pu-secondary">
              / 100
            </span>
          </div>
          {feedback.rep.confidence < 0.55 && (
            <span className="mt-1 flex items-center gap-1 text-[11px] font-medium text-pu-amber">
              <Icon name="TriangleAlert" className="h-3 w-3" />
              Low confidence read
            </span>
          )}
        </div>

        <div className="relative h-[84px] w-[84px] shrink-0">
          <svg width={84} height={84} className="-rotate-90">
            <circle
              cx={42}
              cy={42}
              r={radius}
              fill="none"
              stroke="rgba(255,255,255,0.08)"
              strokeWidth={9}
            />
            <circle
              cx={42}
              cy={42}
              r={radius}
              fill="none"
              stroke={scoreColor(score)}
              strokeWidth={9}
              strokeLinecap="round"
              strokeDasharray={circumference}
              strokeDashoffset={circumference * (1 - score / 100)}
              style={{ transition: "stroke-dashoffset 0.6s ease-out" }}
            />
          </svg>
        </div>
      </div>
    </Card>
  );
}

function CorrectionCard({
  feedback,
}: {
  feedback: NonNullable<ReturnType<typeof usePracticeEngine>["latestFeedback"]>;
}) {
  const { coaching } = feedback;
  return (
    <Card>
      <div className="flex items-start gap-3">
        <Icon
          name={coaching.isPraise ? "BadgeCheck" : "Crosshair"}
          className={cn(
            "mt-0.5 h-5 w-5 shrink-0",
            coaching.isPraise ? "text-pu-lime" : "text-pu-alert",
          )}
          strokeWidth={2.2}
        />
        <div className="flex flex-col gap-1">
          <MicroLabel>{coaching.isPraise ? "Good rep" : "Main issue"}</MicroLabel>
          <span className="text-xl font-bold leading-snug text-pu-primary">
            {coaching.headline}
          </span>
        </div>
      </div>

      <div className="my-3 h-px w-full bg-pu-hairline" />

      <div className="flex items-start gap-3">
        <Icon
          name="Lightbulb"
          className="mt-0.5 h-[18px] w-[18px] shrink-0 text-pu-lime"
          strokeWidth={2.2}
        />
        <p className="text-[15px] font-medium leading-relaxed text-pu-primary">
          {coaching.correction}
        </p>
      </div>

      <div className="mt-3 rounded-xl bg-pu-lime/[0.16] p-3">
        <MicroLabel>Next rep focus</MicroLabel>
        <p className="mt-0.5 text-base font-black tracking-[0.03em] text-pu-lime">
          {coaching.cue}
        </p>
      </div>
    </Card>
  );
}

function PermissionState({
  icon,
  title,
  message,
  actionLabel,
  onAction,
  onCancel,
}: {
  icon: string;
  title: string;
  message: string;
  actionLabel: string;
  onAction: () => void;
  onCancel: () => void;
}) {
  return (
    <div className="relative z-10 flex min-h-dvh flex-col items-center justify-center gap-4 px-8 text-center">
      <Icon name={icon} className="h-11 w-11 text-pu-amber" strokeWidth={1.4} />
      <h2 className="text-2xl font-bold text-pu-primary">{title}</h2>
      <p className="max-w-sm text-[15px] font-medium leading-relaxed text-pu-secondary">
        {message}
      </p>
      <div className="mt-2 w-full max-w-xs">
        <PrimaryButton onClick={onAction}>{actionLabel}</PrimaryButton>
      </div>
      <button
        type="button"
        onClick={onCancel}
        className="text-[13px] font-medium text-pu-secondary transition-colors hover:text-pu-primary"
      >
        Not now
      </button>
    </div>
  );
}
