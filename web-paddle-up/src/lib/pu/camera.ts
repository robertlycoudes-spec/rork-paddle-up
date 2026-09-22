/**
 * Camera access for the practice pipeline. The browser is the only camera
 * surface here, so permission and device states are modelled explicitly and
 * surfaced in the UI rather than hidden behind a fake viewfinder.
 */

export type CameraAuthorization =
  | "idle"
  | "requesting"
  | "authorized"
  | "denied"
  | "noDeviceFound"
  | "failed";

export interface CameraStartResult {
  status: CameraAuthorization;
  stream: MediaStream | null;
}

/** Requests the user-facing camera at a resolution the pose model likes. */
export async function startCamera(): Promise<CameraStartResult> {
  if (!navigator.mediaDevices?.getUserMedia) {
    return { status: "noDeviceFound", stream: null };
  }

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: "user",
        width: { ideal: 1280 },
        height: { ideal: 720 },
        frameRate: { ideal: 30 },
      },
      audio: false,
    });
    return { status: "authorized", stream };
  } catch (error) {
    const name = error instanceof Error ? error.name : "";
    if (name === "NotAllowedError" || name === "SecurityError") {
      return { status: "denied", stream: null };
    }
    if (name === "NotFoundError" || name === "OverconstrainedError") {
      return { status: "noDeviceFound", stream: null };
    }
    return { status: "failed", stream: null };
  }
}

export function stopStream(stream: MediaStream | null): void {
  stream?.getTracks().forEach((track) => track.stop());
}
