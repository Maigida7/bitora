/**
 * BITORA Cloudflare Worker — starter only.
 * This is not the complete production backend. It intentionally does not
 * implement payments, rewards, Telegram authentication, or admin actions yet.
 */
const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" }
});

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-methods": "GET, POST, OPTIONS",
        "access-control-allow-headers": "content-type, x-telegram-init-data",
        "access-control-max-age": "86400"
      }});
    }
    if (url.pathname === "/api/health" && request.method === "GET") {
      return json({ app: "BITORA", status: "ok", stage: "development" });
    }
    if (url.pathname === "/api/db-check" && request.method === "GET") {
      if (!env.DB) return json({ ok: false, error: "D1 binding DB is missing" }, 500);
      try {
        const result = await env.DB.prepare("SELECT COUNT(*) AS table_count FROM sqlite_master WHERE type = 'table'").first();
        return json({ ok: true, database: "connected", table_count: result?.table_count ?? 0 });
      } catch (error) {
        return json({ ok: false, error: "Database query failed" }, 500);
      }
    }
    return json({ app: "BITORA", error: "Not found" }, 404);
  }
};
