param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$delegatePath = Join-Path $PSScriptRoot 'test-p5-e2e-simplified-drill.ps1'
if (-not (Test-Path $delegatePath)) {
    return New-TestResult -Name 'p5-e2e-real-drill' -Data @{
        pass = $false
        exit_code = 1
        status = 'failed'
        reason = 'missing_delegate'
        delegate_path = $delegatePath
    }
}

$result = & $delegatePath -FlowResult $FlowResult -Context $Context
if ($null -eq $result) {
    return New-TestResult -Name 'p5-e2e-real-drill' -Data @{
        pass = $false
        exit_code = 1
        status = 'failed'
        reason = 'delegate_returned_null'
        delegate_path = $delegatePath
    }
}

$data = @{}
foreach ($property in $result.PSObject.Properties) {
    $data[$property.Name] = $property.Value
}
$data['test'] = 'p5-e2e-real-drill'
$data['delegate_test'] = if ($result.PSObject.Properties.Name -contains 'test') { [string]$result.test } else { 'unknown' }
$data['harness_mode'] = 'delegated_simplified'

if ($data.ContainsKey('summary_path') -and -not $data.ContainsKey('drill_summary_path')) {
    $data['drill_summary_path'] = $data['summary_path']
}

return [pscustomobject]$data
