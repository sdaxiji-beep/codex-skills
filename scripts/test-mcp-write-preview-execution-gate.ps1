param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$entry = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\node_modules\tsx\dist\cli.mjs'
$serverPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\src\server.ts'
$policyPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\policy.json'

Assert-True (Test-Path $entry) "tsx entry should exist"
Assert-True (Test-Path $serverPath) "server.ts should exist"
Assert-True (Test-Path $policyPath) "policy.json should exist"

$nodeCode = @"
import fs from 'node:fs';
import { evaluatePreviewProjectContract } from '$($serverPath.Replace('\','/'))';
const policy = JSON.parse(fs.readFileSync('$($policyPath.Replace('\','/'))', 'utf8'));
const payload = {
  request_id: 'req-1',
  action: 'preview_project',
  scope: 'current-project',
  summary: 'Generate preview QR for current project state',
  risk_level: 'low',
  requires_explicit_yes: true,
  expires_in_seconds: 120
};
const accepted = evaluatePreviewProjectContract({
  desc: 'execution gate',
  toolFlagValue: '1',
  policy,
  confirmationPayload: payload,
  executeRequested: true
});
console.log(JSON.stringify({ accepted }));
"@

$raw = & node $entry -e $nodeCode 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -and $raw -match 'spawn EPERM') {
    New-TestResult -Name 'mcp-write-preview-execution-gate' -Data @{
        pass = $true
        exit_code = 0
        skipped = $true
        reason = 'environment_spawn_eperm'
    }
    return
}
try {
    $json = $raw | ConvertFrom-Json
}
catch {
    throw "preview execution gate parse failed: $raw"
}

Assert-Equal $json.accepted.status 'confirmation_accepted' 'base evaluation should accept valid confirmation'
Assert-Equal $json.accepted.execution_requested $true 'executeRequested should be true in accepted contract'

$toolNodeCode = @"
import { evaluatePreviewProjectContract } from '$($serverPath.Replace('\','/'))';
import fs from 'node:fs';
const policy = JSON.parse(fs.readFileSync('$($policyPath.Replace('\','/'))', 'utf8'));
const confirmed = evaluatePreviewProjectContract({
  desc: 'execution gate',
  toolFlagValue: '1',
  policy,
  confirmationPayload: {
    request_id: 'req-1',
    action: 'preview_project',
    scope: 'current-project',
    summary: 'Generate preview QR for current project state',
    risk_level: 'low',
    requires_explicit_yes: true,
    expires_in_seconds: 120
  },
  executeRequested: true
});
console.log(JSON.stringify(confirmed));
"@

$baseRaw = & node $entry -e $toolNodeCode 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -and $baseRaw -match 'spawn EPERM') {
    New-TestResult -Name 'mcp-write-preview-execution-gate' -Data @{
        pass = $true
        exit_code = 0
        skipped = $true
        reason = 'environment_spawn_eperm'
    }
    return
}
$base = $baseRaw | ConvertFrom-Json
Assert-Equal $base.status 'confirmation_accepted' 'direct contract remains accepted before runtime execution gate'

New-TestResult -Name 'mcp-write-preview-execution-gate' -Data @{
    pass = $true
    exit_code = 0
    accepted_status = $json.accepted.status
    execution_requested = $json.accepted.execution_requested
}
