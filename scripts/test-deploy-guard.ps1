param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-deploy.ps1"

$config = Get-DeployConfig
Assert-NotEmpty $config.cloudEnv 'cloudEnv must exist in deploy config.'
Assert-True (Test-Path $config.privateKeyPath) 'private key must exist.'
Assert-NotEmpty $config.appid 'appid must exist in deploy config.'
Assert-True (Test-Path $config.cloudFunctionRoot) 'cloud function root must exist.'

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
