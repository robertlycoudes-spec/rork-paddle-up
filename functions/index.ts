// functions/index.ts — Paddle Up backend (iOS app only).
//
// Routes
//   GET    /ping         health check
//   GET    /v1/account   the signed-in player's synced snapshot (404 if none)
//   PUT    /v1/account   upload a snapshot (last-write-wins by modifiedAt)
//   DELETE /v1/account   permanently delete the player's cloud data
//
// Identity comes from Rork Auth: the platform verifies the bearer token and
// stamps X-Rork-User-Id. Requests without it are rejected with 401.
// Each user gets their own AccountStore Durable Object, addressed as
// `ios:<userID>`. The prefix is kept so existing iOS cloud data stays at the
// same address; Durable Objects created by the retired web app are left
// untouched and simply no longer reachable.

export { AccountStore } from "./account-store";

type Env = { DO: Fetcher };

const MAX_BODY_BYTES = 25 * 1024 * 1024;

function error(status: number, code: string): Response {
  return Response.json({ error: code }, { status });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/ping") {
      return Response.json({ ok: true, now: new Date().toISOString() });
    }

    if (url.pathname === "/v1/account") {
      const userID = request.headers.get("X-Rork-User-Id");
      if (!userID) return error(401, "sign_in_required");

      if (!["GET", "PUT", "DELETE"].includes(request.method)) {
        return error(405, "method_not_allowed");
      }

      const length = Number(request.headers.get("Content-Length") ?? "0");
      if (length > MAX_BODY_BYTES) return error(413, "payload_too_large");

      const forwarded = new Request(request.url, request);
      forwarded.headers.set("X-Rork-DO-Class", "AccountStore");
      forwarded.headers.set("X-Rork-DO-Id", `ios:${userID}`);
      forwarded.headers.set("X-PaddleUp-User", userID);

      try {
        return await env.DO.fetch(forwarded);
      } catch (cause) {
        console.error("AccountStore dispatch failed", cause instanceof Error ? cause.message : "unknown");
        return error(502, "storage_unavailable");
      }
    }

    return error(404, "not_found");
  },
} satisfies ExportedHandler<Env>;
