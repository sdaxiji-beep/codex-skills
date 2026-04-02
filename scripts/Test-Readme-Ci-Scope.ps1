param()

$readme = Get-Content (Join-Path $PSScriptRoot '..\README.md') -Raw -Encoding UTF8

$checks = @(
    'GitHub CI currently covers only the repo-safe guard and diagnostics-focused layers.'
    'Local Windows + WeChat DevTools validation is still required for the higher tiers and for any real preview/deploy confirmation.'
    'GitHub PR checks:'
    'Recommended repository ruleset / required checks:'
    'ci-minimal / guardrails'
    'ci-diagnostics / diagnostics-focused'
    'Local-only validation:'
    'GuardCheckOnly'
    'test-diagnostics-focused.ps1'
    'fast'
    'full'
    'real DevTools preview/deploy drills'
)

$missing = @($checks | Where-Object { $readme -notmatch [regex]::Escape($_) })

$result = [pscustomobject]@{
    test = 'readme-ci-scope'
    pass = ($missing.Count -eq 0)
    missing = $missing
    exit_code = $(if ($missing.Count -eq 0) { 0 } else { 1 })
}

$result | ConvertTo-Json -Depth 4
exit $result.exit_code
