param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-deploy.ps1"

$config = Get-DeployConfig
if (
    [string]::IsNullOrWhiteSpace($config.cloudEnv) -or
    [string]::IsNullOrWhiteSpace($config.appid) -or
    (-not (Test-Path $config.privateKeyPath)) -or
    (-not (Test-Path $config.cloudFunctionRoot))
) {
    New-TestResult -Name 'deploy-guard' -Data @{
        pass      = $true
        exit_code = 0
        skipped   = $true
        reason    = 'shared_mode_missing_real_release_config'
    }
    return
}

$funcs = Get-CloudFunctionList
Assert-True ($funcs.Count -gt 0) 'should have cloud functions.'
$firstFunc = $funcs[0]
Assert-NotEmpty $firstFunc.name 'function name must not be empty.'
Assert-True ($null -ne $firstFunc.has_index) 'has_index field must exist.'
Assert-True ($null -ne $firstFunc.has_package_json) 'has_package_json field must exist.'

$env:WRITE_GUARD_AUTO_CONFIRM = 'no'
$cancel = Invoke-WechatDeploy -Mode 'preview' -RequireConfirm $true
Assert-Equal $cancel.status 'cancelled' 'preview should be cancelled when confirm=no.'

$env:WRITE_GUARD_AUTO_CONFIRM = 'yes'
$list = Invoke-WechatDeploy -Mode 'list-functions' -RequireConfirm $true
Assert-Equal $list.status 'success' 'list-functions should succeed.'
Assert-True ($list.output.functions.Count -gt 0) 'cloud function list should not be empty.'
Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue

New-TestResult -Name 'deploy-guard' -Data @{
    pass              = $true
    exit_code         = 0
    cloudEnv          = $config.cloudEnv
    function_count    = $funcs.Count
    first_function    = $firstFunc.name
    key_exists        = (Test-Path $config.privateKeyPath)
    preview_cancelled = $cancel.status
}
