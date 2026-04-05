import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { server } from "./server.js";

type Policy = {
  enabled?: boolean;
  activation?: {
    env?: string;
    required_value?: string;
  };
  guardrails?: {
    require_explicit_enable?: boolean;
    allow_tools_before_policy_review?: boolean;
  };
};

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const policyPath = path.resolve(__dirname, "..", "policy.json");

function loadPolicy(): Policy {
  const raw = readFileSync(policyPath, "utf8");
  return JSON.parse(raw) as Policy;
}

const policy = loadPolicy();
const activationEnv = policy.activation?.env || "WECHAT_WRITE_MCP_ENABLE";
const activationValue = policy.activation?.required_value || "1";

if (policy.guardrails?.require_explicit_enable && policy.enabled !== true) {
  console.error(`wechat-devtools-mcp-write is disabled by policy: ${policyPath}`);
  process.exit(2);
}

if (process.env[activationEnv] !== activationValue) {
  console.error(`wechat-devtools-mcp-write is disabled. Set ${activationEnv}=${activationValue} to start it.`);
  process.exit(2);
}

if (policy.guardrails?.allow_tools_before_policy_review === false) {
  console.error("wechat-devtools-mcp-write has no approved tools yet. Startup is blocked until policy review completes.");
  process.exit(2);
}

server.start({
  transportType: "stdio"
});
