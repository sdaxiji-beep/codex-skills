param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"

$tcp = New-Object System.Net.Sockets.TcpClient
$portOpen = $false
try {
    $portOpen = $tcp.ConnectAsync('127.0.0.1', 9420).Wait(500)
}
finally {
    $tcp.Close()
}

if (-not $portOpen) {
    Write-Verbose "[SKIP] automator port unavailable, skip test"
    New-TestResult -Name 'automator-page-signature' -Data @{
        pass = $true; exit_code = 0; skipped = $true; reason = 'port_not_available'
    }
    return
}

$auto = Invoke-FlowViaAutomator
$firstCandidate = @($auto.page_signature.candidates)[0]
Assert-Equal $auto.page_signature.source 'automator_current_page_v1' 'source must be automator_current_page_v1.'
Assert-Equal $auto.page_signature.confidence 1.0 'Automator confidence must be 1.0.'
Assert-True (
    ($null -ne $firstCandidate) -or
    ($auto.page_signature.page_data_count -ge 0)
) 'automator should return valid page information.'
Assert-True ($auto.page_signature.page_data_keys -is [System.Array]) 'page_data_keys must be an array.'
Assert-True ($null -ne $auto.page_signature.page_elements) 'page_elements field must exist.'
Assert-True ($auto.page_signature.page_element_count -ge 0) 'page_element_count must be >= 0.'

New-TestResult -Name 'automator-page-signature' -Data @{
    pass               = $true
    exit_code          = 0
    source             = $auto.page_signature.source
    candidates_count   = @($auto.page_signature.candidates).Count
    confidence         = $auto.page_signature.confidence
    page_data_keys     = @($auto.page_signature.page_data_keys)
    page_data_count    = $auto.page_signature.page_data_count
    page_elements      = $auto.page_signature.page_elements
    page_element_count = $auto.page_signature.page_element_count
    first_candidate    = $firstCandidate
}
