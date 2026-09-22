/**
 * In-browser pose estimation. Runs entirely on the device via the MediaPipe
 * Pose Landmarker (WASM): lower latency, no cloud cost, and body-position data
 * never leaves the browser.
 *
 * The model is fetched lazily from a CDN the first time a session starts, so
 * the rest of the app loads instantly. Coordinates are converted into the
 * app's top-left normalised space.
 */

import type { PoseFrame, PoseJoint, PosePoint } from "./pose";

/** MediaPipe BlazePose landmark indices → the app's joint vocabulary. */
const LANDMARK_MAP: { index: number; joint: PoseJoint }[] = [
  { index: 0, joint: "nose" },
  { index: 11, joint: "leftShoulder" },
  { index: 12, joint: "rightShoulder" },
  { index: 13, joint: "leftElbow" },
  { index: 14, joint: "rightElbow" },
  { index: 15, joint: "leftWrist" },
  { index: 16, joint: "rightWrist" },
  { index: 23, joint: "leftHip" },
  { index: 24, joint: "rightHip" },
  { index: 25, joint: "leftKnee" },
  { index: 26, joint: "rightKnee" },
  { index: 27, joint: "leftAnkle" },
  { index: 28, joint: "rightAnkle" },
];

interface Landmark {
  x: number;
  y: number;
  z: number;
  visibility?: number;
}

interface PoseLandmarkerResult {
  landmarks: Landmark[][];
}

interface PoseLandmarkerLike {
  detectForVideo: (
    video: HTMLVideoElement,
    timestamp: number,
  ) => PoseLandmarkerResult;
  close: () => void;
}

const WASM_BASE =
  "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm";
const VISION_BUNDLE_URL =
  "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/vision_bundle.mjs";
const MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task";

let landmarkerPromise: Promise<PoseLandmarkerLike> | null = null;

/**
 * Loads the Pose Landmarker once and reuses it. The vision bundle is imported
 * dynamically from the CDN so it never enters the app's build graph.
 */
async function loadLandmarker(): Promise<PoseLandmarkerLike> {
  if (!landmarkerPromise) {
    landmarkerPromise = (async () => {
      // The URL is held in a variable so TypeScript resolves this as a
      // runtime import rather than trying to type-check a remote module.
      const vision = (await import(/* @vite-ignore */ VISION_BUNDLE_URL)) as {
        FilesetResolver: {
          forVisionTasks: (base: string) => Promise<unknown>;
        };
        PoseLandmarker: {
          createFromOptions: (
            fileset: unknown,
            options: Record<string, unknown>,
          ) => Promise<PoseLandmarkerLike>;
        };
      };

      const fileset = await vision.FilesetResolver.forVisionTasks(WASM_BASE);
      return vision.PoseLandmarker.createFromOptions(fileset, {
        baseOptions: { modelAssetPath: MODEL_URL, delegate: "GPU" },
        runningMode: "VIDEO",
        numPoses: 1,
        minPoseDetectionConfidence: 0.4,
        minPosePresenceConfidence: 0.4,
        minTrackingConfidence: 0.4,
      });
    })().catch((error) => {
      // Let the next attempt retry rather than caching a rejected promise.
      landmarkerPromise = null;
      throw error;
    });
  }
  return landmarkerPromise;
}

export type PoseEngineStatus = "idle" | "loading" | "running" | "failed";

/**
 * Drives pose detection off a <video> element with requestVideoFrameCallback
 * (falling back to rAF), emitting normalised frames to a callback.
 */
export class PoseEngine {
  private landmarker: PoseLandmarkerLike | null = null;
  private rafHandle: number | null = null;
  private videoHandle: number | null = null;
  private video: HTMLVideoElement | null = null;
  private startTime: number | null = null;
  private lastTimestamp = -1;
  private stopped = false;
  private frameCounter = 0;

  /** Process every Nth frame to keep CPU and battery in check. */
  constructor(private readonly frameStride: number = 1) {}

  async start(
    video: HTMLVideoElement,
    onFrame: (frame: PoseFrame | null) => void,
  ): Promise<void> {
    this.stopped = false;
    this.video = video;
    this.landmarker = await loadLandmarker();
    if (this.stopped) return;

    const pump = () => {
      if (this.stopped || !this.video || !this.landmarker) return;
      const element = this.video;

      if (element.readyState >= 2 && element.videoWidth > 0) {
        this.frameCounter += 1;
        if (this.frameCounter % this.frameStride === 0) {
          const now = performance.now();
          if (this.startTime === null) this.startTime = now;
          // MediaPipe requires strictly increasing timestamps.
          const timestamp = Math.max(this.lastTimestamp + 1, Math.round(now));
          this.lastTimestamp = timestamp;

          try {
            const result = this.landmarker.detectForVideo(element, timestamp);
            const landmarks = result.landmarks?.[0];
            onFrame(
              landmarks
                ? convert(landmarks, (now - this.startTime) / 1000)
                : null,
            );
          } catch {
            // A dropped frame is not fatal — keep the loop alive.
            onFrame(null);
          }
        }
      }
      schedule();
    };

    const schedule = () => {
      if (this.stopped || !this.video) return;
      const element = this.video as HTMLVideoElement & {
        requestVideoFrameCallback?: (callback: () => void) => number;
      };
      if (typeof element.requestVideoFrameCallback === "function") {
        this.videoHandle = element.requestVideoFrameCallback(pump);
      } else {
        this.rafHandle = requestAnimationFrame(pump);
      }
    };

    schedule();
  }

  stop(): void {
    this.stopped = true;
    if (this.rafHandle !== null) cancelAnimationFrame(this.rafHandle);
    const element = this.video as
      | (HTMLVideoElement & {
          cancelVideoFrameCallback?: (handle: number) => void;
        })
      | null;
    if (this.videoHandle !== null && element?.cancelVideoFrameCallback) {
      element.cancelVideoFrameCallback(this.videoHandle);
    }
    this.rafHandle = null;
    this.videoHandle = null;
    this.video = null;
    this.startTime = null;
    this.lastTimestamp = -1;
  }
}

function convert(landmarks: Landmark[], time: number): PoseFrame {
  const joints: Partial<Record<PoseJoint, PosePoint>> = {};
  for (const { index, joint } of LANDMARK_MAP) {
    const landmark = landmarks[index];
    if (!landmark) continue;
    const confidence = landmark.visibility ?? 0.5;
    if (confidence < 0.05) continue;
    joints[joint] = { x: landmark.x, y: landmark.y, confidence };
  }

  // Derive the midpoints BlazePose doesn't provide directly.
  const left = joints.leftShoulder;
  const right = joints.rightShoulder;
  if (left && right) {
    joints.neck = {
      x: (left.x + right.x) / 2,
      y: (left.y + right.y) / 2,
      confidence: Math.min(left.confidence, right.confidence),
    };
  }
  const leftHip = joints.leftHip;
  const rightHip = joints.rightHip;
  if (leftHip && rightHip) {
    joints.root = {
      x: (leftHip.x + rightHip.x) / 2,
      y: (leftHip.y + rightHip.y) / 2,
      confidence: Math.min(leftHip.confidence, rightHip.confidence),
    };
  }

  return { time, joints };
}
