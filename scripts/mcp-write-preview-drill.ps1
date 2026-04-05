[CmdletBinding()]
param(
    [string]$Desc = "phase3 preview drill",
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
import { evaluatePreviewProjectContract } from '$($script.Replace('\','/'))';
const policy = JSON.parse(fs.readFileSync('$($policyPath.Replace('\','/'))','utf8'));
const result = evaluatePreviewProjectContract({
  desc: process.env.WECHAT_PREVIEW_DRILL_DESC || '',
  toolFlagValue: '1',
  policy
});
console.log(JSON.stringify(result));
"@

$env:WECHAT_PREVIEW_DRILL_DESC = $Desc
$raw = & node $entry -e $nodeCode 2>&1 | Out-String
Remove-Item Env:WECHAT_PREVIEW_DRILL_DESC -ErrorAction SilentlyContinue

try {
    $json = $raw | ConvertFrom-Json
} catch {
    throw "preview drill parse failed: $raw"
}

$result = [ordered]@{
    ok = [bool]$json.ok
    status = [string]$json.status
    tool = [string]$json.tool
    has_confirmation_contract = ($null -ne $json.confirmation_contract)
    has_confirmation_example = ($null -ne $json.confirmation_request_example)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
    exit 0
}

[pscustomobject]$result | Format-List
