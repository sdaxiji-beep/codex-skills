param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$sig = $FlowResult.page_signature

Assert-True ($sig.ContainsKey('page_name')) 'page_name must exist.'
Assert-True ($sig.ContainsKey('page_understood')) 'page_understood must exist.'
Assert-True ($sig.ContainsKey('is_valid')) 'is_valid must exist.'
Assert-True ($sig.ContainsKey('issues')) 'issues must exist.'
Assert-True ($sig.ContainsKey('semantic_status')) 'semantic_status must exist.'
Assert-True ($sig.ContainsKey('semantic_reason')) 'semantic_reason must exist.'
Assert-True ($sig.issues -is [System.Array]) 'issues must be an array.'
Assert-True ($sig.semantic_status -in @('valid', 'invalid', 'unknown')) 'semantic_status must be valid/invalid/unknown.'
Assert-True ($sig.semantic_reason -is [string]) 'semantic_reason must be a string.'

New-TestResult -Name 'page-semantic' -Data @{
    pass            = $true
    exit_code       = 0
    page_name       = $sig.page_name
    page_understood = $sig.page_understood
    is_valid        = $sig.is_valid
    issues          = @($sig.issues)
    semantic_status = $sig.semantic_status
    semantic_reason = $sig.semantic_reason
}
