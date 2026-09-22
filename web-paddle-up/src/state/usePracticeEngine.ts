/**
 * Orchestrates the live pipeline for one session:
 *
 *   Camera → PoseEngine → RepDetector → ShotClassifier
 *          → MechanicsAnalyzer → ScoringEngine → CoachingEngine
 *
 * Each stage is a separate module; this hook only wires them together and
 * holds the live session state the UI renders. Core logic is never buried here.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { startCamera, stopStream, type CameraAuthorization } from "@/lib/pu/camera";
import { coachRep, type RepCoaching } from "@/lib/pu/coaching";
import type { Drill } from "@/lib/pu/drills";
import { measureWindow } from "@/lib/pu/mechanics-analyzer";
import { sessionLengthSeconds, type SessionLength } from "@/lib/pu/persistence";
import type { PoseFrame } from "@/lib/pu/pose";
import { PoseEngine } from "@/lib/pu/pose-engine";
import {
  newRep,
  type RepRecord,
  type SessionMode,
  type SessionRecord,
} from "@/lib/pu/profile";
import {
  RepDetector,
  type RepRejection,
  type RepState,
} from "@/lib/pu/rep-detector";
import { scoreRep } from "@/lib/pu/scoring";
import { classifySwing } from "@/lib/pu/shot-classifier";
import type { ShotType } from "@/lib/pu/shots";
import { speakCue } from "@/lib/pu/voice";
import { useAppState } from "@/state/AppStateProvider";

export interface LiveRepFeedback {
  id: string;
  rep: RepRecord;
  coaching: RepCoaching;
}

export interface PracticeConfiguration {
  shot: ShotType;
  mode: SessionMode;
  drill: Drill | null;
  length: SessionLength;
}

/** Keep at most ~24 pose frames per rep so stored sessions stay small. */
function downsample(frames: PoseFrame[]): PoseFrame[] {
  if (frames.length <= 24) return frames;
  const stride = frames.length / 24;
  const result: PoseFrame[] = [];
  for (let index = 0; index < 24; index += 1) {
    const frame = frames[Math.floor(index * stride)];
    if (frame) result.push(frame);
  }
  return result;
}

export function usePracticeEngine(configuration: PracticeConfiguration) {
  const { profile, settings, saveSession } = useAppState();

  const [authorization, setAuthorization] = useState<CameraAuthorization>("idle");
  const [isModelLoading, setIsModelLoading] = useState<boolean>(true);
  const [currentPose, setCurrentPose] = useState<PoseFrame | null>(null);
  const [latestFeedback, setLatestFeedback] = useState<LiveRepFeedback | null>(
    null,
  );
  const [repCount, setRepCount] = useState<number>(0);
  const [elapsed, setElapsed] = useState<number>(0);
  const [isFinished, setIsFinished] = useState<boolean>(false);
  const [detectorState, setDetectorState] = useState<RepState>("idle");
  const [lastRejection, setLastRejection] = useState<RepRejection | null>(null);

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const poseRef = useRef<PoseEngine | null>(null);
  const detectorRef = useRef<RepDetector | null>(null);
  const sessionRef = useRef<SessionRecord | null>(null);
  const startedAtRef = useRef<number>(0);
  const finishedRef = useRef<boolean>(false);
  const spokenRepRef = useRef<number>(0);

  const targetSeconds = useMemo(
    () => sessionLengthSeconds(configuration.length),
    [configuration.length],
  );

  const progress = useMemo(() => {
    if (!targetSeconds || targetSeconds <= 0) return 0;
    return Math.min(1, elapsed / targetSeconds);
  }, [elapsed, targetSeconds]);

  if (!sessionRef.current) {
    sessionRef.current = {
      id: crypto.randomUUID(),
      startedAt: Date.now(),
      shot: configuration.shot,
      mode: configuration.mode,
      drillID: configuration.drill?.id,
      reps: [],
      focusCue: configuration.drill?.focusCue,
    };
  }

  const [currentCue, setCurrentCue] = useState<string>(
    configuration.drill?.focusCue ?? "SETTLE IN",
  );

  const end = useCallback(() => {
    if (finishedRef.current) return;
    finishedRef.current = true;
    const session = sessionRef.current;
    if (session) {
      session.endedAt = Date.now();
      saveSession({ ...session });
    }
    poseRef.current?.stop();
    stopStream(streamRef.current);
    streamRef.current = null;
    setIsFinished(true);
  }, [saveSession]);

  const handleWindow = useCallback(
    (window: Parameters<typeof measureWindow>[0]) => {
      const session = sessionRef.current;
      if (!session) return;
      const hand = profile.handedness;

      // Classify (side detection + plausibility) within the session's shot.
      const classification = classifySwing(window, hand, configuration.shot);

      // Measure → score → coach.
      const measurements = measureWindow(window, classification.shot, hand);
      if (measurements.length === 0) return;

      const combinedConfidence =
        window.detectionConfidence * (0.7 + 0.3 * classification.confidence);
      const analysis = scoreRep(
        measurements,
        classification.shot,
        combinedConfidence,
      );
      const coaching = coachRep(analysis);

      const index = session.reps.filter((rep) => !rep.isDeleted).length + 1;
      const rep = newRep({
        sessionID: session.id,
        index,
        timestamp: Date.now(),
        shot: classification.shot,
        score: analysis.score,
        mechanics: analysis.mechanics,
        dominantIssue: analysis.dominantIssue,
        issueID: coaching.issue?.id,
        correction: coaching.correction,
        nextRepCue: coaching.cue,
        recommendedDrillID: coaching.drillID,
        confidence: analysis.confidence,
        poseFrames: downsample(window.frames),
        rubricVersion: analysis.rubricVersion,
      });

      setRepCount(index);
      setCurrentCue(coaching.cue);
      setLatestFeedback({ id: rep.id, rep, coaching });

      // Voice coaching respects the player's chosen frequency.
      const interval =
        settings.voiceCoaching === "off"
          ? Number.MAX_SAFE_INTEGER
          : settings.voiceCoaching === "importantOnly"
            ? 4
            : settings.voiceCoaching === "everyFewReps"
              ? 3
              : 1;
      if (
        !coaching.isPraise &&
        index - spokenRepRef.current >= interval &&
        settings.voiceCoaching !== "off"
      ) {
        spokenRepRef.current = index;
        speakCue(coaching.cue);
      }

      // Persist the rep immediately so a reload never loses practice data.
      session.reps.push(rep);
      saveSession({ ...session });
    },
    [configuration.shot, profile.handedness, saveSession, settings.voiceCoaching],
  );

  const onFrame = useCallback(
    (frame: PoseFrame | null) => {
      if (finishedRef.current || !frame) return;
      setCurrentPose(frame);

      const detector = detectorRef.current;
      if (!detector) return;
      const event = detector.ingest(frame);
      setDetectorState(detector.state);

      if (event.kind === "repCompleted") {
        handleWindow(event.window);
      } else if (event.kind === "repRejected") {
        setLastRejection(event.reason);
      }
    },
    [handleWindow],
  );

  /** Start the camera and pose pipeline once, on mount. */
  useEffect(() => {
    let cancelled = false;
    detectorRef.current = new RepDetector(profile.handedness);
    const engine = new PoseEngine(1);
    poseRef.current = engine;

    const boot = async () => {
      setAuthorization("requesting");
      const result = await startCamera();
      if (cancelled) {
        stopStream(result.stream);
        return;
      }
      setAuthorization(result.status);
      if (result.status !== "authorized" || !result.stream) {
        setIsModelLoading(false);
        return;
      }

      streamRef.current = result.stream;
      const video = videoRef.current;
      if (!video) return;
      video.srcObject = result.stream;
      try {
        await video.play();
      } catch {
        // Autoplay can be deferred; the loop still starts once frames arrive.
      }

      try {
        await engine.start(video, onFrame);
      } catch {
        if (!cancelled) setAuthorization("failed");
      } finally {
        if (!cancelled) setIsModelLoading(false);
      }

      startedAtRef.current = performance.now();
    };

    void boot();

    return () => {
      cancelled = true;
      engine.stop();
      stopStream(streamRef.current);
      streamRef.current = null;
    };
    // The engine is created once per practice session by design.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /** Session clock; ends the session automatically at the target length. */
  useEffect(() => {
    if (authorization !== "authorized") return;
    const timer = window.setInterval(() => {
      if (finishedRef.current || startedAtRef.current === 0) return;
      const seconds = (performance.now() - startedAtRef.current) / 1000;
      setElapsed(seconds);
      if (targetSeconds && seconds >= targetSeconds) end();
    }, 200);
    return () => window.clearInterval(timer);
  }, [authorization, targetSeconds, end]);

  return {
    videoRef,
    authorization,
    isModelLoading,
    currentPose,
    latestFeedback,
    repCount,
    elapsed,
    isFinished,
    detectorState,
    lastRejection,
    currentCue,
    progress,
    targetSeconds,
    sessionID: sessionRef.current.id,
    end,
  };
}
