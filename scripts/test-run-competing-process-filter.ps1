param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
$content = Get-Content (Join-Path $PSScriptRoot 'test-wechat-skill.ps1') -Raw
Assert-True (-not ($content -match 'another_instance_running')) 'New architecture should not depend on competing-process filter.'
New-TestResult -Name 'run-competing-process-filter' -Data @{ pass = $true; exit_code = 0; source = 'single-process-v2' }
