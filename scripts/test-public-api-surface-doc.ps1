param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$docPath = Join-Path $repoRoot 'PUBLIC_API_SURFACE.md'
$readmePath = Join-Path $repoRoot 'README.md'
$wechatEntryPath = Join-Path $PSScriptRoot 'wechat.ps1'

Assert-True (Test-Path $docPath) 'PUBLIC_API_SURFACE.md should exist'
Assert-True (Test-Path $readmePath) 'README.md should exist'
Assert-True (Test-Path $wechatEntryPath) 'wechat.ps1 should exist'

$doc = Get-Content -Path $docPath -Raw -Encoding UTF8
$readme = Get-Content -Path $readmePath -Raw -Encoding UTF8
$entry = Get-Content -Path $wechatEntryPath -Raw -Encoding UTF8

foreach ($token in @(
    'scripts\wechat.ps1',
    'scripts\wechat-mcp-tool-boundary.ps1',
    'diagnostics\Invoke-RepairLoopAuto.ps1',
    '.agents\skills\wechat-devtools-control',
    'scripts\test-*.ps1',
    'Internal implementation surface'
)) {
    Assert-True ($doc.Contains($token)) "PUBLIC_API_SURFACE.md should mention $token"
}

Assert-True ($readme.Contains('PUBLIC_API_SURFACE.md')) 'README should link to PUBLIC_API_SURFACE.md'
Assert-True ($entry.Contains('Get-WechatPublicApiSurface')) 'wechat.ps1 should expose Get-WechatPublicApiSurface'

New-TestResult -Name 'public-api-surface-doc' -Data @{
    pass = $true
    exit_code = 0
    required_tokens = 6
}

