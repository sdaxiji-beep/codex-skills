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
const required = evaluatePreviewProjectContract({
  desc: 'contract test',
  toolFlagValue: '1',
  policy
});
const invalid = evaluatePreviewProjectContract({
  desc: 'contract test',
  toolFlagValue: '1',
  policy,
  confirmationPayload: { action: 'preview_project' }
});
const accepted = evaluatePreviewProjectContract({
  desc: 'contract test',
  toolFlagValue: '1',
  policy,
  confirmationPayload: {
    request_id: 'req-1',
    action: 'preview_project',
    scope: 'D:\\\\卤味',
    summary: 'Generate preview QR for current project state',
    risk_level: 'low',
    requires_explicit_yes: true,
    expires_in_seconds: 120
  }
});
console.log(JSON.stringify({ required, invalid, accepted }));
"@

$raw = & node $entry -e $nodeCode 2>&1 | Out-String
try {
    $json = $raw | ConvertFrom-Json
}
catch {
    throw "preview confirmation contract parse failed: $raw"
}

Assert-Equal $json.required.status 'confirmation_required' 'missing payload should require confirmation'
Assert-Equal $json.invalid.status 'invalid_confirmation_payload' 'invalid payload should be rejected'
Assert-Equal $json.accepted.status 'confirmation_accepted' 'valid payload should be accepted'
Assert-Equal $json.accepted.execution_requested $false 'accepted payload without execute flag should not request execution'

New-TestResult -Name 'mcp-write-preview-confirmation-contract' -Data @{
    pass = $true
    exit_code = 0
    required_status = $json.required.status
    invalid_status = $json.invalid.status
    accepted_status = $json.accepted.status
}
