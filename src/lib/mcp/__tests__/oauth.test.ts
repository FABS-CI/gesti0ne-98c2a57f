import { describe, it, expect } from "vitest";
import mcp from "../index";

describe("MCP server OAuth configuration", () => {
  it("declares an OAuth issuer that requires a valid JWT", () => {
    const cfg = mcp as unknown as {
      auth?: { type?: string; issuer?: string; acceptedAudiences?: string[] };
    };
    expect(cfg.auth).toBeDefined();
    expect(cfg.auth?.issuer).toMatch(/\/auth\/v1$/);
    expect(cfg.auth?.acceptedAudiences).toContain("authenticated");
  });

  it("exposes only read-only tools (defensive check)", () => {
    const cfg = mcp as unknown as {
      tools: Array<{ name: string; annotations?: { readOnlyHint?: boolean } }>;
    };
    for (const tool of cfg.tools) {
      expect(tool.annotations?.readOnlyHint, `tool ${tool.name} must be read-only`).toBe(true);
    }
  });
});

describe("MCP HTTP endpoint (integration, requires dev server)", () => {
  const base = process.env.MCP_TEST_BASE_URL;
  const maybeIt = base ? it : it.skip;

  maybeIt("rejects requests without a bearer token with 401", async () => {
    const res = await fetch(`${base}/mcp`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
      },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
    });
    expect(res.status).toBe(401);
  });

  maybeIt("rejects requests with an invalid JWT with 401", async () => {
    const res = await fetch(`${base}/mcp`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        Authorization: "Bearer not-a-real-jwt",
      },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
    });
    expect(res.status).toBe(401);
  });
});
