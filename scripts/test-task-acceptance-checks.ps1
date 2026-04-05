param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$couponTranslation = Invoke-WechatTaskTranslator -TaskText 'build a coupon center empty-state page with a claim button and rules copy'
$couponExecution = Invoke-WechatTaskExecution `
    -TaskSpec $couponTranslation.task_spec `
    -PageBundle $couponTranslation.page_bundle `
    -ComponentBundle $couponTranslation.component_bundle `
    -AppPatch $couponTranslation.app_patch `
    -OutputDir (Join-Path (Split-Path $PSScriptRoot -Parent) 'generated') `
    -Preview $false

Assert-Equal $couponExecution.status 'success' 'coupon execution should pass before acceptance verification'
Assert-Equal $couponExecution.acceptance.status 'pass' 'coupon acceptance should pass'

$productTranslation = Invoke-WechatTaskTranslator -TaskText 'build a store showcase homepage with prices and featured picks'
$productExecution = Invoke-WechatTaskExecution `
    -TaskSpec $productTranslation.task_spec `
    -PageBundle $productTranslation.page_bundle `
    -ComponentBundle $productTranslation.component_bundle `
    -AppPatch $productTranslation.app_patch `
    -OutputDir (Join-Path (Split-Path $PSScriptRoot -Parent) 'generated') `
    -Preview $false

Assert-Equal $productExecution.status 'success' 'product execution should pass before acceptance verification'
Assert-Equal $productExecution.acceptance.status 'pass' 'product acceptance should pass'

$activityTranslation = Invoke-WechatTaskTranslator -TaskText 'build a campaign page that says the event has not started yet, shows a notify me CTA, and keeps a simple mobile-first activity layout'
$activityExecution = Invoke-WechatTaskExecution `
    -TaskSpec $activityTranslation.task_spec `
    -PageBundle $activityTranslation.page_bundle `
    -ComponentBundle $activityTranslation.component_bundle `
    -AppPatch $activityTranslation.app_patch `
    -OutputDir (Join-Path (Split-Path $PSScriptRoot -Parent) 'generated') `
    -Preview $false
Assert-Equal $activityExecution.status 'success' 'activity execution should pass before acceptance verification'
Assert-Equal $activityExecution.acceptance.status 'pass' 'activity acceptance should pass'

$benefitsTranslation = Invoke-WechatTaskTranslator -TaskText 'build a benefits center page with an empty-state message, an unlock benefits CTA, and a member perks explanation section'
$benefitsExecution = Invoke-WechatTaskExecution `
    -TaskSpec $benefitsTranslation.task_spec `
    -PageBundle $benefitsTranslation.page_bundle `
    -ComponentBundle $benefitsTranslation.component_bundle `
    -AppPatch $benefitsTranslation.app_patch `
    -OutputDir (Join-Path (Split-Path $PSScriptRoot -Parent) 'generated') `
    -Preview $false
Assert-Equal $benefitsExecution.status 'success' 'benefits execution should pass before acceptance verification'
Assert-Equal $benefitsExecution.acceptance.status 'pass' 'benefits acceptance should pass'

$detailTranslation = Invoke-WechatTaskTranslator -TaskText 'build a product detail page with product image, title, description, price, and an add to cart CTA'
$detailExecution = Invoke-WechatTaskExecution `
    -TaskSpec $detailTranslation.task_spec `
    -PageBundle $detailTranslation.page_bundle `
    -ComponentBundle $detailTranslation.component_bundle `
    -AppPatch $detailTranslation.app_patch `
    -OutputDir (Join-Path (Split-Path $PSScriptRoot -Parent) 'generated') `
    -Preview $false
Assert-Equal $detailExecution.status 'success' 'product detail execution should pass before acceptance verification'
Assert-Equal $detailExecution.acceptance.status 'pass' 'product detail acceptance should pass'

New-TestResult -Name 'task-acceptance-checks' -Data @{
    pass = $true
    exit_code = 0
    coupon_acceptance = $couponExecution.acceptance.status
    product_acceptance = $productExecution.acceptance.status
    activity_acceptance = $activityExecution.acceptance.status
    benefits_acceptance = $benefitsExecution.acceptance.status
    product_detail_acceptance = $detailExecution.acceptance.status
}
