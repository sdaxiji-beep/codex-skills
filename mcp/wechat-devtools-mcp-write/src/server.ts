import { FastMCP } from "fastmcp";
import { z } from "zod";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const server = new FastMCP({
  name: "wechat-devtools-mcp-write",
  version: "0.1.0"
});

type WritePolicy = {
  enabled?: boolean;
  guardrails?: {
    allow_tools_before_policy_review?: boolean;
  };
};

function toContent(payload: unknown): string {
  return JSON.stringify(payload, null, 2);
}

const confirmationContract = {
  version: "write_confirm_v1",
  callback_type: "client_confirmation",
  required_fields: [
    "request_id",
    "action",
    "scope",
    "summary",
    "risk_level",
    "requires_explicit_yes",
    "expires_in_seconds"
  ],
  risk_levels: ["low", "medium", "high"]
} as const;

const previewToolGate = {
  env: "WECHAT_WRITE_TOOL_PREVIEW_ENABLE",
  required_value: "1"
} as const;

const previewExecutionGate = {
  env: "WECHAT_WRITE_TOOL_PREVIEW_EXECUTE_ENABLE",
  required_value: "1"
} as const;

type ConfirmationContract = {
  version: string;
  required_fields: string[];
  risk_levels: string[];
  default_ttl_seconds?: number;
};

function validateConfirmationPayload(input: {
  payload: unknown;
  expectedAction: string;
  expectedScope?: string;
  contract: ConfirmationContract;
}) {
  const issues: string[] = [];
  const payload = input.payload as Record<string, unknown>;

  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { valid: false, issues: ["payload_must_be_object"] };
  }

  for (const field of input.contract.required_fields) {
    if (!(field in payload)) {
      issues.push(`missing_field:${field}`);
      continue;
    }
    const value = payload[field];
    if (value === null || value === undefined) {
      issues.push(`null_field:${field}`);
      continue;
    }
    if (typeof value === "string" && value.trim().length === 0) {
      issues.push(`empty_field:${field}`);
    }
  }

  if ("action" in payload && payload.action !== input.expectedAction) {
    issues.push("action_mismatch");
  }

  if (input.expectedScope && "scope" in payload && payload.scope !== input.expectedScope) {
    issues.push("scope_mismatch");
  }

  if ("risk_level" in payload) {
    const riskLevel = String(payload.risk_level);
    if (!input.contract.risk_levels.includes(riskLevel)) {
      issues.push("invalid_risk_level");
    }
  }

  if ("requires_explicit_yes" in payload && payload.requires_explicit_yes !== true) {
    issues.push("requires_explicit_yes_must_be_true");
  }

  if ("expires_in_seconds" in payload) {
    const ttl = Number(payload.expires_in_seconds);
    if (!Number.isFinite(ttl) || ttl <= 0) {
      issues.push("invalid_expires_in_seconds");
    } else if (
      input.contract.default_ttl_seconds &&
      ttl > Number(input.contract.default_ttl_seconds)
    ) {
      issues.push("expires_in_seconds_exceeds_default_ttl");
    }
  }

  return { valid: issues.length === 0, issues };
}

function loadPolicy(): WritePolicy {
  const currentFile = fileURLToPath(import.meta.url);
  const currentDir = path.dirname(currentFile);
  const policyPath = path.resolve(currentDir, "../policy.json");
  const raw = fs.readFileSync(policyPath, "utf8");
  return JSON.parse(raw) as WritePolicy;
}

function getPreviewAuditLogPath() {
  const currentFile = fileURLToPath(import.meta.url);
  const currentDir = path.dirname(currentFile);
  return path.resolve(currentDir, "../../../artifacts/mcp-write-preview-audit.jsonl");
}

export function recordPreviewProjectAudit(input: {
  status: string;
  executeRequested: boolean;
  hasConfirmationPayload: boolean;
}) {
  const logPath = getPreviewAuditLogPath();
  const dir = path.dirname(logPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  const line = JSON.stringify({
    timestamp: new Date().toISOString(),
    tool: "preview_project",
    status: input.status,
    execute_requested: input.executeRequested,
    has_confirmation_payload: input.hasConfirmationPayload
  });
  fs.appendFileSync(logPath, `${line}\n`, "utf8");
  return logPath;
}

export function evaluatePreviewProjectContract(input: {
  desc?: string;
  confirmationPayload?: unknown;
  executeRequested?: boolean;
  toolFlagValue?: string;
  executionFlagValue?: string;
  policy: WritePolicy;
}) {
  const desc = input.desc || "";
  const contract = confirmationContract as unknown as ConfirmationContract;

  if (!input.policy.enabled || !input.policy.guardrails?.allow_tools_before_policy_review) {
    return {
      ok: false,
      status: "blocked_by_policy",
      tool: "preview_project",
      request: { desc },
      tool_gate: previewToolGate,
      confirmation_contract: confirmationContract,
      note: "No deploy action was executed."
    };
  }

  if (input.toolFlagValue !== previewToolGate.required_value) {
    return {
      ok: false,
      status: "blocked_by_tool_flag",
      tool: "preview_project",
      tool_gate: previewToolGate,
      confirmation_contract: confirmationContract,
      note: "No deploy action was executed."
    };
  }

  if (input.confirmationPayload) {
    const validation = validateConfirmationPayload({
      payload: input.confirmationPayload,
      expectedAction: "preview_project",
      contract
    });
    if (!validation.valid) {
      return {
        ok: false,
        status: "invalid_confirmation_payload",
        tool: "preview_project",
        request: { desc },
        tool_gate: previewToolGate,
        confirmation_contract: confirmationContract,
        confirmation_issues: validation.issues,
        note: "No deploy action was executed."
      };
    }

    return {
      ok: false,
      status: "confirmation_accepted",
      tool: "preview_project",
      request: { desc },
      tool_gate: previewToolGate,
      confirmation_contract: confirmationContract,
      execution_gate: previewExecutionGate,
      execution_requested: input.executeRequested === true
    };
  }

  return {
    ok: false,
    status: "confirmation_required",
    tool: "preview_project",
    request: { desc },
    tool_gate: previewToolGate,
    confirmation_contract: confirmationContract,
    confirmation_request_example: {
      request_id: "preview-<timestamp>",
      action: "preview_project",
      scope: "D:\\卤味",
      summary: desc || "Generate preview QR for current project state",
      risk_level: "low",
      requires_explicit_yes: true,
      expires_in_seconds: 300
    },
    required_before_execution: [
      "client must send explicit confirmation payload using write_confirm_v1",
      "Layer 4 validation should be green before preview execution",
      "release guard must remain enabled"
    ],
    note: "No deploy action was executed."
  };
}

export function resolvePreviewProjectRequest(input: {
  desc?: string;
  confirmationPayload?: unknown;
  execute?: boolean;
  toolFlagValue?: string;
  executionFlagValue?: string;
  policy: WritePolicy;
}) {
  const baseResult = evaluatePreviewProjectContract({
    desc: input.desc,
    confirmationPayload: input.confirmationPayload,
    executeRequested: input.execute === true,
    toolFlagValue: input.toolFlagValue,
    executionFlagValue: input.executionFlagValue,
    policy: input.policy
  }) as Record<string, unknown>;

  if (baseResult.status === "confirmation_accepted" && input.execute === true) {
    if (input.executionFlagValue !== previewExecutionGate.required_value) {
      return {
        ...baseResult,
        status: "blocked_by_execution_flag",
        ok: false,
        note: "Execution switch is off. No deploy action was executed."
      };
    }

    return {
      ...baseResult,
      status: "execution_permitted",
      ok: true,
      execution_ready: true,
      execution_status: "pending",
      note: "Execution gate passed. Deploy preview can proceed."
    };
  }

  return baseResult;
}

export function executePreviewProject(input: { desc?: string }) {
  const currentFile = fileURLToPath(import.meta.url);
  const currentDir = path.dirname(currentFile);
  const repoRoot = path.resolve(currentDir, "../../..");
  const entryScript = path.resolve(repoRoot, "scripts/wechat.ps1");

  if (!fs.existsSync(entryScript)) {
    return {
      ok: false,
      status: "execution_failed",
      reason: "entry_script_not_found",
      script: entryScript
    };
  }

  const escapedEntry = entryScript.replace(/'/g, "''");
  const escapedDesc = (input.desc || "").replace(/'/g, "''");
  const psCommand = [
    "$ErrorActionPreference='Stop'",
    `. '${escapedEntry}'`,
    `$result = Invoke-WechatPreview -Desc '${escapedDesc}' -RequireConfirm:$false`,
    "$result | ConvertTo-Json -Depth 10 -Compress"
  ].join("; ");

  const proc = spawnSync(
    "powershell",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", psCommand],
    {
      encoding: "utf8",
      timeout: 180000,
      windowsHide: true,
      maxBuffer: 8 * 1024 * 1024,
      env: {
        ...process.env,
        DEPLOY_AUTO_CONFIRM: process.env.DEPLOY_AUTO_CONFIRM || "yes"
      }
    }
  );

  const stderr = String(proc.stderr || "").trim();
  const stdout = String(proc.stdout || "").trim();
  const jsonLine = stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith("{"))
    .at(-1);

  if (proc.error) {
    return {
      ok: false,
      status: "execution_failed",
      reason: "powershell_spawn_error",
      error: String(proc.error.message || proc.error)
    };
  }

  if (!jsonLine) {
    return {
      ok: false,
      status: "execution_failed",
      reason: "missing_json_output",
      exit_code: proc.status ?? -1,
      stderr,
      stdout
    };
  }

  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = JSON.parse(jsonLine) as Record<string, unknown>;
  } catch (error) {
    return {
      ok: false,
      status: "execution_failed",
      reason: "invalid_json_output",
      exit_code: proc.status ?? -1,
      stderr,
      stdout: jsonLine,
      error: String(error)
    };
  }

  const underlying = String(parsed.underlying_status || parsed.status || "");
  const isSuccess = underlying === "preview_ok" || String(parsed.status) === "success";
  return {
    ok: isSuccess,
    status: isSuccess ? "execution_completed" : "execution_failed",
    execution_status: underlying || (isSuccess ? "preview_ok" : "unknown"),
    exit_code: proc.status ?? 0,
    stderr,
    output: parsed
  };
}

server.addTool({
  name: "preview_project",
  description: "Guarded preview contract for phase3 first-tool rollout.",
  parameters: z.object({
    desc: z.string().min(1).max(120).optional(),
    confirmation_payload: z.record(z.string(), z.any()).optional(),
    execute: z.boolean().optional()
  }),
  execute: async (args) => {
    const policy = loadPolicy();
    let result = resolvePreviewProjectRequest({
      desc: args.desc,
      confirmationPayload: args.confirmation_payload,
      execute: args.execute === true,
      toolFlagValue: process.env[previewToolGate.env],
      executionFlagValue: process.env[previewExecutionGate.env],
      policy
    }) as Record<string, unknown>;

    if (result.status === "execution_permitted" && args.execute === true) {
      const executionResult = executePreviewProject({ desc: args.desc });
      result = {
        ...result,
        ...executionResult
      };
    }

    recordPreviewProjectAudit({
      status: String(result.status || "unknown"),
      executeRequested: args.execute === true,
      hasConfirmationPayload: Boolean(args.confirmation_payload)
    });
    return toContent(result);
  }
});
