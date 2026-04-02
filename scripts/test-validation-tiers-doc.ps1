param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$docPath = Join-Path $repoRoot 'TEST_TIERS.md'
$readmePath = Join-Path $repoRoot 'README.md'
$wechatEntryPath = Join-Path $PSScriptRoot 'wechat.ps1'

Assert-True (Test-Path $docPath) 'TEST_TIERS.md should exist'
Assert-True (Test-Path $readmePath) 'README.md should exist'
Assert-True (Test-Path $wechatEntryPath) 'wechat.ps1 should exist'

$doc = Get-Content -Path $docPath -Raw -Encoding UTF8
$readme = Get-Content -Path $readmePath -Raw -Encoding UTF8
$entry = Get-Content -Path $wechatEntryPath -Raw -Encoding UTF8

foreach ($token in @(
    'GuardCheckOnly',
    'test-diagnostics-focused.ps1',
    '-SkipSmoke -Tag fast',
    '-Tag full',
    'cached deploy/preview gate',
    'Do not run `fast` and `full` in parallel.'
)) {
    Assert-True ($doc.Contains($token)) "TEST_TIERS.md should mention $token"
}

Assert-True ($readme.Contains('TEST_TIERS.md')) 'README should link to TEST_TIERS.md'
Assert-True ($entry.Contains('Get-WechatValidationPlan')) 'wechat.ps1 should expose Get-WechatValidationPlan'

New-TestResult -Name 'validation-tiers-doc' -Data @{
    pass = $true
    exit_code = 0
    required_tokens = 6
}

