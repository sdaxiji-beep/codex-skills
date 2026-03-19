[CmdletBinding()]
param(
    [string]$PayloadJson,
    [string]$PayloadPath,
    [switch]$AsJson
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$policyPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\policy.json'

if (-not (Test-Path $policyPath)) {
    throw "Policy file not found: $policyPath"
}

$policy = Get-Content $policyPath -Raw | ConvertFrom-Json
$contract = $policy.confirmation_contract

$result = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    contract_version = if ($contract.version) { [string]$contract.version } else { '' }
    status = 'invalid'
    valid = $false
    issues = @()
    payload = $null
}

if ([string]::IsNullOrWhiteSpace($PayloadJson) -and [string]::IsNullOrWhiteSpace($PayloadPath)) {
    $result.status = 'requires_payload'
    $result.issues += 'payload_missing'
    if ($AsJson) {
        $result | ConvertTo-Json -Depth 10
        exit 0
    }
    [pscustomobject]$result | Format-List
    exit 0
}

try {
    if (-not [string]::IsNullOrWhiteSpace($PayloadPath)) {
        if (-not (Test-Path $PayloadPath)) {
            throw "Payload path not found: $PayloadPath"
        }
        $result.payload = Get-Content $PayloadPath -Raw | ConvertFrom-Json
    }
    else {
        $result.payload = $PayloadJson | ConvertFrom-Json
    }
}
catch {
    $result.status = 'invalid_json'
    $result.issues += "json_parse_failed: $($_.Exception.Message)"
    if ($AsJson) {
        $result | ConvertTo-Json -Depth 10
        exit 0
    }
    [pscustomobject]$result | Format-List
    exit 0
}

$payload = $result.payload
$required = @($contract.required_fields)
foreach ($field in $required) {
    if (-not ($payload.PSObject.Properties.Name -contains $field)) {
        $result.issues += "missing_field:$field"
        continue
    }
    $v = $payload.$field
    if ($null -eq $v) {
        $result.issues += "null_field:$field"
        continue
    }
    if ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)) {
        $result.issues += "empty_field:$field"
    }
}

if ($payload.PSObject.Properties.Name -contains 'risk_level') {
    if (@($contract.risk_levels) -notcontains [string]$payload.risk_level) {
        $result.issues += 'invalid_risk_level'
    }
}

if ($payload.PSObject.Properties.Name -contains 'requires_explicit_yes') {
    if ([bool]$payload.requires_explicit_yes -ne $true) {
        $result.issues += 'requires_explicit_yes_must_be_true'
    }
}

if ($payload.PSObject.Properties.Name -contains 'expires_in_seconds') {
    $ttl = 0
    $parsed = [int]::TryParse([string]$payload.expires_in_seconds, [ref]$ttl)
    if (-not $parsed -or $ttl -le 0) {
        $result.issues += 'invalid_expires_in_seconds'
    }
    elseif ($contract.default_ttl_seconds -and $ttl -gt [int]$contract.default_ttl_seconds) {
        $result.issues += 'expires_in_seconds_exceeds_default_ttl'
    }
}

if ($result.issues.Count -eq 0) {
    $result.status = 'valid'
    $result.valid = $true
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 10
    exit 0
}

[pscustomobject]$result | Format-List
