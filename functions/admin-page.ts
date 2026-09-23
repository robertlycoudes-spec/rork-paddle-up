// functions/admin-page.ts
//
// The comp-code admin page, served at /admin. Static HTML — it holds no data
// and no secret. The password is typed in the browser, kept in sessionStorage
// for the tab only, and sent as X-Admin-Secret on each API call; the Worker
// checks it against PADDLEUP_ADMIN_SECRET. All server data is rendered via
// textContent, never innerHTML, so emails and notes can't inject markup.

export const ADMIN_PAGE_HTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Paddle Up · Comp codes</title>
<style>
  :root {
    --canvas: #0B0F0C; --surface: #151B16; --raised: #1C241D;
    --hairline: rgba(255,255,255,0.08); --lime: #C6FF3D; --lime-ink: #0A1005;
    --text: #F4F7F2; --text2: #8C968D; --text3: #5E6760; --alert: #FF5F52; --amber: #FFB020;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--canvas); color: var(--text);
    font: 15px/1.45 -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif; }
  main { max-width: 880px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 26px; font-weight: 800; margin: 0 0 4px; letter-spacing: -0.01em; }
  h2 { font-size: 11px; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase;
    color: var(--text3); margin: 32px 0 10px; }
  .sub { color: var(--text2); margin: 0 0 8px; }
  .card { background: var(--surface); border: 1px solid var(--hairline); border-radius: 16px; padding: 18px; }
  label { display: block; font-size: 12px; font-weight: 600; color: var(--text2); margin-bottom: 6px; }
  input, select { width: 100%; background: var(--raised); color: var(--text); border: 1px solid var(--hairline);
    border-radius: 10px; padding: 10px 12px; font: inherit; }
  input:focus, select:focus { outline: none; border-color: rgba(198,255,61,0.55); }
  .grid { display: grid; gap: 14px; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); }
  button { font: inherit; font-weight: 700; border: 0; border-radius: 999px; padding: 11px 20px; cursor: pointer; }
  .primary { background: var(--lime); color: var(--lime-ink); }
  .ghost { background: transparent; color: var(--text2); border: 1px solid var(--hairline); padding: 6px 12px; font-size: 13px; }
  button:disabled { opacity: 0.5; cursor: default; }
  .row { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
  .msg { font-size: 13px; margin-top: 12px; min-height: 18px; }
  .ok { color: var(--lime); } .err { color: var(--alert); }
  .code { font: 700 17px ui-monospace, "SF Mono", Menlo, monospace; letter-spacing: 0.04em; }
  .pill { font-size: 11px; font-weight: 700; padding: 3px 9px; border-radius: 999px; text-transform: uppercase; letter-spacing: 0.06em; }
  .s-active { background: rgba(198,255,61,0.16); color: var(--lime); }
  .s-inactive, .s-expired { background: rgba(255,95,82,0.14); color: var(--alert); }
  .s-used { background: rgba(255,176,32,0.14); color: var(--amber); }
  .meta { color: var(--text2); font-size: 13px; }
  .codes { display: flex; flex-direction: column; gap: 10px; }
  .redemptions { margin-top: 12px; border-top: 1px solid var(--hairline); padding-top: 10px; font-size: 13px; }
  .redemptions div { display: flex; justify-content: space-between; gap: 12px; padding: 4px 0; color: var(--text2); }
  .redemptions span:first-child { color: var(--text); word-break: break-all; }
  .empty { color: var(--text3); text-align: center; padding: 28px; }
  .hidden { display: none; }
  .copy { cursor: pointer; }
</style>
</head>
<body>
<main>
  <h1>Comp codes</h1>
  <p class="sub">Free Paddle Up Pro for friends. Separate from App Store offer codes.</p>

  <section id="login" class="card" style="margin-top:20px">
    <label for="secret">Admin password</label>
    <div class="row">
      <input id="secret" type="password" autocomplete="current-password" style="flex:1;min-width:220px">
      <button id="unlock" class="primary">Unlock</button>
    </div>
    <div id="loginMsg" class="msg err"></div>
  </section>

  <section id="app" class="hidden">
    <h2>New code</h2>
    <div class="card">
      <div class="grid">
        <div>
          <label for="type">Type</label>
          <select id="type">
            <option value="freeMonth">Free month (30 days)</option>
            <option value="lifetime">Lifetime</option>
          </select>
        </div>
        <div>
          <label for="max">Redemption limit</label>
          <input id="max" type="number" min="1" max="100000" value="1">
        </div>
        <div>
          <label for="expires">Expires (optional)</label>
          <input id="expires" type="date">
        </div>
        <div>
          <label for="custom">Custom code (optional)</label>
          <input id="custom" placeholder="Auto-generate" maxlength="32" autocapitalize="characters">
        </div>
        <div>
          <label for="note">Note (optional)</label>
          <input id="note" placeholder="Who it's for" maxlength="80">
        </div>
      </div>
      <div class="row" style="margin-top:16px">
        <button id="create" class="primary">Create code</button>
        <button id="logout" class="ghost">Lock</button>
      </div>
      <div id="createMsg" class="msg"></div>
    </div>

    <h2>All codes</h2>
    <div id="codes" class="codes"></div>
  </section>
</main>

<script>
(function () {
  var KEY = "pu-admin-secret";
  var $ = function (id) { return document.getElementById(id); };
  var secret = sessionStorage.getItem(KEY) || "";

  function api(method, path, body) {
    return fetch("/admin/api/" + path, {
      method: method,
      headers: { "Content-Type": "application/json", "X-Admin-Secret": secret },
      body: body ? JSON.stringify(body) : undefined
    }).then(function (res) {
      return res.json().catch(function () { return {}; }).then(function (data) {
        if (!res.ok) {
          var e = new Error(data.error || ("HTTP " + res.status));
          e.status = res.status; throw e;
        }
        return data;
      });
    });
  }

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined && text !== null) n.textContent = String(text);
    return n;
  }

  function fmt(ms) {
    return new Date(ms).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
  }

  function describeError(e) {
    if (e.status === 401) return "Wrong password.";
    if (e.status === 503) return "PADDLEUP_ADMIN_SECRET isn't set on the backend yet (12+ characters).";
    return e.message || "Something went wrong.";
  }

  function showApp(on) {
    $("login").classList.toggle("hidden", on);
    $("app").classList.toggle("hidden", !on);
  }

  function render(codes) {
    var list = $("codes");
    list.replaceChildren();
    if (!codes.length) { list.appendChild(el("div", "card empty", "No codes yet.")); return; }
    codes.forEach(function (c) {
      var card = el("div", "card");
      var top = el("div", "row");
      top.style.justifyContent = "space-between";
      var left = el("div", "row");
      var codeEl = el("span", "code copy", c.code);
      codeEl.title = "Click to copy";
      codeEl.onclick = function () { navigator.clipboard && navigator.clipboard.writeText(c.code); };
      left.appendChild(codeEl);
      var statusClass = c.status === "used up" ? "s-used" : "s-" + c.status;
      left.appendChild(el("span", "pill " + statusClass, c.status));
      top.appendChild(left);
      var toggle = el("button", "ghost", c.active ? "Deactivate" : "Activate");
      toggle.onclick = function () {
        toggle.disabled = true;
        api("POST", "codes/active", { code: c.code, active: !c.active }).then(load).catch(function (e) {
          alert(describeError(e)); toggle.disabled = false;
        });
      };
      top.appendChild(toggle);
      card.appendChild(top);

      var parts = [
        c.type === "lifetime" ? "Lifetime" : "Free month",
        c.redemptions.length + " / " + c.maxRedemptions + " used",
        "Created " + fmt(c.createdAt)
      ];
      if (c.expiresAt) parts.push("Expires " + fmt(c.expiresAt));
      var meta = el("div", "meta", parts.join("  ·  "));
      meta.style.marginTop = "6px";
      card.appendChild(meta);
      if (c.note) card.appendChild(el("div", "meta", c.note));

      if (c.redemptions.length) {
        var box = el("div", "redemptions");
        c.redemptions.forEach(function (r) {
          var line = el("div");
          line.appendChild(el("span", null, r.email || r.userId));
          line.appendChild(el("span", null, fmt(r.redeemedAt)));
          box.appendChild(line);
        });
        card.appendChild(box);
      }
      list.appendChild(card);
    });
  }

  function load() {
    return api("GET", "codes").then(function (data) { showApp(true); render(data.codes || []); });
  }

  function unlock() {
    secret = $("secret").value;
    $("loginMsg").textContent = "";
    load().then(function () {
      sessionStorage.setItem(KEY, secret);
    }).catch(function (e) {
      $("loginMsg").textContent = describeError(e);
      showApp(false);
    });
  }

  $("unlock").onclick = unlock;
  $("secret").addEventListener("keydown", function (e) { if (e.key === "Enter") unlock(); });
  $("logout").onclick = function () {
    sessionStorage.removeItem(KEY); secret = ""; $("secret").value = ""; showApp(false);
  };

  $("create").onclick = function () {
    var msg = $("createMsg");
    var btn = $("create");
    msg.className = "msg"; msg.textContent = "";
    var expires = $("expires").value;
    var body = {
      type: $("type").value,
      maxRedemptions: Number($("max").value),
      expiresAt: expires ? new Date(expires + "T23:59:59").getTime() : null,
      code: $("custom").value.trim() || undefined,
      note: $("note").value.trim() || undefined
    };
    btn.disabled = true;
    api("POST", "codes", body).then(function (data) {
      msg.className = "msg ok";
      msg.textContent = "Created " + data.code + " — click it below to copy.";
      $("custom").value = ""; $("note").value = "";
      return load();
    }).catch(function (e) {
      msg.className = "msg err"; msg.textContent = describeError(e);
    }).then(function () { btn.disabled = false; });
  };

  if (secret) load().catch(function () { sessionStorage.removeItem(KEY); secret = ""; showApp(false); });
})();
</script>
</body>
</html>`;
