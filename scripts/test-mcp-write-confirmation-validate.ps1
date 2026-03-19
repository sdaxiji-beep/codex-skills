param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$validPayload = @{
    request_id = 'preview-20260319-000001'
    action = 'preview_project'
    scope = 'D:\卤味'
    summary = 'Generate preview QR for current project state'
    risk_level = 'low'
    requires_explicit_yes = $true
    expires_in_seconds = 300
} | ConvertTo-Json -Compress

$validRaw = & "$PSScriptRoot\mcp-write-confirmation-validate.ps1" -PayloadJson $validPayload -AsJson
$valid = $validRaw | ConvertFrom-Json
Assert-Equal $valid.status 'valid' 'valid confirmation payload should pass'
Assert-True ($valid.valid -eq $true) 'valid confirmation payload should set valid=true'

$invalidPayload = @{
    request_id = 'preview-20260319-000002'
    action = 'preview_project'
    scope = 'D:\卤味'
    summary = 'Generate preview QR for current project state'
    risk_level = 'unknown'
    requires_explicit_yes = $false
    expires_in_seconds = 9999
} | ConvertTo-Json -Compress

$invalidRaw = & "$PSScriptRoot\mcp-write-confirmation-validate.ps1" -PayloadJson $invalidPayload -AsJson
$invalid = $invalidRaw | ConvertFrom-Json
Assert-Equal $invalid.status 'invalid' 'invalid confirmation payload should fail'
Assert-True ($invalid.valid -eq $false) 'invalid confirmation payload should set valid=false'
Assert-True ($invalid.issues.Count -ge 1) 'invalid confirmation payload should include issues'

New-TestResult -Name 'mcp-write-confirmation-validate' -Data @{
    pass = $true
    exit_code = 0
    valid_status = $valid.status
    invalid_status = $invalid.status
}
