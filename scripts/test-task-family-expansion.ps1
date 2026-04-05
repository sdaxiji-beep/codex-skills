param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$generatedRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'generated'

$activityTranslation = Invoke-WechatTaskTranslator -TaskText 'build a campaign page that says the event has not started yet, shows a notify me CTA, and keeps a simple mobile-first activity layout'
Assert-Equal $activityTranslation.status 'success' 'activity translator should succeed'
$activityExecution = Invoke-WechatTaskExecution `
    -TaskSpec $activityTranslation.task_spec `
    -PageBundle $activityTranslation.page_bundle `
    -ComponentBundle $activityTranslation.component_bundle `
    -AppPatch $activityTranslation.app_patch `
    -OutputDir $generatedRoot `
    -Preview $false
Assert-Equal $activityExecution.status 'success' 'activity execution should succeed'
Assert-Equal $activityExecution.acceptance.status 'pass' 'activity acceptance should pass'

$benefitsTranslation = Invoke-WechatTaskTranslator -TaskText 'build a benefits center page with an empty-state message, an unlock benefits CTA, and a member perks explanation section'
Assert-Equal $benefitsTranslation.status 'success' 'benefits translator should succeed'
$benefitsExecution = Invoke-WechatTaskExecution `
    -TaskSpec $benefitsTranslation.task_spec `
    -PageBundle $benefitsTranslation.page_bundle `
    -ComponentBundle $benefitsTranslation.component_bundle `
    -AppPatch $benefitsTranslation.app_patch `
    -OutputDir $generatedRoot `
    -Preview $false
Assert-Equal $benefitsExecution.status 'success' 'benefits execution should succeed'
Assert-Equal $benefitsExecution.acceptance.status 'pass' 'benefits acceptance should pass'

$detailTranslation = Invoke-WechatTaskTranslator -TaskText 'build a product detail page with product image, title, description, price, and an add to cart CTA'
Assert-Equal $detailTranslation.status 'success' 'product detail translator should succeed'
Assert-Equal $detailTranslation.task_spec.route_mode 'product-detail' 'product detail translator should map to product-detail'
$detailExecution = Invoke-WechatTaskExecution `
    -TaskSpec $detailTranslation.task_spec `
    -PageBundle $detailTranslation.page_bundle `
    -ComponentBundle $detailTranslation.component_bundle `
    -AppPatch $detailTranslation.app_patch `
    -OutputDir $generatedRoot `
    -Preview $false
Assert-Equal $detailExecution.status 'success' 'product detail execution should succeed'
Assert-Equal $detailExecution.acceptance.status 'pass' 'product detail acceptance should pass'

New-TestResult -Name 'task-family-expansion' -Data @{
    pass = $true
    exit_code = 0
    activity_acceptance = $activityExecution.acceptance.status
    benefits_acceptance = $benefitsExecution.acceptance.status
    product_detail_acceptance = $detailExecution.acceptance.status
}
