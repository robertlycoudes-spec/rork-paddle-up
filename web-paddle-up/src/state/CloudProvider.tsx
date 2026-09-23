/**
 * Optional cloud account (Rork Auth: Apple / Google) plus local-first sync —
 * the web counterpart of the iOS CloudAuthService + CloudSyncService.
 *
 * Rules (no merging, no conflict resolution):
 *   • Every local change stamps AccountData.modifiedAt and triggers a push.
 *   • On sign-in, load, tab focus and reconnect the cloud snapshot is pulled
 *     and compared: cloud newer → replace local; local newer → push.
 *   • The server rejects an older upload (409); the newer copy is applied.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import { migrateAccountData, type AccountData } from "@/lib/pu/persistence";
import { useAppState } from "@/state/AppStateProvider";

const AUTH_URL = (import.meta.env.EXPO_PUBLIC_RORK_AUTH_URL as string | undefined) ?? "";
const APP_KEY = (import.meta.env.EXPO_PUBLIC_RORK_APP_KEY as string | undefined) ?? "";
const FUNCTIONS_URL =
  (import.meta.env.EXPO_PUBLIC_RORK_FUNCTIONS_URL as string | undefined) ?? "";

const ACCESS_TOKEN_KEY = "rork:access_token";
const REFRESH_TOKEN_KEY = "rork:refresh_token";
const CODE_VERIFIER_KEY = "rork:pkce_verifier";

export interface CloudUser {
  id: string;
  email: string;
  name?: string;
}

export type SyncStatus = "signedOut" | "idle" | "syncing" | "offline" | "failed";

interface CloudValue {
  user: CloudUser | null;
  isLoading: boolean;
  isSigningIn: boolean;
  error: string | null;
  status: SyncStatus;
  lastSyncedAt: number | null;
  signIn: (provider: "google" | "apple") => Promise<void>;
  signOut: () => void;
  clearError: () => void;
  exchangeCode: (code: string) => Promise<void>;
  syncNow: () => Promise<void>;
  deleteCloudData: () => Promise<boolean>;
}

const CloudContext = createContext<CloudValue | null>(null);

function base64URL(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

async function codeChallenge(verifier: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return base64URL(new Uint8Array(hash));
}

/** Decodes the JWT payload; the backend re-verifies on every request. */
function userFromToken(token: string): CloudUser | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))) as {
      sub: string;
      email?: string;
      name?: string;
      exp?: number;
    };
    if (payload.exp && payload.exp * 1000 < Date.now() + 30_000) return null;
    return { id: payload.sub, email: payload.email ?? "", name: payload.name };
  } catch {
    return null;
  }
}

function readStorage(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

class SyncSignedOut extends Error {}

export function CloudProvider({ children }: { children: ReactNode }) {
  const { data, isLoaded, applyRemote } = useAppState();

  const [user, setUser] = useState<CloudUser | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSigningIn, setIsSigningIn] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<SyncStatus>("signedOut");
  const [lastSyncedAt, setLastSyncedAt] = useState<number | null>(null);

  const dataRef = useRef<AccountData>(data);
  dataRef.current = data;
  const syncingRef = useRef<boolean>(false);
  const pushTimer = useRef<number | null>(null);
  const lastPushedAt = useRef<number>(0);

  const signOut = useCallback(() => {
    try {
      localStorage.removeItem(ACCESS_TOKEN_KEY);
      localStorage.removeItem(REFRESH_TOKEN_KEY);
      localStorage.removeItem(CODE_VERIFIER_KEY);
    } catch {
      // storage unavailable
    }
    setUser(null);
    setStatus("signedOut");
    setLastSyncedAt(null);
  }, []);

  /** A non-expired access token, refreshing first when needed. */
  const validToken = useCallback(async (): Promise<string | null> => {
    const access = readStorage(ACCESS_TOKEN_KEY);
    if (access && userFromToken(access)) return access;
    const refresh = readStorage(REFRESH_TOKEN_KEY);
    if (!refresh || !AUTH_URL) return null;
    try {
      const response = await fetch(`${AUTH_URL}/oauth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ app_key: APP_KEY, refresh_token: refresh }),
      });
      if (response.status === 400 || response.status === 401) {
        signOut();
        return null;
      }
      if (!response.ok) return null;
      const { access_token } = (await response.json()) as { access_token: string };
      localStorage.setItem(ACCESS_TOKEN_KEY, access_token);
      const decoded = userFromToken(access_token);
      if (decoded) setUser(decoded);
      return access_token;
    } catch {
      return null; // offline — keep the session, retry later
    }
  }, [signOut]);

  // Restore a stored session once.
  useEffect(() => {
    void (async () => {
      const access = readStorage(ACCESS_TOKEN_KEY);
      const decoded = access ? userFromToken(access) : null;
      if (decoded) setUser(decoded);
      else if (readStorage(REFRESH_TOKEN_KEY)) await validToken();
      setIsLoading(false);
    })();
  }, [validToken]);

  const request = useCallback(
    async (method: "GET" | "PUT" | "DELETE", body?: string): Promise<Response> => {
      const token = await validToken();
      if (!token) throw new SyncSignedOut();
      if (!FUNCTIONS_URL) throw new Error("Cloud sync isn't configured.");
      return fetch(`${FUNCTIONS_URL}/v1/account`, {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          "X-PaddleUp-Platform": "web",
        },
        body,
      });
    },
    [validToken],
  );

  const toRemote = useCallback((raw: unknown): AccountData | null => {
    const snapshot = raw as {
      modifiedAt?: number;
      schemaVersion?: number;
      data?: Partial<AccountData>;
    } | null;
    if (!snapshot?.data || typeof snapshot.modifiedAt !== "number") return null;
    return migrateAccountData({
      ...snapshot.data,
      modifiedAt: snapshot.modifiedAt,
      schemaVersion: snapshot.schemaVersion,
    });
  }, []);

  const push = useCallback(
    async (local: AccountData) => {
      const { modifiedAt, schemaVersion, ...payload } = local;
      const response = await request(
        "PUT",
        JSON.stringify({ modifiedAt, schemaVersion, data: payload }),
      );
      if (response.status === 401) throw new SyncSignedOut();
      if (response.status === 409) {
        // The cloud holds something newer — last write wins, so take it.
        const body = (await response.json().catch(() => null)) as { snapshot?: unknown } | null;
        const remote = toRemote(body?.snapshot);
        if (remote) applyRemote(remote);
        return;
      }
      if (!response.ok) throw new Error(`Cloud error (${response.status})`);
      lastPushedAt.current = modifiedAt;
    },
    [request, toRemote, applyRemote],
  );

  const handleFailure = useCallback(
    (cause: unknown) => {
      if (cause instanceof SyncSignedOut) {
        setStatus("signedOut");
        return;
      }
      setStatus(navigator.onLine ? "failed" : "offline");
    },
    [],
  );

  /** Pull-compare-push. Safe to call any time; no-ops when signed out. */
  const syncNow = useCallback(async () => {
    if (!user || !isLoaded || syncingRef.current) return;
    if (!navigator.onLine) {
      setStatus("offline");
      return;
    }
    syncingRef.current = true;
    setStatus("syncing");
    try {
      const response = await request("GET");
      if (response.status === 401) throw new SyncSignedOut();
      let remote: AccountData | null = null;
      if (response.ok) remote = toRemote(await response.json());
      else if (response.status !== 404) throw new Error(`Cloud error (${response.status})`);

      const local = dataRef.current;
      if (remote && remote.modifiedAt > local.modifiedAt) {
        lastPushedAt.current = remote.modifiedAt;
        applyRemote(remote);
      } else if (!remote || local.modifiedAt > remote.modifiedAt) {
        await push(local);
      }
      setLastSyncedAt(Date.now());
      setStatus("idle");
    } catch (cause) {
      handleFailure(cause);
    } finally {
      syncingRef.current = false;
    }
  }, [user, isLoaded, request, toRemote, applyRemote, push, handleFailure]);

  // Sync on sign-in and once data is loaded.
  useEffect(() => {
    if (user && isLoaded) void syncNow();
    if (!user) setStatus("signedOut");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id, isLoaded]);

  // Debounced push after local edits.
  useEffect(() => {
    if (!user || !isLoaded) return;
    if (data.modifiedAt <= lastPushedAt.current) return;
    if (pushTimer.current !== null) window.clearTimeout(pushTimer.current);
    pushTimer.current = window.setTimeout(() => {
      if (syncingRef.current || !navigator.onLine) return;
      setStatus("syncing");
      push(dataRef.current)
        .then(() => {
          setLastSyncedAt(Date.now());
          setStatus("idle");
        })
        .catch(handleFailure);
    }, 3000);
    return () => {
      if (pushTimer.current !== null) window.clearTimeout(pushTimer.current);
    };
  }, [data.modifiedAt, user, isLoaded, push, handleFailure]);

  // Re-sync when the tab regains focus or the network returns.
  useEffect(() => {
    const onOnline = () => void syncNow();
    const onOffline = () => user && setStatus("offline");
    const onVisible = () => {
      if (document.visibilityState === "visible") void syncNow();
    };
    window.addEventListener("online", onOnline);
    window.addEventListener("offline", onOffline);
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      window.removeEventListener("online", onOnline);
      window.removeEventListener("offline", onOffline);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [syncNow, user]);

  const exchangeCode = useCallback(async (code: string) => {
    const verifier = readStorage(CODE_VERIFIER_KEY);
    if (!verifier) {
      setError("Sign-in expired — please try again.");
      return;
    }
    localStorage.removeItem(CODE_VERIFIER_KEY);
    const response = await fetch(`${AUTH_URL}/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ app_key: APP_KEY, code, code_verifier: verifier }),
    });
    if (!response.ok) {
      const body = (await response.json().catch(() => ({}))) as { error?: string };
      setError(body.error ?? `Sign-in failed (${response.status})`);
      return;
    }
    const tokens = (await response.json()) as {
      access_token: string;
      refresh_token: string;
      user: CloudUser;
    };
    localStorage.setItem(ACCESS_TOKEN_KEY, tokens.access_token);
    localStorage.setItem(REFRESH_TOKEN_KEY, tokens.refresh_token);
    setUser(tokens.user);
  }, []);

  const signIn = useCallback(
    async (provider: "google" | "apple") => {
      if (!AUTH_URL || !APP_KEY) {
        setError("Sign-in isn't configured for this build.");
        return;
      }
      setIsSigningIn(true);
      setError(null);
      try {
        const bytes = new Uint8Array(32);
        crypto.getRandomValues(bytes);
        const verifier = base64URL(bytes);
        localStorage.setItem(CODE_VERIFIER_KEY, verifier);

        const isPreview = window.parent !== window;
        const body: Record<string, unknown> = {
          app_key: APP_KEY,
          provider,
          code_challenge: await codeChallenge(verifier),
          target: "web",
          env: isPreview ? "preview" : "production",
        };
        if (isPreview) body.app_path = "web-paddle-up";

        const response = await fetch(`${AUTH_URL}/oauth/initiate`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        });
        if (!response.ok) {
          localStorage.removeItem(CODE_VERIFIER_KEY);
          const errorBody = (await response.json().catch(() => ({}))) as { error?: string };
          setError(errorBody.error ?? `Sign-in failed (${response.status})`);
          return;
        }
        const { auth_url } = (await response.json()) as { auth_url: string };

        if (!isPreview) {
          window.location.href = auth_url;
          return;
        }
        const popup = window.open(auth_url, "_blank", "width=500,height=650");
        if (!popup) {
          localStorage.removeItem(CODE_VERIFIER_KEY);
          setError("Popup blocked — please allow popups for this site.");
          return;
        }
        await new Promise<void>((resolve) => {
          const onMessage = async (event: MessageEvent) => {
            const payload = event.data as { type?: string; code?: string } | null;
            if (payload?.type !== "rork_auth_callback") return;
            window.removeEventListener("message", onMessage);
            window.clearInterval(poll);
            if (payload.code) await exchangeCode(payload.code);
            resolve();
          };
          window.addEventListener("message", onMessage);
          const poll = window.setInterval(() => {
            if (popup.closed) {
              window.clearInterval(poll);
              window.removeEventListener("message", onMessage);
              resolve();
            }
          }, 500);
        });
      } catch {
        localStorage.removeItem(CODE_VERIFIER_KEY);
        setError("Sign-in failed. Check your connection and try again.");
      } finally {
        setIsSigningIn(false);
      }
    },
    [exchangeCode],
  );

  const deleteCloudData = useCallback(async () => {
    try {
      const response = await request("DELETE");
      if (response.ok) {
        signOut();
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }, [request, signOut]);

  const value = useMemo<CloudValue>(
    () => ({
      user,
      isLoading,
      isSigningIn,
      error,
      status,
      lastSyncedAt,
      signIn,
      signOut,
      clearError: () => setError(null),
      exchangeCode,
      syncNow,
      deleteCloudData,
    }),
    [
      user,
      isLoading,
      isSigningIn,
      error,
      status,
      lastSyncedAt,
      signIn,
      signOut,
      exchangeCode,
      syncNow,
      deleteCloudData,
    ],
  );

  return <CloudContext.Provider value={value}>{children}</CloudContext.Provider>;
}

export function useCloud(): CloudValue {
  const context = useContext(CloudContext);
  if (!context) throw new Error("useCloud must be used inside CloudProvider");
  return context;
}
