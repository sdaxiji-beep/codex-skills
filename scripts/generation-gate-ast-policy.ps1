function Get-WechatAstHybridMode {
    $raw = [string]$env:WECHAT_AST_HYBRID_MODE
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $true
    }

    switch ($raw.Trim().ToLowerInvariant()) {
        '0' { return $false }
        'false' { return $false }
        'off' { return $false }
        default { return $true }
    }
}

function Get-WechatAstPromotedSeverities {
    $raw = [string]$env:WECHAT_AST_PROMOTED_SEVERITIES
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @('error')
    }

    $allowed = @('error', 'warn')
    $parsed = @($raw -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and $allowed -contains $_
    } | Select-Object -Unique)

    if ($parsed.Count -eq 0) {
        return @('error')
    }

    return $parsed
}

function Get-WechatAstDiagnosticsBySeverity {
    param(
        [Parameter(Mandatory)]$Diagnostics,
        [Parameter(Mandatory)][string[]]$Severities
    )

    return @($Diagnostics | Where-Object {
        $_.PSObject.Properties.Name -contains 'severity' -and $Severities -contains [string]$_.severity
    })
}

function Get-WechatAstErrorDiagnosticCount {
    param(
        [Parameter(Mandatory)]$Diagnostics
    )

    return @(Get-WechatAstDiagnosticsBySeverity -Diagnostics $Diagnostics -Severities @('error')).Count
}

function Get-WechatAstPromotedDiagnosticCount {
    param(
        [Parameter(Mandatory)]$Diagnostics,
        [Parameter(Mandatory)][string[]]$PromotedSeverities
    )

    return @(Get-WechatAstDiagnosticsBySeverity -Diagnostics $Diagnostics -Severities $PromotedSeverities).Count
}

function New-WechatAstGateMessage {
    param(
        [Parameter(Mandatory)]$Diagnostic
    )

    $code = if ($Diagnostic.PSObject.Properties.Name -contains 'code') { [string]$Diagnostic.code } else { 'ast_error' }
    $file = if ($Diagnostic.PSObject.Properties.Name -contains 'file') { [string]$Diagnostic.file } else { '' }
    $msg = if ($Diagnostic.PSObject.Properties.Name -contains 'message') { [string]$Diagnostic.message } else { 'AST validation error' }
    $severity = if ($Diagnostic.PSObject.Properties.Name -contains 'severity') { [string]$Diagnostic.severity } else { 'error' }
    $suffix = if ([string]::IsNullOrWhiteSpace($file)) { '' } else { " in '$file'" }
    $severityLabel = if ($severity -eq 'warn') { 'Warn' } else { 'Error' }

    return "AST $severityLabel [$code]${suffix}: $msg"
}
