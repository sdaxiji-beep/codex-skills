param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-get-port.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

$port = $null
if ($Context.ContainsKey('DetectedDevtoolsPort')) {
    $port = [int]$Context.DetectedDevtoolsPort
}
else {
    $port = Get-WechatDevtoolsPort
    $Context.DetectedDevtoolsPort = $port
}

Assert-True ($port -gt 1024) "Port should be > 1024, actual: $port"
Assert-True ($port -lt 65535) "Port should be < 65535, actual: $port"

Write-Host "[TEST] detected port: $port"
New-TestResult -Name 'get-port' -Data @{
    pass      = $true
    exit_code = 0
    port      = $port
}
