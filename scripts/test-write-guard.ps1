param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-write-guard.ps1"

$sandbox = Join-Path (Split-Path $PSScriptRoot -Parent) 'sandbox\fake-project'

$r1 = Invoke-SafeWrite `
    -ProjectPath $sandbox `
    -Description 'test: add comment to app.js' `
    -RequireConfirm $false `
    -WriteAction {
        $content = Get-Content "$sandbox\app.js" -Raw
        Set-Content "$sandbox\app.js" -Value "$content`n// auto-written by test"
    }
Assert-Equal $r1.status 'success' 'Direct write should succeed.'

$appContent = Get-Content "$sandbox\app.js" -Raw
Assert-True ($appContent -match 'auto-written by test') 'app.js should contain the sandbox write marker.'

Push-Location $sandbox
$log = git log --oneline -3 | Out-String
Pop-Location
Assert-True ($log -match 'auto-backup') 'git backup commit should exist.'

$r2 = Invoke-SafeWrite `
    -ProjectPath $sandbox `
    -Description 'test: intentional failure' `
    -RequireConfirm $false `
    -WriteAction {
        throw 'intentional error for rollback test'
    }
Assert-Equal $r2.status 'reverted' 'Failure should trigger automatic rollback.'

Push-Location $sandbox
$log2 = git log --oneline -5 | Out-String
Pop-Location
Assert-True ($log2 -match 'revert') 'git rollback commit should exist.'

New-TestResult -Name 'write-guard' -Data @{
    pass      = $true
    exit_code = 0
    test1     = $r1.status
    test2     = $r2.status
}
