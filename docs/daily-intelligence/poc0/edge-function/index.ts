// POC-0: minimal stateless MCP server (Streamable HTTP, JSON responses).
// One tool: record_poc_write. Writes only to schema dwi_poc. Throwaway.
import postgres from "npm:postgres@3.4.4";

const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { max: 1, prepare: false });
const EXPECTED = { test_id: "CHATGPT-EXIT-001", title: "ChatGPT unattended external write test" };

async function sha256(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
const rpc = (id: unknown, result: unknown) => Response.json({ jsonrpc: "2.0", id, result });
const rpcErr = (id: unknown, code: number, message: string, status = 200) =>
  Response.json({ jsonrpc: "2.0", id, error: { code, message } }, { status });

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const ua = req.headers.get("user-agent") ?? "";
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const k = url.searchParams.get("k") ?? "";
  const [{ ok }] = await sql`select exists(select 1 from dwi_poc.token where sha256 = ${await sha256(k)}) as ok`;
  let body: any;
  try { body = await req.json(); } catch { body = null; }
  const method = body?.method ?? null;
  const tool = method === "tools/call" ? body?.params?.name ?? null : null;
  const log = async (outcome: string) =>
    (await sql`insert into dwi_poc.invocations (rpc_method, tool_name, user_agent, auth_ok, outcome)
               values (${method}, ${tool}, ${ua.slice(0, 300)}, ${ok}, ${outcome}) returning id`)[0].id;

  if (!ok) { await log("unauthorized"); return new Response("unauthorized", { status: 401 }); }
  if (!body || body.jsonrpc !== "2.0") { await log("bad_request"); return rpcErr(null, -32600, "invalid request", 400); }
  if (body.id === undefined) { await log("notification"); return new Response(null, { status: 202 }); }

  switch (method) {
    case "initialize":
      await log("initialize");
      return rpc(body.id, {
        protocolVersion: body.params?.protocolVersion ?? "2025-06-18",
        capabilities: { tools: {} },
        serverInfo: { name: "dwi-poc0", version: "0.0.1" },
      });
    case "ping":
      return rpc(body.id, {});
    case "tools/list":
      await log("tools_list");
      return rpc(body.id, { tools: [{
        name: "record_poc_write",
        description: "Records one fixed test row for the POC-0 unattended-write experiment. Call exactly once with test_id and title.",
        inputSchema: {
          type: "object",
          properties: { test_id: { type: "string" }, title: { type: "string" } },
          required: ["test_id", "title"], additionalProperties: false,
        },
      }] });
    case "tools/call": {
      const a = body.params?.arguments ?? {};
      if (tool !== "record_poc_write" || a.test_id !== EXPECTED.test_id || a.title !== EXPECTED.title) {
        await log("rejected_payload");
        return rpc(body.id, { isError: true, content: [{ type: "text", text: "rejected: payload must match the fixed POC-0 payload" }] });
      }
      const invId = await log("write_attempt");
      const src = url.searchParams.get("src") === "selftest" ? "claude_selftest" : "chatgpt_mcp";
      const [row] = await sql`insert into dwi_poc.writes (test_id, title, source, invocation_id)
                              values (${a.test_id}, ${a.title}, ${src}, ${invId}) returning id, committed_at`;
      return rpc(body.id, { content: [{ type: "text",
        text: `COMMITTED write_id=${row.id} committed_at=${new Date(row.committed_at).toISOString()}` }] });
    }
    default:
      await log("unknown_method");
      return rpcErr(body.id, -32601, "method not found");
  }
});
