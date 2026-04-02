param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
$content = Get-Content (Join-Path $PSScriptRoot 'test-wechat-skill.ps1') -Raw
Assert-True ($content -match [regex]::Escape('. "$PSScriptRoot\wechat-readonly-flow.ps1"')) 'test-wechat-skill must dot-source wechat-readonly-flow.ps1.'
Assert-True (-not ($content -match 'powershell\s+-ExecutionPolicy')) 'test-wechat-skill must not spawn nested PowerShell child processes.'
New-TestResult -Name 'script-call-cycles' -Data @{ pass = $true; exit_code = 0; mode = 'in_memory' }
