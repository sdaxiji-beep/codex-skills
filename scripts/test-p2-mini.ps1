param([array]$Results)

$required = @(
    'readonly-flow-page-validation',
    'readonly-flow-page-validation-failed',
    'readonly-flow-page-validation-contract-v2',
    'readonly-flow-page-validation-rule-verdict',
    'readonly-flow-page-validation-normalized-skipped',
    'readonly-flow-page-validation-skipped',
    'p2-scenario-minimal-v1',
    'p2-scenario-failure-v1'
)
$selected = @($Results | Where-Object { $required -contains $_.name })
$pass = @($selected | Where-Object { $_.pass }).Count -eq $required.Count
[pscustomobject]@{
    test            = 'p2-mini'
    pass            = $pass
    required_total  = $required.Count
    required_passed = @($selected | Where-Object { $_.pass }).Count
}
