// functions/account-store.ts
//
// One Durable Object per signed-in iOS user. Its SQLite database holds the
// player's synced data in tables that mirror the client's AccountData schema
// (PlayerProfile, AppSettings, Session, Rep, MechanicHistory, PracticePlan,
// Achievement, UserFeedback). Field names inside each row's JSON are exactly
// the client's — the server never renames or reshapes them.
//
// Sync is local-first, last-write-wins at the account level: a PUT only lands
// when its `modifiedAt` is at least as new as what is stored. No merging.

import { DurableObject } from "cloudflare:workers";

type Env = { DO: Fetcher };

type JSONObject = Record<string, unknown>;

interface AccountPayload {
  profile?: JSONObject | null;
  settings?: JSONObject | null;
  plan?: JSONObject | null;
  sessions?: JSONObject[];
  mechanicHistory?: JSONObject[];
  achievements?: JSONObject[];
  feedback?: JSONObject[];
}

interface Snapshot {
  modifiedAt: number;
  schemaVersion: number;
  data: AccountPayload;
}

const json = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const idOf = (record: JSONObject, fallback: string): string => {
  const value = record["id"];
  return typeof value === "string" || typeof value === "number" ? String(value) : fallback;
};

const flag = (record: JSONObject | null | undefined, key: string): number =>
  record && record[key] === true ? 1 : 0;

const text = (record: JSONObject, key: string): string | null => {
  const value = record[key];
  return typeof value === "string" ? value : null;
};

const num = (record: JSONObject, key: string): number | null => {
  const value = record[key];
  return typeof value === "number" && Number.isFinite(value) ? value : null;
};

export class AccountStore extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.createTables();
    });
  }

  private createTables(): void {
    const sql = this.ctx.storage.sql;
    sql.exec(`CREATE TABLE IF NOT EXISTS account_meta (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_id TEXT NOT NULL,
      platform TEXT NOT NULL,
      modified_at INTEGER NOT NULL,
      schema_version INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS player_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      data TEXT NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS app_settings (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      share_anonymized_data INTEGER NOT NULL DEFAULT 0,
      data TEXT NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS practice_plan (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      data TEXT NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS session (
      id TEXT PRIMARY KEY,
      position INTEGER NOT NULL,
      shot TEXT,
      mode TEXT,
      shared_for_research INTEGER NOT NULL DEFAULT 0,
      data TEXT NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS rep (
      id TEXT NOT NULL,
      session_id TEXT NOT NULL,
      position INTEGER NOT NULL,
      shot TEXT,
      score REAL,
      shared_for_research INTEGER NOT NULL DEFAULT 0,
      data TEXT NOT NULL,
      PRIMARY KEY (session_id, id)
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS mechanic_history (
      id TEXT PRIMARY KEY,
      position INTEGER NOT NULL,
      shot TEXT,
      mechanic TEXT,
      score REAL,
      data TEXT NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS achievement (
      id TEXT PRIMARY KEY,
      position INTEGER NOT NULL,
      data TEXT NOT NULL
    )`);
    sql.exec(`CREATE TABLE IF NOT EXISTS user_feedback (
      id TEXT PRIMARY KEY,
      position INTEGER NOT NULL,
      data TEXT NOT NULL
    )`);
  }

  override async fetch(request: Request): Promise<Response> {
    const userID = request.headers.get("X-PaddleUp-User") ?? "";

    switch (request.method) {
      case "GET": {
        const snapshot = this.readSnapshot();
        return snapshot ? json(snapshot) : json({ error: "no_data" }, 404);
      }
      case "PUT": {
        let incoming: Snapshot;
        try {
          incoming = (await request.json()) as Snapshot;
        } catch {
          return json({ error: "invalid_json" }, 400);
        }
        if (
          typeof incoming?.modifiedAt !== "number" ||
          typeof incoming?.data !== "object" ||
          incoming.data === null
        ) {
          return json({ error: "invalid_snapshot" }, 400);
        }
        const storedModifiedAt = this.storedModifiedAt();
        // Last write wins: an older snapshot never overwrites a newer one.
        if (storedModifiedAt !== null && storedModifiedAt > incoming.modifiedAt) {
          return json({ error: "stale", snapshot: this.readSnapshot() }, 409);
        }
        this.writeSnapshot(incoming, userID);
        return json({ ok: true, modifiedAt: incoming.modifiedAt });
      }
      case "DELETE": {
        this.deleteAll();
        return json({ ok: true });
      }
      default:
        return json({ error: "method_not_allowed" }, 405);
    }
  }

  private storedModifiedAt(): number | null {
    const rows = this.ctx.storage.sql
      .exec<{ modified_at: number }>("SELECT modified_at FROM account_meta WHERE id = 1")
      .toArray();
    return rows[0]?.modified_at ?? null;
  }

  private writeSnapshot(snapshot: Snapshot, userID: string): void {
    const sql = this.ctx.storage.sql;
    const data = snapshot.data;
    const now = Date.now();

    this.ctx.storage.transactionSync(() => {
      this.clearTables();

      sql.exec(
        `INSERT INTO account_meta (id, user_id, platform, modified_at, schema_version, updated_at)
         VALUES (1, ?, 'ios', ?, ?, ?)`,
        userID,
        snapshot.modifiedAt,
        typeof snapshot.schemaVersion === "number" ? snapshot.schemaVersion : 1,
        now,
      );

      if (data.profile) {
        sql.exec("INSERT INTO player_profile (id, data) VALUES (1, ?)", JSON.stringify(data.profile));
      }
      if (data.settings) {
        sql.exec(
          "INSERT INTO app_settings (id, share_anonymized_data, data) VALUES (1, ?, ?)",
          flag(data.settings, "shareAnonymizedData"),
          JSON.stringify(data.settings),
        );
      }
      if (data.plan) {
        sql.exec("INSERT INTO practice_plan (id, data) VALUES (1, ?)", JSON.stringify(data.plan));
      }

      (data.sessions ?? []).forEach((session, sessionIndex) => {
        const sessionID = idOf(session, `session-${sessionIndex}`);
        const { reps, ...sessionRow } = session as JSONObject & { reps?: JSONObject[] };
        sql.exec(
          `INSERT OR REPLACE INTO session (id, position, shot, mode, shared_for_research, data)
           VALUES (?, ?, ?, ?, ?, ?)`,
          sessionID,
          sessionIndex,
          text(session, "shot"),
          text(session, "mode"),
          flag(session, "sharedForResearch"),
          JSON.stringify(sessionRow),
        );
        (Array.isArray(reps) ? reps : []).forEach((rep, repIndex) => {
          sql.exec(
            `INSERT OR REPLACE INTO rep (id, session_id, position, shot, score, shared_for_research, data)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            idOf(rep, `rep-${repIndex}`),
            sessionID,
            repIndex,
            text(rep, "shot"),
            num(rep, "score"),
            flag(rep, "sharedForResearch"),
            JSON.stringify(rep),
          );
        });
      });

      (data.mechanicHistory ?? []).forEach((point, index) => {
        sql.exec(
          `INSERT OR REPLACE INTO mechanic_history (id, position, shot, mechanic, score, data)
           VALUES (?, ?, ?, ?, ?, ?)`,
          idOf(point, `history-${index}`),
          index,
          text(point, "shot"),
          text(point, "mechanic"),
          num(point, "score"),
          JSON.stringify(point),
        );
      });

      (data.achievements ?? []).forEach((achievement, index) => {
        sql.exec(
          "INSERT OR REPLACE INTO achievement (id, position, data) VALUES (?, ?, ?)",
          idOf(achievement, `achievement-${index}`),
          index,
          JSON.stringify(achievement),
        );
      });

      (data.feedback ?? []).forEach((item, index) => {
        sql.exec(
          "INSERT OR REPLACE INTO user_feedback (id, position, data) VALUES (?, ?, ?)",
          idOf(item, `feedback-${index}`),
          index,
          JSON.stringify(item),
        );
      });
    });
  }

  private readSnapshot(): Snapshot | null {
    const sql = this.ctx.storage.sql;
    const meta = sql
      .exec<{ modified_at: number; schema_version: number }>(
        "SELECT modified_at, schema_version FROM account_meta WHERE id = 1",
      )
      .toArray()[0];
    if (!meta) return null;

    const single = (table: string): JSONObject | null => {
      const row = sql.exec<{ data: string }>(`SELECT data FROM ${table} WHERE id = 1`).toArray()[0];
      return row ? (JSON.parse(row.data) as JSONObject) : null;
    };
    const list = (table: string): JSONObject[] =>
      sql
        .exec<{ data: string }>(`SELECT data FROM ${table} ORDER BY position ASC`)
        .toArray()
        .map((row) => JSON.parse(row.data) as JSONObject);

    const repsBySession = new Map<string, JSONObject[]>();
    for (const row of sql
      .exec<{ session_id: string; data: string }>(
        "SELECT session_id, data FROM rep ORDER BY session_id, position ASC",
      )
      .toArray()) {
      const bucket = repsBySession.get(row.session_id) ?? [];
      bucket.push(JSON.parse(row.data) as JSONObject);
      repsBySession.set(row.session_id, bucket);
    }

    const sessions = sql
      .exec<{ id: string; data: string }>("SELECT id, data FROM session ORDER BY position ASC")
      .toArray()
      .map((row) => ({ ...(JSON.parse(row.data) as JSONObject), reps: repsBySession.get(row.id) ?? [] }));

    return {
      modifiedAt: meta.modified_at,
      schemaVersion: meta.schema_version,
      data: {
        profile: single("player_profile"),
        settings: single("app_settings"),
        plan: single("practice_plan"),
        sessions,
        mechanicHistory: list("mechanic_history"),
        achievements: list("achievement"),
        feedback: list("user_feedback"),
      },
    };
  }

  private clearTables(): void {
    const sql = this.ctx.storage.sql;
    for (const table of [
      "account_meta",
      "player_profile",
      "app_settings",
      "practice_plan",
      "session",
      "rep",
      "mechanic_history",
      "achievement",
      "user_feedback",
    ]) {
      sql.exec(`DELETE FROM ${table}`);
    }
  }

  private deleteAll(): void {
    this.ctx.storage.transactionSync(() => this.clearTables());
  }
}
