param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$translation = Invoke-WechatTaskTranslator -TaskText 'build a coupon center empty-state page with a claim button and rules copy'
Assert-Equal $translation.status 'success' 'executor focused test requires a successful translator result'

$outputDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'generated'
$result = Invoke-WechatTaskExecution `
    -TaskSpec $translation.task_spec `
    -PageBundle $translation.page_bundle `
    -ComponentBundle $translation.component_bundle `
    -AppPatch $translation.app_patch `
    -OutputDir $outputDir `
    -Preview $false

Assert-Equal $result.status 'success' 'task executor should complete successfully for compiled coupon flow'
Assert-Equal $result.component_validate.gate_status 'pass' 'executor should pass component validation'
Assert-Equal $result.page_validate.gate_status 'pass' 'executor should pass page validation'
Assert-Equal $result.app_validate.gate_status 'pass' 'executor should pass app patch validation'
Assert-Equal $result.preview_result.status 'skipped' 'executor should keep preview skipped by default'
Assert-True (Test-Path (Join-Path $result.project_dir 'pages\\index\\index.wxml')) 'executor should write page files into generated project'
Assert-True (Test-Path (Join-Path $result.project_dir 'components\\cta-button\\index.js')) 'executor should write component files into generated project'

New-TestResult -Name 'task-executor' -Data @{
    pass = $true
    exit_code = 0
    status = $result.status
    project_dir = $result.project_dir
    component_gate = $result.component_validate.gate_status
    page_gate = $result.page_validate.gate_status
    app_gate = $result.app_validate.gate_status
}
