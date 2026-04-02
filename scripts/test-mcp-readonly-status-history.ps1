param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$historyCommand = Join-Path $PSScriptRoot 'mcp-readonly-status-history.ps1'
Assert-True (Test-Path $historyCommand) 'mcp-readonly-status-history.ps1 should exist'

$out = & $historyCommand -KeepLast 200 2>&1 | Out-String
Assert-NotEmpty $out 'status history command should return JSON output'

$cmdResult = $out | ConvertFrom-Json
Assert-True ($cmdResult.appended -eq $true) 'history command should append successfully'
Assert-True ($cmdResult.current_lines -ge 1) 'history file should contain at least one line'
Assert-True (Test-Path $cmdResult.history_path) 'history path should exist'

$lastLine = Get-Content $cmdResult.history_path | Select-Object -Last 1
Assert-NotEmpty $lastLine 'history last line should exist'
$last = $lastLine | ConvertFrom-Json
Assert-True ($last.stable -eq $true) 'latest history entry should be stable=true'
Assert-True ($last.cloud_list_exit_code -eq 0) 'latest history entry cloud-list exit should be 0'

New-TestResult -Name 'mcp-readonly-status-history' -Data @{
    pass = $true
    exit_code = 0
    history_path = $cmdResult.history_path
    current_lines = $cmdResult.current_lines
}
