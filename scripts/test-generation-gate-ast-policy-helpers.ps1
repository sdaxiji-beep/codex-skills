param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-ast-policy.ps1"

$diagnostics = @(
    [pscustomobject]@{
        severity = 'error'
        code = 'js_parse_error'
        file = 'pages/about/index.js'
        message = 'Unexpected token'
    },
    [pscustomobject]@{
        severity = 'warn'
        code = 'wxml_html_tag_detected'
        file = 'pages/about/index.wxml'
        message = 'Potential unsupported HTML tags detected in WXML.'
    }
)

$errorCount = Get-WechatAstErrorDiagnosticCount -Diagnostics $diagnostics
Assert-Equal $errorCount 1 'Error diagnostic count should only include severity=error'

$promotedErrorOnly = Get-WechatAstPromotedDiagnosticCount -Diagnostics $diagnostics -PromotedSeverities @('error')
Assert-Equal $promotedErrorOnly 1 'Promoted count should respect configured severities (error only)'

$promotedErrorWarn = Get-WechatAstPromotedDiagnosticCount -Diagnostics $diagnostics -PromotedSeverities @('error', 'warn')
Assert-Equal $promotedErrorWarn 2 'Promoted count should include warn when configured'

$warnMsg = New-WechatAstGateMessage -Diagnostic $diagnostics[1]
Assert-True ($warnMsg -match '^AST Warn \[wxml_html_tag_detected\]') 'Warn diagnostic message should use AST Warn prefix'

$errorMsg = New-WechatAstGateMessage -Diagnostic $diagnostics[0]
Assert-True ($errorMsg -match '^AST Error \[js_parse_error\]') 'Error diagnostic message should use AST Error prefix'

New-TestResult -Name 'generation-gate-ast-policy-helpers' -Data @{
    pass = $true
    exit_code = 0
    error_count = $errorCount
    promoted_error_only = $promotedErrorOnly
    promoted_error_warn = $promotedErrorWarn
}
