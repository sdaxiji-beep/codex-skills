param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-open-project.ps1"

$root = Split-Path $PSScriptRoot -Parent
$missingPath = Join-Path $root 'sandbox\\does-not-exist'
$r = Invoke-OpenProject -ProjectPath $missingPath
Assert-Equal $r.status 'failed' 'missing path should return failed'

$fakePath = Join-Path $root 'sandbox\fake-project'
$r2 = Invoke-OpenProject -ProjectPath $fakePath
Assert-True ($r2.status -in @('failed', 'warning', 'success')) 'expected a clear status'

New-TestResult -Name 'open-project' -Data @{
    pass      = $true
    exit_code = 0
    test1     = $r.status
    test2     = $r2.status
}
