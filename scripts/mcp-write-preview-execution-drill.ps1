[CmdletBinding()]
param(
    [string]$Desc = "phase3 preview execution drill",
    [switch]$AsJson
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$entry = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\node_modules\tsx\dist\cli.mjs'
$script = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\src\server.ts'
$policyPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\policy.json'

if (-not (Test-Path $entry)) { throw "tsx entry not found: $entry" }
if (-not (Test-Path $script)) { throw "server.ts not found: $script" }
if (-not (Test-Path $policyPath)) { throw "policy not found: $policyPath" }

$nodeCode = @"
import fs from 'node:fs';
import { resolvePreviewProjectRequest } from '$($script.Replace('\','/'))';
const policyRaw = fs.readFileSync('$($policyPath.Replace('\','/'))','utf8').replace(/^\uFEFF/, '');
const policy = JSON.parse(policyRaw);
const payload = {
  request_id: 'preview-drill-1',
  action: 'preview_project',
  scope: 'sandbox\\\\fake-project',
  summary: process.env.WECHAT_PREVIEW_EXEC_DRILL_DESC || 'phase3 preview execution drill',
  risk_level: 'low',
  requires_explicit_yes: true,
  expires_in_seconds: 120
};
const blocked = resolvePreviewProjectRequest({
  desc: process.env.WECHAT_PREVIEW_EXEC_DRILL_DESC || '',
  confirmationPayload: payload,
  execute: true,
  toolFlagValue: '1',
  executionFlagValue: '0',
  policy
});
const permitted = resolvePreviewProjectRequest({
  desc: process.env.WECHAT_PREVIEW_EXEC_DRILL_DESC || '',
  confirmationPayload: payload,
  execute: true,
  toolFlagValue: '1',
  executionFlagValue: '1',
  policy
});
console.log(JSON.stringify({ blocked, permitted }));
"@

$env:WECHAT_PREVIEW_EXEC_DRILL_DESC = $Desc
$raw = & node $entry -e $nodeCode 2>&1 | Out-String
$raw = $raw.TrimStart([char]0xFEFF).Trim()
Remove-Item Env:WECHAT_PREVIEW_EXEC_DRILL_DESC -ErrorAction SilentlyContinue

try {
    $json = $raw | ConvertFrom-Json
} catch {
    throw "preview execution drill parse failed: $raw"
}

$result = [ordered]@{
    blocked_status = [string]$json.blocked.status
    permitted_status = [string]$json.permitted.status
    execution_ready = [bool]$json.permitted.execution_ready
    execution_status = [string]$json.permitted.execution_status
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

[pscustomobject]$result | Format-List
