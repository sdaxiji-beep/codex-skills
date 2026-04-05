param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$translation = Invoke-WechatTaskTranslator -TaskText 'build a coupon center empty-state page with a claim button and rules copy'
Assert-Equal $translation.status 'success' 'acceptance repair loop test requires a successful translator result'

$componentBundle = $translation.component_bundle | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$pageBundle = $translation.page_bundle | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$appPatch = $translation.app_patch | ConvertTo-Json -Depth 20 | ConvertFrom-Json

$wxmlFile = @($pageBundle.files | Where-Object { $_.path -like '*.wxml' })[0]
$wxmlFile.content = [string]$wxmlFile.content -replace "\s*<cta-button text='[^']*'></cta-button>", ''

$outputDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'sandbox'
$result = Invoke-WechatTaskExecution `
    -TaskSpec $translation.task_spec `
    -PageBundle $pageBundle `
    -ComponentBundle $componentBundle `
    -AppPatch $appPatch `
    -OutputDir $outputDir `
    -Preview $false

Assert-Equal $result.status 'success' 'acceptance repair loop should restore a missing CTA and finish successfully'
Assert-Equal $result.acceptance.status 'pass' 'acceptance repair loop should end with a passing acceptance status'
Assert-NotEmpty $result.acceptance_repair_loop 'acceptance repair loop result should be present'
Assert-Equal $result.acceptance_repair_loop.status 'pass' 'acceptance repair loop should pass after repair'
Assert-True (@($result.acceptance_repair_loop.history).Count -ge 1) 'acceptance repair loop should record at least one repair round'
$modifiedCodes = @($result.acceptance_repair_loop.history[0].modified_codes)
Assert-True ($modifiedCodes -contains 'missing_cta_button') 'acceptance repair loop should repair the missing CTA button'

New-TestResult -Name 'acceptance-repair-loop' -Data @{
    pass = $true
    exit_code = 0
    status = $result.status
    repair_status = $result.acceptance_repair_loop.status
    modified_codes = $modifiedCodes
}
