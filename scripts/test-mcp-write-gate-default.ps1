param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$statusRaw = & "$PSScriptRoot\mcp-write-gate-status.ps1" -AsJson
$status = $statusRaw | ConvertFrom-Json

Assert-True ($status.blocked -eq $true) 'write MCP should be blocked by default'
Assert-True ($status.gates.policy_enabled -eq $true) 'policy.enabled should be true in phase3 rollout mode'
Assert-True ($status.gates.review_gate_open -eq $true) 'review gate should be open in phase3 rollout mode'

$policyPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'mcp\wechat-devtools-mcp-write\policy.json'
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json
Assert-True ($policy.enabled -eq $true) 'policy file should enable write MCP service in phase3 rollout mode'
Assert-True ($policy.guardrails.allow_tools_before_policy_review -eq $true) 'policy review gate should be opened for phase3 first tool rollout'

$checklistPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'mcp\wechat-devtools-mcp-write\ENABLE_CHECKLIST.md'
Assert-True (Test-Path $checklistPath) 'write MCP enable checklist should exist'

New-TestResult -Name 'mcp-write-gate-default' -Data @{
    pass = $true
    exit_code = 0
    blocked = $status.blocked
    can_enable = $false
}
