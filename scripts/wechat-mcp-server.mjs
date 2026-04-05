#!/usr/bin/env node
/**
 * Thin MCP-native adapter for this repo.
 *
 * Public surface rules:
 * - tools expose the stable boundary operations
 * - resources expose read-only discovery and client guidance
 * - prompts generate draft payloads before any write
 * - keep payloads repo-relative when possible; avoid machine-local paths in public examples
 *
 * Assumptions:
 * - Windows / PowerShell is available for the existing boundary script.
 * - Prefer root package dependencies for MCP SDK / zod.
 * - Fall back to the legacy nested workspace only for backward compatibility in local checkouts.
 * - This server intentionally keeps the boundary script as the execution kernel while exposing
 *   tools, prompts, and a small set of fixed resources.
 */

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');

const boundaryScript = process.env.WECHAT_MCP_BOUNDARY_SCRIPT
  ? path.resolve(process.env.WECHAT_MCP_BOUNDARY_SCRIPT)
  : path.join(repoRoot, 'scripts', 'wechat-mcp-tool-boundary.ps1');
const taskPipelineBridgeScript = process.env.WECHAT_MCP_TASK_PIPELINE_BRIDGE
  ? path.resolve(process.env.WECHAT_MCP_TASK_PIPELINE_BRIDGE)
  : path.join(repoRoot, 'scripts', 'wechat-mcp-pipeline-bridge.ps1');

function assertPathExists(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${label} not found: ${filePath}`);
  }
}

assertPathExists(boundaryScript, 'Boundary script');
assertPathExists(taskPipelineBridgeScript, 'Task pipeline bridge script');

async function importMcpRuntime() {
  const explicitSdkRoot = process.env.WECHAT_MCP_SDK_ROOT
    ? path.resolve(process.env.WECHAT_MCP_SDK_ROOT)
    : null;
  const explicitZodEntry = process.env.WECHAT_MCP_ZOD_ENTRY
    ? path.resolve(process.env.WECHAT_MCP_ZOD_ENTRY)
    : null;

  if (explicitSdkRoot) {
    assertPathExists(path.join(explicitSdkRoot, 'server', 'mcp.js'), 'MCP SDK server module');
    assertPathExists(path.join(explicitSdkRoot, 'server', 'stdio.js'), 'MCP SDK stdio module');
  }

  if (explicitZodEntry) {
    assertPathExists(explicitZodEntry, 'Zod entry module');
  }

  try {
    const [{ McpServer }, { StdioServerTransport }, zodModule] = await Promise.all([
      explicitSdkRoot
        ? import(pathToFileURL(path.join(explicitSdkRoot, 'server', 'mcp.js')).href)
        : import('@modelcontextprotocol/sdk/server/mcp.js'),
      explicitSdkRoot
        ? import(pathToFileURL(path.join(explicitSdkRoot, 'server', 'stdio.js')).href)
        : import('@modelcontextprotocol/sdk/server/stdio.js'),
      explicitZodEntry
        ? import(pathToFileURL(explicitZodEntry).href)
        : import('zod')
    ]);

    return {
      McpServer,
      StdioServerTransport,
      z: zodModule.z ?? zodModule.default ?? zodModule
    };
  } catch (rootError) {
    const legacySdkRoot = path.join(repoRoot, 'mcp', 'wechat-devtools-mcp', 'node_modules', '@modelcontextprotocol', 'sdk', 'dist', 'esm');
    const legacyZodEntry = path.join(repoRoot, 'mcp', 'wechat-devtools-mcp', 'node_modules', 'zod', 'v4', 'index.js');
    assertPathExists(path.join(legacySdkRoot, 'server', 'mcp.js'), 'Legacy MCP SDK server module');
    assertPathExists(path.join(legacySdkRoot, 'server', 'stdio.js'), 'Legacy MCP SDK stdio module');
    assertPathExists(legacyZodEntry, 'Legacy zod entry module');

    const [{ McpServer }, { StdioServerTransport }, zodModule] = await Promise.all([
      import(pathToFileURL(path.join(legacySdkRoot, 'server', 'mcp.js')).href),
      import(pathToFileURL(path.join(legacySdkRoot, 'server', 'stdio.js')).href),
      import(pathToFileURL(legacyZodEntry).href)
    ]);

    return {
      McpServer,
      StdioServerTransport,
      z: zodModule.z ?? zodModule.default ?? zodModule,
      runtimeWarning: rootError instanceof Error ? rootError.message : String(rootError)
    };
  }
}

const { McpServer, StdioServerTransport, z, runtimeWarning } = await importMcpRuntime();

const server = new McpServer(
  {
    name: 'wechat-devtools-control-mcp',
    version: '1.0.0'
  },
  {
    instructions:
      'Thin MCP adapter over the repo boundary script. Use read-only resources first to discover the live surface, keep payloads repo-relative when possible, and prefer prompts for draft generation before validate/apply writes.'
  }
);

const registeredTools = [];
const registeredPrompts = [];
const registeredResources = [];

const emptySchema = z.object({}).strict();
const boundaryPayloadSchema = z
  .object({
    jsonPayload: z.string().optional(),
    jsonFilePath: z.string().optional(),
    targetWorkspace: z.string().optional()
  })
  .strict();

const taskPipelineSchema = z
  .object({
    prompt: z.string().min(1),
    open: z.boolean().optional()
  })
  .strict();

function resourceText(uri, mimeType, text) {
  return {
    contents: [
      {
        uri,
        mimeType,
        text
      }
    ]
  };
}

function promptText(lines) {
  return {
    type: 'text',
    text: lines.join('\n')
  };
}

function readRepoFile(relativePath, fallbackText = '') {
  const fullPath = path.join(repoRoot, relativePath);
  if (!fs.existsSync(fullPath)) {
    return fallbackText;
  }
  return fs.readFileSync(fullPath, 'utf8');
}

function renderInventoryMarkdown() {
  const toBulletList = (items) => {
    if (!items.length) {
      return '- none';
    }

    return items.map((item) => `- ${item}`).join('\n');
  };

  return [
    '# MCP Server Inventory',
    '',
    '## Registered Tools',
    toBulletList(registeredTools),
    '',
    '## Registered Prompts',
    toBulletList(registeredPrompts),
    '',
    '## Registered Resources',
    toBulletList(registeredResources),
    '',
    '## Notes',
    '- This inventory is read-only and mirrors the live MCP registration surface.',
    '- The PowerShell boundary script remains the execution kernel for validate/apply tools.',
    '- Use this resource in inspector clients to quickly confirm exposure without invoking a tool.'
  ].join('\n');
}

function renderPathConventionsMarkdown() {
  return [
    '# MCP Path Conventions',
    '',
    '## Purpose',
    'Keep examples clone-agnostic, repo-relative, and safe for any checkout of this repository.',
    '',
    '## Rules',
    '- Treat the current repository root as the only anchor you need.',
    '- Prefer repo-relative paths such as `scripts/wechat-mcp-server.mjs` or `diagnostics/Test-DiagnosticsMetricsWriter.ps1`.',
    '- Avoid machine-local paths in prompts, docs, and payload examples unless a tool explicitly requires a local file path.',
    '- When a resource or tool accepts a path, start from the repo root and keep the path minimal.',
    '',
    '## Examples',
    '- Good: `scripts/wechat-mcp-tool-boundary.ps1`',
    '- Good: `diagnostics/METRICS_SUMMARY.md`',
    '- Good: `mcp/wechat-devtools-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm`',
    '- Avoid: `<user-home>/...` or other user-specific checkout paths',
    '',
    '## Notes',
    '- This resource is read-only.',
    '- It is intended for both inspector clients and automation clients.',
    '- Use it alongside `server_inventory` and `read_order` when a path is involved.'
  ].join('\n');
}

function renderPromptSelectionGuideMarkdown() {
  return [
    '# MCP Prompt Selection Guide',
    '',
    '## Purpose',
    'Map common tasks to the smallest prompt that can draft a safe payload before any write.',
    '',
    '## Rules',
    '- Start with a read-only resource if you are unsure.',
    '- Use prompts to draft, not to write directly.',
    '- Keep examples repo-relative and clone-agnostic.',
    '',
    '## Prompt -> Use',
    '- `generate_page_bundle` -> draft a page bundle for a single page path.',
    '- `generate_component_bundle` -> draft a component bundle for a single component.',
    '- `repair_page_issue` -> turn diagnostics into a narrow repair plan.',
    '- `patch_app_routes` -> draft a minimal app.json append_pages patch.',
    '',
    '## When to choose a prompt',
    '- If the task is page creation, choose `generate_page_bundle`.',
    '- If the task is component creation, choose `generate_component_bundle`.',
    '- If the task is diagnosis or repair, choose `repair_page_issue`.',
    '- If the task is route addition, choose `patch_app_routes`.',
    '',
    '## Notes',
    '- This resource is read-only.',
    '- It is intended for inspector and consumer clients.',
    '- Use it together with `server_inventory`, `read_order`, and `tool_selection_guide`.'
  ].join('\n');
}

function renderConsumerRouterMarkdown() {
  return [
    '# MCP Consumer Router',
    '',
    '## Purpose',
    'Provide a deterministic first-hop guide for inspector and consumer clients before they choose a prompt or tool.',
    '',
    '## Route',
    '- Need to confirm what exists? -> `wechat://server-inventory`',
    '- Need a consistent read-first path? -> `wechat://read-order`',
    '- Need repo-relative path rules? -> `wechat://path-conventions`',
    '- Need to choose a draft prompt? -> `wechat://prompt-selection-guide`',
    '- Need to choose the narrowest safe tool? -> `wechat://tool-selection-guide`',
    '- Need to validate or apply? -> read the relevant contract first, then validate, then apply.',
    '- Need diagnosis or repair? -> inspect `wechat://latest-diagnostics-metrics` before retrying.',
    '',
    '## Notes',
    '- This resource is read-only.',
    '- It is intended to reduce guesswork for new clients.',
    '- Keep all example payloads repo-relative and clone-agnostic.'
  ].join('\n');
}

function buildBoundaryArgs(params = {}) {
  const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', boundaryScript, '-Operation', params.operation];

  if (typeof params.jsonPayload === 'string' && params.jsonPayload.length > 0) {
    args.push('-JsonPayload', params.jsonPayload);
  }

  if (typeof params.jsonFilePath === 'string' && params.jsonFilePath.length > 0) {
    args.push('-JsonFilePath', params.jsonFilePath);
  }

  if (typeof params.targetWorkspace === 'string' && params.targetWorkspace.length > 0) {
    args.push('-TargetWorkspace', params.targetWorkspace);
  }

  return args;
}

function runBoundary(operation, params = {}) {
  const powershellExe = process.env.WECHAT_MCP_POWERSHELL || 'powershell';
  const args = buildBoundaryArgs({
    operation,
    ...params
  });

  const result = spawnSync(powershellExe, args, {
    encoding: 'utf8',
    windowsHide: true,
    maxBuffer: 20 * 1024 * 1024
  });

  const stdout = typeof result.stdout === 'string' ? result.stdout.trim() : '';
  const stderr = typeof result.stderr === 'string' ? result.stderr.trim() : '';
  const exitCode =
    typeof result.status === 'number'
      ? result.status
      : typeof result.signal === 'string'
        ? 1
        : 1;

  return {
    exitCode,
    stdout,
    stderr,
    error: result.error ? result.error.message : ''
  };
}

function formatToolResult(operation, boundaryResult) {
  if (boundaryResult.exitCode === 0) {
    return {
      content: [
        {
          type: 'text',
          text:
            boundaryResult.stdout ||
            JSON.stringify(
              {
                operation,
                status: 'success',
                note: 'boundary returned no stdout payload'
              },
              null,
              2
            )
        }
      ]
    };
  }

  return {
    isError: true,
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            operation,
            status: 'error',
            boundary_exit_code: boundaryResult.exitCode,
            stdout: boundaryResult.stdout,
            stderr: boundaryResult.stderr,
            spawn_error: boundaryResult.error || undefined
          },
          null,
          2
        )
      }
    ]
  };
}

function runTaskPipeline(prompt, open = false) {
  const powershellExe = process.env.WECHAT_MCP_POWERSHELL || 'powershell';
  const args = [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    taskPipelineBridgeScript,
    '-Prompt',
    prompt,
    '-Open',
    open ? 'true' : 'false',
    '-Output',
    'json'
  ];

  const result = spawnSync(powershellExe, args, {
    cwd: repoRoot,
    encoding: 'utf8',
    windowsHide: true,
    maxBuffer: 20 * 1024 * 1024
  });

  const stdout = typeof result.stdout === 'string' ? result.stdout.trim() : '';
  const stderr = typeof result.stderr === 'string' ? result.stderr.trim() : '';
  const exitCode =
    typeof result.status === 'number'
      ? result.status
      : typeof result.signal === 'string'
        ? 1
        : 1;

  let parsed = null;
  if (stdout) {
    try {
      parsed = JSON.parse(stdout);
    } catch {
      parsed = firstJsonObject(stdout);
    }
  }

  if (exitCode === 0 && parsed) {
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(parsed, null, 2)
        }
      ]
    };
  }

  return {
    isError: true,
    content: [
      {
        type: 'text',
        text: JSON.stringify(
          {
            tool: 'run_task_pipeline',
            status: 'error',
            exit_code: exitCode,
            stdout,
            stderr,
            parsed,
            spawn_error: result.error ? String(result.error.message || result.error) : ''
          },
          null,
          2
        )
      }
    ]
  };
}

function registerTool(name, description, inputSchema) {
  registeredTools.push(name);
  server.registerTool(
    name,
    {
      title: name,
      description,
      inputSchema
    },
    async (params = {}) => {
      const boundaryResult = runBoundary(name, params);
      return formatToolResult(name, boundaryResult);
    }
  );
}

function registerPrompt(name, title, description, argsSchema, buildLines) {
  registeredPrompts.push(name);
  server.registerPrompt(
    name,
    {
      title,
      description,
      argsSchema
    },
    async (args = {}) => ({
      messages: [
        {
          role: 'user',
          content: promptText(buildLines(args))
        }
      ]
    })
  );
}

function registerResource(name, uri, meta, handler) {
  registeredResources.push(name);
  server.registerResource(name, uri, meta, handler);
}

registerTool(
  'describe_contract',
  'Return the boundary contract for the repo, including supported operations and exit-code mapping.',
  emptySchema
);

registerTool(
  'describe_execution_profile',
  'Return the execution profile for the boundary adapter, including platform and retry guidance.',
  emptySchema
);

registerTool(
  'validate_page_bundle',
  'Validate a page bundle through the existing PowerShell boundary script.',
  boundaryPayloadSchema
);

registerTool(
  'apply_page_bundle',
  'Apply a page bundle through the existing PowerShell boundary script.',
  boundaryPayloadSchema
);

registerTool(
  'validate_component_bundle',
  'Validate a component bundle through the existing PowerShell boundary script.',
  boundaryPayloadSchema
);

registerTool(
  'apply_component_bundle',
  'Apply a component bundle through the existing PowerShell boundary script.',
  boundaryPayloadSchema
);

registerTool(
  'validate_app_json_patch',
  'Validate an app.json patch through the existing PowerShell boundary script.',
  boundaryPayloadSchema
);

registerTool(
  'apply_app_json_patch',
  'Apply an app.json patch through the existing PowerShell boundary script.',
  boundaryPayloadSchema
);

registeredTools.push('run_task_pipeline');
server.registerTool(
  'run_task_pipeline',
  {
    title: 'run_task_pipeline',
    description:
      'Run the internal TaskSpec pipeline from natural-language prompt through translator, compiler, executor, and acceptance on the active repo-root workflow.',
    inputSchema: taskPipelineSchema
  },
  async ({ prompt, open = false }) => runTaskPipeline(prompt, open)
);

const generatePagePromptArgs = {
  pagePath: z.string().min(1).describe('Target page path, for example pages/home/index'),
  requirement: z.string().min(1).describe('Natural-language page requirement')
};

const generateComponentPromptArgs = {
  componentName: z.string().min(1).describe('Target component name, for example product-card'),
  requirement: z.string().min(1).describe('Natural-language component requirement')
};

const repairPagePromptArgs = {
  pagePath: z.string().min(1).describe('Target page path, for example pages/cart/index'),
  issueType: z.string().min(1).describe('Detected issue type'),
  repairHint: z.string().min(1).describe('Repair hint from diagnostics'),
  issueJson: z.string().optional().describe('Optional raw PageIssue JSON or console excerpt')
};

const patchRoutesPromptArgs = {
  appendPages: z.string().min(1).describe('Comma-separated page paths to append into app.json pages')
};

registerPrompt(
  'generate_page_bundle',
  'Generate Page Bundle',
  'Draft a page-level JSON bundle using the current page contracts, golden-path rules, and boundary validation flow.',
  generatePagePromptArgs,
  ({ pagePath, requirement }) => [
    `Generate a page-level JSON bundle for ${pagePath}.`,
    `Requirement: ${requirement}`,
    '',
    'Follow the repo contracts:',
    '- GOLDEN_PATH.md',
    '- MCP_BOUNDARY_CONTRACT.md',
    '- TEST_TIERS.md',
    '',
    'Constraints:',
    '- Output a single JSON bundle only.',
    '- Use only page-scoped files under pages/<name>/<name>.(wxml|js|wxss|json).',
    '- Do not modify app.js, app.wxss, project.config.json, or any other global file.',
    '- Keep the bundle aligned with validate_page_bundle and apply_page_bundle.'
  ]
);

registerPrompt(
  'generate_component_bundle',
  'Generate Component Bundle',
  'Draft a component-level JSON bundle using the current component contracts and boundary validation flow.',
  generateComponentPromptArgs,
  ({ componentName, requirement }) => [
    `Generate a custom component JSON bundle for ${componentName}.`,
    `Requirement: ${requirement}`,
    '',
    'Follow the repo contracts:',
    '- GOLDEN_PATH.md',
    '- MCP_BOUNDARY_CONTRACT.md',
    '- PUBLIC_API_SURFACE.md',
    '',
    'Constraints:',
    '- Output a single JSON bundle only.',
    '- Use only component-scoped files under components/<name>/index.(wxml|js|wxss|json).',
    '- Do not use Page({}); use Component({}) with component: true and properties.',
    '- Keep the bundle aligned with validate_component_bundle and apply_component_bundle.'
  ]
);

registerPrompt(
  'repair_page_issue',
  'Repair Page Issue',
  'Turn a PageIssue or console excerpt into a minimal page repair plan grounded in the current diagnostics and repair loop contracts.',
  repairPagePromptArgs,
  ({ pagePath, issueType, repairHint, issueJson }) => [
    `Repair the page issue for ${pagePath}.`,
    `issue_type: ${issueType}`,
    `repair_hint: ${repairHint}`,
    issueJson ? `raw_issue: ${issueJson}` : 'raw_issue: <not provided>',
    '',
    'Follow the repo contracts:',
    '- diagnostics/PageIssue contract',
    '- diagnostics/DETECTOR_BRIDGE_CONTRACT.md',
    '- PROJECT_STATE.md',
    '',
    'Constraints:',
    '- Repair only the affected page-level files.',
    '- Prefer deterministic fixes already supported by the repair loop.',
    '- If the issue is not safely repairable, stop and explain why.'
  ]
);

registerPrompt(
  'patch_app_routes',
  'Patch App Routes',
  'Draft a minimal app.json patch that appends new page routes without touching unrelated global config.',
  patchRoutesPromptArgs,
  ({ appendPages }) => [
    'Patch app.json routing with a minimal append_pages JSON patch.',
    `append_pages: ${appendPages}`,
    '',
    'Follow the repo contracts:',
    '- MCP_BOUNDARY_CONTRACT.md',
    '- GOLDEN_PATH.md',
    '- TEST_TIERS.md',
    '',
    'Constraints:',
    '- Output only a JSON patch with append_pages.',
    '- Do not rewrite the whole app.json.',
    '- Do not modify app.js, app.wxss, project.config.json, or unrelated global fields.',
    '- Keep the patch aligned with validate_app_json_patch and apply_app_json_patch.'
  ]
);

registerResource(
  'project_state',
  'wechat://project-state',
  {
    title: 'Project State',
    description: 'Current repo project state and blocker tracking.',
    mimeType: 'text/markdown'
  },
  async () => resourceText('wechat://project-state', 'text/markdown', readRepoFile('PROJECT_STATE.md', '# PROJECT_STATE.md not found\n'))
);

registerResource(
  'validation_plan',
  'wechat://validation-plan',
  {
    title: 'Validation Plan',
    description: 'Current test tier guidance and validation budgets.',
    mimeType: 'text/markdown'
  },
  async () => resourceText('wechat://validation-plan', 'text/markdown', readRepoFile('TEST_TIERS.md', '# TEST_TIERS.md not found\n'))
);

registerResource(
  'path_conventions',
  'wechat://path-conventions',
  {
    title: 'Path Conventions',
    description: 'Clone-agnostic repo-relative path guidance for clients and inspectors.',
    mimeType: 'text/markdown'
  },
  async () => resourceText('wechat://path-conventions', 'text/markdown', renderPathConventionsMarkdown())
);

registerResource(
  'consumer_router',
  'wechat://consumer-router',
  {
    title: 'Consumer Router',
    description: 'Deterministic first-hop routing for inspector and consumer clients.',
    mimeType: 'text/markdown'
  },
  async () => resourceText('wechat://consumer-router', 'text/markdown', renderConsumerRouterMarkdown())
);

registerResource(
  'prompt_selection_guide',
  'wechat://prompt-selection-guide',
  {
    title: 'Prompt Selection Guide',
    description: 'Clone-agnostic guidance for choosing the smallest safe prompt.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://prompt-selection-guide',
      'text/markdown',
      renderPromptSelectionGuideMarkdown()
    )
);

registerResource(
  'latest_diagnostics_metrics',
  'wechat://latest-diagnostics-metrics',
  {
    title: 'Latest Diagnostics Metrics',
    description: 'Latest passive diagnostics metrics summary artifact.',
    mimeType: 'application/json'
  },
  async () =>
    resourceText(
      'wechat://latest-diagnostics-metrics',
      'application/json',
      readRepoFile(path.join('artifacts', 'wechat-devtools', 'diagnostics', 'latest-metrics-summary.json'), JSON.stringify({
        schema_version: 'diagnostics_metrics_summary_v1',
        status: 'missing'
      }, null, 2))
    )
);

registerResource(
  'boundary_contract',
  'wechat://boundary-contract',
  {
    title: 'Boundary Contract',
    description: 'Current PowerShell boundary contract exposed to external clients.',
    mimeType: 'text/markdown'
  },
  async () => resourceText('wechat://boundary-contract', 'text/markdown', readRepoFile('MCP_BOUNDARY_CONTRACT.md', '# MCP_BOUNDARY_CONTRACT.md not found\n'))
);

registerResource(
  'external_client_entrypoints',
  'wechat://external-client-entrypoints',
  {
    title: 'External Client Entrypoints',
    description: 'Stable public entrypoints for external clients.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://external-client-entrypoints',
      'text/markdown',
      readRepoFile('EXTERNAL_CLIENT_ENTRYPOINTS.md', '# EXTERNAL_CLIENT_ENTRYPOINTS.md not found\n')
    )
);

registerResource(
  'release_package',
  'wechat://release-package',
  {
    title: 'Release Package',
    description: 'Release-scoped packaging and sharing guidance.',
    mimeType: 'text/markdown'
  },
  async () => resourceText('wechat://release-package', 'text/markdown', readRepoFile('RELEASE_PACKAGE.md', '# RELEASE_PACKAGE.md not found\n'))
);

registerResource(
  'tool_selection_guide',
  'wechat://tool-selection-guide',
  {
    title: 'Tool Selection Guide',
    description: 'Quick mapping from common tasks to the safest MCP tools.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://tool-selection-guide',
      'text/markdown',
      readRepoFile('MCP_TOOL_SELECTION.md', '# MCP_TOOL_SELECTION.md not found\n')
    )
);

registerResource(
  'server_inventory',
  'wechat://server-inventory',
  {
    title: 'Server Inventory',
    description: 'Live read-only inventory of the registered MCP tools, prompts, and resources.',
    mimeType: 'text/markdown'
  },
  async () => resourceText('wechat://server-inventory', 'text/markdown', renderInventoryMarkdown())
);

registerResource(
  'read_order',
  'wechat://read-order',
  {
    title: 'Read Order',
    description: 'Recommended read-first order for inspector and consumer clients.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://read-order',
      'text/markdown',
      [
        '# MCP Read Order',
        '',
        '1. `wechat://server-inventory`',
        '2. `wechat://read-order`',
        '3. `wechat://consumer-router`',
        '4. `wechat://path-conventions`',
        '5. `wechat://surface-map`',
        '6. `wechat://tool-selection-guide`',
        '7. `wechat://client-usage-guide`',
        '8. `wechat://boundary-contract`',
        '9. `wechat://validation-plan`',
        '10. `wechat://latest-diagnostics-metrics`',
        '',
        '## Notes',
        '- Start with the live inventory to confirm what is currently exposed.',
        '- Use the surface map and tool-selection guide before choosing a write tool.',
        '- Read the client usage guide before any validate/apply workflow.'
      ].join('\n')
  )
);

registerResource(
  'task_map',
  'wechat://task-map',
  {
    title: 'Task Map',
    description: 'Compact task-to-resource hints for inspector and consumer clients.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://task-map',
      'text/markdown',
      [
        '# MCP Task Map',
        '',
        '## If you want to...',
        '- confirm the live surface -> `wechat://server-inventory`',
        '- follow the recommended read order -> `wechat://read-order`',
        '- choose the first consumer hop -> `wechat://consumer-router`',
        '- standardize repo-relative paths -> `wechat://path-conventions`',
        '- choose a draft prompt -> `wechat://prompt-selection-guide`',
        '- find the narrowest safe tool -> `wechat://tool-selection-guide`',
        '- understand how to use the client flow -> `wechat://client-usage-guide`',
        '- inspect the current boundary contract -> `wechat://boundary-contract`',
        '- choose a validation tier -> `wechat://validation-plan`',
        '- inspect the current operator metrics view -> `wechat://latest-diagnostics-metrics`',
        '',
        '## Notes',
        '- This map is intentionally short and read-only.',
        '- Use it when the task is clear but the safest resource is not.',
        '- Fall back to `server_inventory` if you need the live surface first.',
        '- Use `path_conventions` when a task involves paths, clones, or repo-relative examples.'
      ].join('\n')
    )
);

registerResource(
  'client_usage_guide',
  'wechat://client-usage-guide',
  {
    title: 'Client Usage Guide',
    description: 'Quickstart guidance for external MCP clients using the repo server.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://client-usage-guide',
      'text/markdown',
      readRepoFile('MCP_CLIENT_USAGE.md', '# MCP_CLIENT_USAGE.md not found\n')
    )
);

registerResource(
  'inspector_quickstart',
  'wechat://inspector-quickstart',
  {
    title: 'Inspector Quickstart',
    description: 'Shortest read-first path for inspector clients using the repo server.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://inspector-quickstart',
      'text/markdown',
      readRepoFile('MCP_INSPECTOR_QUICKSTART.md', '# MCP_INSPECTOR_QUICKSTART.md not found\n')
    )
);

registerResource(
  'surface_map',
  'wechat://surface-map',
  {
    title: 'Surface Map',
    description: 'Compact map from public MCP surface to the matching docs and tests.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://surface-map',
      'text/markdown',
      readRepoFile('MCP_SURFACE_MAP.md', '# MCP_SURFACE_MAP.md not found\n')
    )
);

registerResource(
  'registry_readiness',
  'wechat://registry-readiness',
  {
    title: 'Registry Readiness',
    description: 'Public-safe guidance for future MCP registry or installer publication without machine-local assumptions.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://registry-readiness',
      'text/markdown',
      readRepoFile('MCP_REGISTRY_READINESS.md', '# MCP_REGISTRY_READINESS.md not found\n')
    )
);

registerResource(
  'installer_readiness',
  'wechat://installer-readiness',
  {
    title: 'Installer Readiness',
    description: 'Public-safe installer-facing guidance for publication work without rooted paths or machine-local assumptions.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://installer-readiness',
      'text/markdown',
      readRepoFile('MCP_REGISTRY_READINESS.md', '# MCP_REGISTRY_READINESS.md not found\n')
    )
);

registerResource(
  'distribution_quickstart',
  'wechat://distribution-quickstart',
  {
    title: 'Distribution Quickstart',
    description: 'Shortest public-safe starting point for installer-facing or consumer-facing distribution work.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://distribution-quickstart',
      'text/markdown',
      readRepoFile('MCP_DISTRIBUTION_QUICKSTART.md', '# MCP_DISTRIBUTION_QUICKSTART.md not found\n')
    )
);

registerResource(
  'registration_guidance',
  'wechat://registration-guidance',
  {
    title: 'Registration Guidance',
    description: 'Clone-agnostic public-safe guidance for registering or consuming this MCP surface.',
    mimeType: 'text/markdown'
  },
  async () =>
    resourceText(
      'wechat://registration-guidance',
      'text/markdown',
      readRepoFile('MCP_REGISTRATION_GUIDANCE.md', '# MCP_REGISTRATION_GUIDANCE.md not found\n')
    )
);

function buildSmokeManifest() {
  return {
    server_name: 'wechat-devtools-control-mcp',
    version: '1.0.0',
    boundary_script: path.relative(repoRoot, boundaryScript).replaceAll(path.sep, '/'),
    smoke_mode: process.env.WECHAT_MCP_SERVER_SMOKE || '',
    tools: [...registeredTools],
    prompts: [...registeredPrompts],
    resources: [...registeredResources]
  };
}

if (process.env.WECHAT_MCP_SERVER_SMOKE) {
  process.stdout.write(`${JSON.stringify({ ...buildSmokeManifest(), runtime_warning: runtimeWarning || undefined }, null, 2)}\n`);
  process.exit(0);
}

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

process.on('uncaughtException', (error) => {
  console.error('[wechat-mcp-server] uncaughtException:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  console.error('[wechat-mcp-server] unhandledRejection:', reason);
  process.exit(1);
});

main().catch((error) => {
  console.error('[wechat-mcp-server] failed to start:', error);
  process.exit(1);
});
