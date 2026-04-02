param([array]$Results)

$required = @(
    'readonly-flow-page-validation',
    'readonly-flow-page-validation-skipped',
    'readonly-flow-page-validation-failed',
    'automator-page-signature'
)
$selected = @($Results | Where-Object { $required -contains $_.name })
$pass = @($selected | Where-Object { $_.pass }).Count -eq $required.Count
[pscustomobject]@{
    test           = 'p2-fast'
    pass           = $pass
    required_total = $required.Count
    required_passed = @($selected | Where-Object { $_.pass }).Count
}
