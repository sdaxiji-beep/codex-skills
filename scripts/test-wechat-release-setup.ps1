param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-release-setup.ps1"

$tempRoot = Join-Path $env:TEMP ("codex-release-setup-" + [guid]::NewGuid().ToString('N'))
$configDir = Join-Path $tempRoot 'config'
$miniDir = Join-Path $tempRoot 'mini'
$keysDir = Join-Path $tempRoot 'keys'
New-Item -ItemType Directory -Force -Path $configDir,$miniDir,$keysDir | Out-Null

$baseConfigPath = Join-Path $tempRoot 'deploy-config.json'
@{
  appid = 'touristappid'
  privateKeyPath = ''
  projectPath = $miniDir
  projectRoot = $tempRoot
  cloudFunctionRoot = ''
  cloudEnv = ''
  devtoolsPort = 'auto'
} | ConvertTo-Json -Depth 5 | Set-Content $baseConfigPath -Encoding UTF8

$keyPath = Join-Path $keysDir 'private.test.key'
Set-Content $keyPath 'fake-key' -Encoding UTF8

$missingBasePath = Join-Path $tempRoot 'missing-deploy-config.json'
$beforeMissingBase = Get-WechatReleaseReadiness -ConfigPath $missingBasePath -WorkspaceRoot $tempRoot
Assert-Equal $beforeMissingBase.ready $false "release readiness should stay false when base config is missing"
Assert-Equal $beforeMissingBase.status 'needs_release_setup' "missing base config should map to needs_release_setup"

$before = Get-WechatReleaseReadiness -ConfigPath $baseConfigPath -WorkspaceRoot $tempRoot
Assert-Equal $before.ready $false "release readiness should fail before local setup"

$setupWithoutBase = Invoke-WechatReleaseSetup `
  -WorkspaceRoot $tempRoot `
  -ConfigPath $missingBasePath `
  -AppId 'wx1234567890abcdef' `
  -PrivateKeyPath $keyPath `
  -ProjectPath $miniDir `
  -ProjectRoot $tempRoot `
  -NonInteractive

Assert-Equal $setupWithoutBase.status 'success' "release setup should succeed without a base deploy config"

$setup = Invoke-WechatReleaseSetup `
  -WorkspaceRoot $tempRoot `
  -ConfigPath $baseConfigPath `
  -AppId 'wx1234567890abcdef' `
  -PrivateKeyPath $keyPath `
  -ProjectPath $miniDir `
  -ProjectRoot $tempRoot `
  -NonInteractive

Assert-Equal $setup.status 'success' "release setup should write valid local config"
Assert-True (Test-Path $setup.local_config_path) "local release config should be created"

$after = Get-WechatReleaseReadiness -ConfigPath $baseConfigPath -WorkspaceRoot $tempRoot
Assert-Equal $after.ready $true "release readiness should pass after local setup"
Assert-Equal $after.appid 'wx1234567890abcdef' "local config appid should override base config"

New-TestResult -Name "wechat-release-setup" -Data @{
  pass = $true
  exit_code = 0
  local_config_path = $setup.local_config_path
}
