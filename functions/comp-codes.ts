// functions/comp-codes.ts
//
// Friend comp codes — free Paddle Up Pro access granted by the developer,
// completely separate from Apple billing and App Store offer codes.
//
// A single `CompCodes` Durable Object (id "global") owns three things so that
// validating a code, recording the redemption and granting access happen in
// one atomic step (a DO processes one request at a time):
//
//   comp_code         the codes the admin created
//   comp_redemption   who redeemed which code, and when
//   comp_entitlement  each user's current comp access (source = "comp")
//
// A freeMonth code grants 30 days (stacked on top of any remaining comp
// time); a lifetime code grants access with no expiry (compExpiresAt = null).

import { DurableObject } from "cloudflare:workers";

type Env = { DO: Fetcher };

export type CompType = "freeMonth" | "lifetime";

const COMP_TYPES: ReadonlySet<string> = new Set(["freeMonth", "lifetime"]);
const FREE_MONTH_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_FAILED_ATTEMPTS = 10;
const ATTEMPT_WINDOW_MS = 60 * 60 * 1000;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

type CodeRow = {
  code_key: string;
  code: string;
  type: string;
  max_redemptions: number;
  created_at: number;
  expires_at: number | null;
  active: number;
  note: string | null;
};

type RedemptionRow = {
  code_key: string;
  user_id: string;
  email: string | null;
  redeemed_at: number;
};

type EntitlementRow = {
  user_id: string;
  type: string;
  comp_expires_at: number | null;
  code: string;
  granted_at: number;
};

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

/** Uppercase letters and digits only, so "pu-7k2m 9qx4" matches "PU-7K2M-9QX4". */
export function codeKey(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function displayCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/\s+/g, "");
}

function generateCode(): string {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  const chars = Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]);
  return `PU-${chars.slice(0, 4).join("")}-${chars.slice(4).join("")}`;
}

function entitlementJSON(row: EntitlementRow | null, now: number) {
  if (!row) return null;
  const active = row.comp_expires_at === null || row.comp_expires_at > now;
  return {
    isPro: active,
    entitlementSource: "comp",
    type: row.type,
    compExpiresAt: row.comp_expires_at,
    grantedAt: row.granted_at,
  };
}

export class CompCodes extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.createTables();
    });
  }

  private createTables(): void {
    const sql = this.ctx.storage.sql;
    sql.exec(`CREATE TABLE IF NOT EXISTS comp_code (
      code_key TEXT PRIMARY KEY,
      code TEXT NOT NULL,
      type TEXT NOT NULL,
      max_redemptions INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER,
      active INTEGER NOT NULL DEFAULT 1,
      note TEXT
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS comp_redemption (
      code_key TEXT NOT NULL,
      user_id TEXT NOT NULL,
      email TEXT,
      redeemed_at INTEGER NOT NULL,
      PRIMARY KEY (code_key, user_id)
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS comp_entitlement (
      user_id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      comp_expires_at INTEGER,
      code TEXT NOT NULL,
      granted_at INTEGER NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS redeem_failure (
      user_id TEXT NOT NULL,
      at INTEGER NOT NULL
    )`);
  }

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const route = `${request.method} ${url.pathname}`;
    const userID = request.headers.get("X-PaddleUp-User") ?? "";

    switch (route) {
      case "POST /redeem":
        return this.redeem(request, userID);
      case "GET /entitlement":
        return json({ entitlement: entitlementJSON(this.entitlementRow(userID), Date.now()) });
      case "POST /forget":
        // Account deletion: drop the email we kept for the admin list. The
        // user ID stays so the code's redemption limit remains accurate.
        this.ctx.storage.sql.exec("UPDATE comp_redemption SET email = NULL WHERE user_id = ?", userID);
        return json({ ok: true });
      case "GET /admin/codes":
        return json({ codes: this.listCodes() });
      case "POST /admin/codes":
        return this.createCode(request);
      case "POST /admin/codes/active":
        return this.setActive(request);
      default:
        return json({ error: "not_found" }, 404);
    }
  }

  // MARK: - Redemption

  private async redeem(request: Request, userID: string): Promise<Response> {
    if (!userID) return json({ error: "sign_in_required" }, 401);

    let body: { code?: unknown };
    try {
      body = (await request.json()) as { code?: unknown };
    } catch {
      return json({ error: "invalid_request" }, 400);
    }

    // Everything below is synchronous, so no other request can interleave
    // between validation and recording the redemption.
    const sql = this.ctx.storage.sql;
    const now = Date.now();
    sql.exec("DELETE FROM redeem_failure WHERE at < ?", now - ATTEMPT_WINDOW_MS);
    const failures =
      sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM redeem_failure WHERE user_id = ?", userID).toArray()[0]?.n ?? 0;
    if (failures >= MAX_FAILED_ATTEMPTS) return json({ error: "too_many_attempts" }, 429);

    const fail = (error: string, status: number): Response => {
      sql.exec("INSERT INTO redeem_failure (user_id, at) VALUES (?, ?)", userID, now);
      return json({ error }, status);
    };

    const key = typeof body.code === "string" ? codeKey(body.code) : "";
    if (key.length < 4 || key.length > 32) return fail("invalid_code", 404);

    const code = sql.exec<CodeRow>("SELECT * FROM comp_code WHERE code_key = ?", key).toArray()[0];
    if (!code) return fail("invalid_code", 404);
    if (code.active !== 1) return fail("inactive", 410);
    if (code.expires_at !== null && code.expires_at <= now) return fail("expired", 410);

    const alreadyUsed = sql
      .exec("SELECT 1 FROM comp_redemption WHERE code_key = ? AND user_id = ?", key, userID)
      .toArray().length > 0;
    if (alreadyUsed) return json({ error: "already_redeemed" }, 409);

    const used =
      sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM comp_redemption WHERE code_key = ?", key).toArray()[0]?.n ?? 0;
    if (used >= code.max_redemptions) return fail("exhausted", 410);

    const current = this.entitlementRow(userID);
    const hasLifetime = current !== null && current.comp_expires_at === null;
    if (hasLifetime) return json({ error: "already_lifetime" }, 409);

    let compExpiresAt: number | null;
    if (code.type === "lifetime") {
      compExpiresAt = null;
    } else {
      // Stack on any comp time still remaining so a second code isn't wasted.
      const base = Math.max(now, current?.comp_expires_at ?? now);
      compExpiresAt = base + FREE_MONTH_MS;
    }

    const email = request.headers.get("X-PaddleUp-Email");
    this.ctx.storage.transactionSync(() => {
      sql.exec(
        "INSERT INTO comp_redemption (code_key, user_id, email, redeemed_at) VALUES (?, ?, ?, ?)",
        key,
        userID,
        email && email.length > 0 ? email : null,
        now,
      );
      sql.exec(
        `INSERT INTO comp_entitlement (user_id, type, comp_expires_at, code, granted_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(user_id) DO UPDATE SET
           type = excluded.type,
           comp_expires_at = excluded.comp_expires_at,
           code = excluded.code,
           granted_at = excluded.granted_at`,
        userID,
        code.type,
        compExpiresAt,
        code.code,
        now,
      );
    });

    return json({
      ok: true,
      type: code.type,
      entitlement: entitlementJSON(this.entitlementRow(userID), now),
    });
  }

  private entitlementRow(userID: string): EntitlementRow | null {
    if (!userID) return null;
    return (
      this.ctx.storage.sql
        .exec<EntitlementRow>("SELECT * FROM comp_entitlement WHERE user_id = ?", userID)
        .toArray()[0] ?? null
    );
  }

  // MARK: - Admin

  private listCodes() {
    const sql = this.ctx.storage.sql;
    const now = Date.now();
    const redemptions = sql
      .exec<RedemptionRow>("SELECT * FROM comp_redemption ORDER BY redeemed_at DESC")
      .toArray();
    const byCode = new Map<string, RedemptionRow[]>();
    for (const row of redemptions) {
      const list = byCode.get(row.code_key) ?? [];
      list.push(row);
      byCode.set(row.code_key, list);
    }
    return sql
      .exec<CodeRow>("SELECT * FROM comp_code ORDER BY created_at DESC")
      .toArray()
      .map((row) => {
        const used = byCode.get(row.code_key) ?? [];
        let status = "active";
        if (row.active !== 1) status = "inactive";
        else if (row.expires_at !== null && row.expires_at <= now) status = "expired";
        else if (used.length >= row.max_redemptions) status = "used up";
        return {
          code: row.code,
          type: row.type,
          maxRedemptions: row.max_redemptions,
          createdAt: row.created_at,
          expiresAt: row.expires_at,
          active: row.active === 1,
          note: row.note,
          status,
          redemptions: used.map((r) => ({ userId: r.user_id, email: r.email, redeemedAt: r.redeemed_at })),
        };
      });
  }

  private async createCode(request: Request): Promise<Response> {
    let body: Record<string, unknown>;
    try {
      body = (await request.json()) as Record<string, unknown>;
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    const type = typeof body["type"] === "string" ? body["type"] : "";
    if (!COMP_TYPES.has(type)) return json({ error: "type must be freeMonth or lifetime" }, 400);

    const max = Number(body["maxRedemptions"]);
    if (!Number.isInteger(max) || max < 1 || max > 100_000) {
      return json({ error: "maxRedemptions must be a whole number from 1 to 100000" }, 400);
    }

    const now = Date.now();
    let expiresAt: number | null = null;
    if (body["expiresAt"] !== null && body["expiresAt"] !== undefined && body["expiresAt"] !== "") {
      const value = Number(body["expiresAt"]);
      if (!Number.isFinite(value) || value <= now) return json({ error: "expiresAt must be in the future" }, 400);
      expiresAt = Math.round(value);
    }

    const note = typeof body["note"] === "string" ? body["note"].trim().slice(0, 80) : "";
    const requested = typeof body["code"] === "string" ? displayCode(body["code"]) : "";

    const sql = this.ctx.storage.sql;
    let code = requested;
    if (code) {
      if (!/^[A-Z0-9-]{4,32}$/.test(code) || codeKey(code).length < 4) {
        return json({ error: "Codes use 4–32 letters, digits or hyphens" }, 400);
      }
      const taken = sql.exec("SELECT 1 FROM comp_code WHERE code_key = ?", codeKey(code)).toArray().length > 0;
      if (taken) return json({ error: "That code already exists" }, 409);
    } else {
      do {
        code = generateCode();
      } while (sql.exec("SELECT 1 FROM comp_code WHERE code_key = ?", codeKey(code)).toArray().length > 0);
    }

    sql.exec(
      `INSERT INTO comp_code (code_key, code, type, max_redemptions, created_at, expires_at, active, note)
       VALUES (?, ?, ?, ?, ?, ?, 1, ?)`,
      codeKey(code),
      code,
      type,
      max,
      now,
      expiresAt,
      note.length > 0 ? note : null,
    );
    return json({ ok: true, code }, 201);
  }

  private async setActive(request: Request): Promise<Response> {
    let body: { code?: unknown; active?: unknown };
    try {
      body = (await request.json()) as { code?: unknown; active?: unknown };
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
    if (typeof body.code !== "string" || typeof body.active !== "boolean") {
      return json({ error: "code and active are required" }, 400);
    }
    const key = codeKey(body.code);
    const exists = this.ctx.storage.sql.exec("SELECT 1 FROM comp_code WHERE code_key = ?", key).toArray().length > 0;
    if (!exists) return json({ error: "not_found" }, 404);
    this.ctx.storage.sql.exec("UPDATE comp_code SET active = ? WHERE code_key = ?", body.active ? 1 : 0, key);
    return json({ ok: true });
  }
}
