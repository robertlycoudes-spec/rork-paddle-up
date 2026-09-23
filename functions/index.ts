// functions/index.ts — Paddle Up backend (iOS app only).
//
// Routes
//   GET    /ping               health check
//   GET    /v1/account         the signed-in player's synced snapshot (404 if none)
//   PUT    /v1/account         upload a snapshot (last-write-wins by modifiedAt)
//   DELETE /v1/account         permanently delete the player's cloud data
//   POST   /v1/redeem-code     redeem a friend comp code → comp entitlement
//   GET    /v1/entitlement     the signed-in player's comp entitlement (or null)
//   GET    /admin              password-protected comp-code admin page
//   GET    /admin/api/codes    list codes + redemptions        (admin secret)
//   POST   /admin/api/codes    create a code                   (admin secret)
//   POST   /admin/api/codes/active  activate / deactivate      (admin secret)
//
// Identity comes from Rork Auth: the platform verifies the bearer token and
// stamps X-Rork-User-Id. Player routes without it are rejected with 401.
// Each user gets their own AccountStore Durable Object, addressed as
// `ios:<userID>`. The prefix is kept so existing iOS cloud data stays at the
// same address; Durable Objects created by the retired web app are left
// untouched and simply no longer reachable.
//
// Comp codes live in one CompCodes Durable Object ("global") and are entirely
// separate from Apple billing. Admin routes require the shared secret in
// PADDLEUP_ADMIN_SECRET, sent as the X-Admin-Secret header.

import { ADMIN_PAGE_HTML } from "./admin-page";

export { AccountStore } from "./account-store";
export { CompCodes } from "./comp-codes";

type Env = { DO: Fetcher; PADDLEUP_ADMIN_SECRET?: string };

const MAX_BODY_BYTES = 25 * 1024 * 1024;
const COMP_CODES_ID = "global";

function error(status: number, code: string): Response {
  return Response.json({ error: code }, { status, headers: { "Cache-Control": "no-store" } });
}

/** Constant-time comparison so the secret can't be guessed byte by byte. */
async function secretsMatch(provided: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  const left = new Uint8Array(a);
  const right = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  return diff === 0;
}

async function dispatch(
  env: Env,
  request: Request,
  className: string,
  id: string,
  path: string,
  extraHeaders: Record<string, string> = {},
): Promise<Response> {
  const url = new URL(request.url);
  url.pathname = path;
  const forwarded = new Request(url.toString(), request);
  forwarded.headers.set("X-Rork-DO-Class", className);
  forwarded.headers.set("X-Rork-DO-Id", id);
  for (const [key, value] of Object.entries(extraHeaders)) forwarded.headers.set(key, value);
  try {
    return await env.DO.fetch(forwarded);
  } catch (cause) {
    console.error(`${className} dispatch failed`, cause instanceof Error ? cause.message : "unknown");
    return error(502, "storage_unavailable");
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/ping") {
      return Response.json({ ok: true, now: new Date().toISOString() });
    }

    // MARK: Player routes (Rork Auth required)

    if (path === "/v1/account" || path === "/v1/redeem-code" || path === "/v1/entitlement") {
      const userID = request.headers.get("X-Rork-User-Id");
      if (!userID) return error(401, "sign_in_required");
      const email = request.headers.get("X-Rork-User-Email") ?? "";
      const identity = { "X-PaddleUp-User": userID, "X-PaddleUp-Email": email };

      if (path === "/v1/redeem-code") {
        if (request.method !== "POST") return error(405, "method_not_allowed");
        return dispatch(env, request, "CompCodes", COMP_CODES_ID, "/redeem", identity);
      }

      if (path === "/v1/entitlement") {
        if (request.method !== "GET") return error(405, "method_not_allowed");
        return dispatch(env, request, "CompCodes", COMP_CODES_ID, "/entitlement", identity);
      }

      if (!["GET", "PUT", "DELETE"].includes(request.method)) {
        return error(405, "method_not_allowed");
      }
      const length = Number(request.headers.get("Content-Length") ?? "0");
      if (length > MAX_BODY_BYTES) return error(413, "payload_too_large");

      const response = await dispatch(env, request, "AccountStore", `ios:${userID}`, "/v1/account", identity);
      if (request.method === "DELETE" && response.ok) {
        // Deleting cloud data also drops the email kept on comp redemptions.
        const forget = new Request(new URL("/forget", request.url).toString(), { method: "POST" });
        await dispatch(env, forget, "CompCodes", COMP_CODES_ID, "/forget", identity);
      }
      return response;
    }

    // MARK: Admin (shared secret)

    if (path === "/admin" || path === "/admin/") {
      return new Response(ADMIN_PAGE_HTML, {
        headers: {
          "Content-Type": "text/html; charset=utf-8",
          "Cache-Control": "no-store",
          "X-Robots-Tag": "noindex, nofollow",
          "X-Frame-Options": "DENY",
          "Referrer-Policy": "no-referrer",
        },
      });
    }

    if (path.startsWith("/admin/api/")) {
      const expected = env.PADDLEUP_ADMIN_SECRET ?? "";
      if (expected.length < 12) return error(503, "admin_secret_not_configured");
      const provided = request.headers.get("X-Admin-Secret") ?? "";
      if (!(await secretsMatch(provided, expected))) return error(401, "wrong_password");

      if (path === "/admin/api/codes" && request.method === "GET") {
        return dispatch(env, request, "CompCodes", COMP_CODES_ID, "/admin/codes");
      }
      if (path === "/admin/api/codes" && request.method === "POST") {
        return dispatch(env, request, "CompCodes", COMP_CODES_ID, "/admin/codes");
      }
      if (path === "/admin/api/codes/active" && request.method === "POST") {
        return dispatch(env, request, "CompCodes", COMP_CODES_ID, "/admin/codes/active");
      }
      return error(404, "not_found");
    }

    return error(404, "not_found");
  },
} satisfies ExportedHandler<Env>;
