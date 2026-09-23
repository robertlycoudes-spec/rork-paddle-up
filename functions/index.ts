// functions/index.ts — Paddle Up backend.
//
// Routes
//   GET    /ping         health check
//   GET    /v1/account   the signed-in player's synced snapshot (404 if none)
//   PUT    /v1/account   upload a snapshot (last-write-wins by modifiedAt)
//   DELETE /v1/account   permanently delete the player's cloud data
//
// Identity comes from Rork Auth: the platform verifies the bearer token and
// stamps X-Rork-User-Id. Requests without it are rejected with 401.
// Each (platform, user) pair gets its own AccountStore Durable Object, because
// the iOS and web apps persist with different local encodings.

export { AccountStore } from "./account-store";

type Env = { DO: Fetcher };

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-PaddleUp-Platform",
  "Access-Control-Max-Age": "86400",
};

const PLATFORMS = new Set(["ios", "web"]);
const MAX_BODY_BYTES = 25 * 1024 * 1024;

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(CORS)) headers.set(key, value);
  return new Response(response.body, { status: response.status, headers });
}

function error(status: number, code: string): Response {
  return withCors(Response.json({ error: code }, { status }));
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    if (url.pathname === "/ping") {
      return withCors(Response.json({ ok: true, now: new Date().toISOString() }));
    }

    if (url.pathname === "/v1/account") {
      const userID = request.headers.get("X-Rork-User-Id");
      if (!userID) return error(401, "sign_in_required");

      const platform = (request.headers.get("X-PaddleUp-Platform") ?? "").toLowerCase();
      if (!PLATFORMS.has(platform)) return error(400, "unknown_platform");

      if (!["GET", "PUT", "DELETE"].includes(request.method)) {
        return error(405, "method_not_allowed");
      }

      const length = Number(request.headers.get("Content-Length") ?? "0");
      if (length > MAX_BODY_BYTES) return error(413, "payload_too_large");

      const forwarded = new Request(request.url, request);
      forwarded.headers.set("X-Rork-DO-Class", "AccountStore");
      forwarded.headers.set("X-Rork-DO-Id", `${platform}:${userID}`);
      forwarded.headers.set("X-PaddleUp-User", userID);
      forwarded.headers.set("X-PaddleUp-Platform", platform);

      try {
        const response = await env.DO.fetch(forwarded);
        return withCors(response);
      } catch (cause) {
        console.error("AccountStore dispatch failed", cause instanceof Error ? cause.message : "unknown");
        return error(502, "storage_unavailable");
      }
    }

    return error(404, "not_found");
  },
} satisfies ExportedHandler<Env>;
