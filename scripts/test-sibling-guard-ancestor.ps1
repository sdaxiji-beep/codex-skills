param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
Assert-True (Test-Path $PSScriptRoot) 'Script root must exist.'
Assert-True (Test-Path (Join-Path (Split-Path $PSScriptRoot -Parent) '.agents')) '.agents directory must exist.'
New-TestResult -Name 'sibling-guard-ancestor' -Data @{ pass = $true; exit_code = 0; script_root = $PSScriptRoot }
