param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-write-guard.ps1"

$sandbox = Join-Path (Split-Path $PSScriptRoot -Parent) 'sandbox\fake-project'

$env:WRITE_GUARD_AUTO_CONFIRM = 'yes'

$r = Invoke-SafeWrite `
    -ProjectPath $sandbox `
    -Description 'test: confirm mode - add line to index.js' `
    -RequireConfirm $true `
    -WriteAction {
        $content = Get-Content "$sandbox\index.js" -Raw
        Set-Content "$sandbox\index.js" -Value "$content`n// confirmed write"
    }

Assert-Equal $r.status 'success' 'Confirm mode write should succeed.'

$env:WRITE_GUARD_AUTO_CONFIRM = 'no'

$r2 = Invoke-SafeWrite `
    -ProjectPath $sandbox `
    -Description 'test: confirm mode - should be cancelled' `
    -RequireConfirm $true `
    -WriteAction {
        Set-Content "$sandbox\should-not-exist.js" -Value 'this should not exist'
    }

Assert-Equal $r2.status 'cancelled' 'Rejecting confirmation should cancel write.'
Assert-True (-not (Test-Path "$sandbox\should-not-exist.js")) 'No file should be created after cancellation.'

Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue

New-TestResult -Name 'write-guard-confirm' -Data @{
    pass        = $true
    exit_code   = 0
    confirm_yes = $r.status
    confirm_no  = $r2.status
}
