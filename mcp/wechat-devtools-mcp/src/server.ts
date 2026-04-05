import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FastMCP } from "fastmcp";
import { z } from "zod";

type ProcessRun = {
  status: number;
  stdout: string;
  stderr: string;
  error: string;
};

type ValidationSummary = {
  success: boolean;
  passed: number;
  failed: number;
};

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const WORKSPACE_ROOT = path.resolve(__dirname, "..", "..", "..");
const PROBE_SCRIPT = path.join(WORKSPACE_ROOT, "probe-automator.js");
const TEST_SCRIPT = path.join(WORKSPACE_ROOT, "scripts", "test-wechat-skill.ps1");
const DEPLOY_SCRIPT = path.join(WORKSPACE_ROOT, "wechat-deploy.js");
const PROJECT_STATE_FILE = path.join(WORKSPACE_ROOT, "PROJECT_STATE.md");

function runProcess(command: string, args: string[], timeoutMs = 120000): ProcessRun {
  const result = spawnSync(command, args, {
    cwd: WORKSPACE_ROOT,
    encoding: "utf8",
    timeout: timeoutMs,
    windowsHide: true
  });

  return {
    status: result.status ?? 1,
    stdout: (result.stdout || "").trim(),
    stderr: (result.stderr || "").trim(),
    error: result.error ? String(result.error.message || result.error) : ""
  };
}

function firstJsonObject(text: string): Record<string, unknown> | null {
  const lines = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  for (let i = lines.length - 1; i >= 0; i -= 1) {
    if (!lines[i].startsWith("{")) {
      continue;
    }

    try {
      return JSON.parse(lines[i]) as Record<string, unknown>;
    } catch {
      // Keep scanning older lines.
    }
  }

  return null;
}

function parseValidationSummary(output: string): ValidationSummary {
  const successMatch = output.match(/"success"\s*:\s*(true|false)/);
  const passedMatch = output.match(/"passed"\s*:\s*(\d+)/);
  const failedMatch = output.match(/"failed"\s*:\s*(\d+)/);

  return {
    success: successMatch ? successMatch[1] === "true" : false,
    passed: passedMatch ? Number(passedMatch[1]) : 0,
    failed: failedMatch ? Number(failedMatch[1]) : 0
  };
}

function toContent(payload: unknown): string {
  return JSON.stringify(payload, null, 2);
}

export const server = new FastMCP({
  name: "wechat-devtools-mcp-readonly",
  version: "1.0.0"
});

server.addTool({
  name: "get_current_page",
  description: "Get current WeChat page path/query from probe-automator.js (readonly).",
  parameters: z.object({}),
  execute: async () => {
    const run = runProcess("node", [PROBE_SCRIPT], 45000);
    const parsed = firstJsonObject(run.stdout);

    return toContent({
      ok: run.status === 0 && !!parsed,
      status: run.status,
      page: parsed ? { path: parsed.path || "", query: parsed.query || {} } : null,
      error: run.status === 0 ? "" : run.stderr || run.error || "probe_failed"
    });
  }
});

server.addTool({
  name: "get_page_data",
  description: "Get page data keys and page elements from probe-automator.js (readonly).",
  parameters: z.object({}),
  execute: async () => {
    const run = runProcess("node", [PROBE_SCRIPT], 45000);
    const parsed = firstJsonObject(run.stdout);

    return toContent({
      ok: run.status === 0 && !!parsed,
      status: run.status,
      path: parsed?.path || "",
      data_keys: parsed?.data_keys || [],
      page_elements: parsed?.page_elements || {},
      error: run.status === 0 ? "" : run.stderr || run.error || "probe_failed"
    });
  }
});

server.addTool({
  name: "run_validation",
  description: "Run Layer 4 validation using test-wechat-skill.ps1 -SkipSmoke (readonly run).",
  parameters: z.object({}),
  execute: async () => {
    const run = runProcess(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", TEST_SCRIPT, "-SkipSmoke"],
      180000
    );
    const summary = parseValidationSummary(run.stdout);

    return toContent({
      ok: run.status === 0 && summary.success,
      status: run.status,
      summary,
      stderr: run.stderr || ""
    });
  }
});

server.addTool({
  name: "list_cloud_functions",
  description: "List cloud functions from deploy helper (readonly cloud-list mode).",
  parameters: z.object({}),
  execute: async () => {
    const run = runProcess("node", [DEPLOY_SCRIPT, "cloud-list"], 90000);
    const parsed = firstJsonObject(run.stdout);

    return toContent({
      ok: run.status === 0 && !!parsed,
      status: run.status,
      result: parsed || null,
      stderr: run.stderr || ""
    });
  }
});

server.addTool({
  name: "get_project_state",
  description: "Read PROJECT_STATE.md from workspace (readonly).",
  parameters: z.object({}),
  execute: async () => {
    const text = readFileSync(PROJECT_STATE_FILE, "utf8");
    return toContent({
      ok: true,
      path: PROJECT_STATE_FILE,
      content: text
    });
  }
});
