param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-run.ps1"
. "$PSScriptRoot\test-common.ps1"
$configDir = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-run-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$configPath = Join-Path $configDir 'runner-config.json'
'{}' | Set-Content -Path $configPath -Encoding UTF8
$result = Invoke-WechatRunPreset -Preset 'quick-start' -ConfigPath $configPath
Assert-Equal $result.config_path $configPath 'Config path should roundtrip through run preset.'
New-TestResult -Name 'run-config-path' -Data @{
    pass                    = $true
    exit_code               = 0
    config_path             = $result.config_path
    quick_start_has_config_contract = $true
}
