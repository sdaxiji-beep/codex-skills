param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$translation = Invoke-WechatTaskTranslator -TaskText 'build a food ordering mini program with a menu list, prices, and a floating cart summary'
Assert-Equal $translation.status 'success' 'food-order translator should succeed'
Assert-Equal ([string]$translation.task_spec.task_family) 'food-order' 'food-order task family should match'
Assert-Equal ([string]$translation.task_spec.route_mode) 'food-order' 'food-order route mode should match'
Assert-Equal @($translation.component_bundles).Count 2 'food-order should compile two component bundles'
Assert-Equal ([string]$translation.page_bundle.source) 'registry' 'food-order page bundle should come from registry'

$componentSources = @($translation.component_bundles | ForEach-Object { [string]$_.source } | Select-Object -Unique)
Assert-Equal @($componentSources).Count 1 'food-order component sources should be uniform'
Assert-Equal ([string]$componentSources[0]) 'registry' 'food-order component bundles should come from registry'

$names = @($translation.component_bundles | ForEach-Object { [string]$_.component_name })
Assert-In 'food-item' $names 'food-order should include food-item component'
Assert-In 'cart-summary' $names 'food-order should include cart-summary component'

$flowTranslation = Invoke-WechatTaskTranslator -TaskText 'build a food order flow with a listing page and a checkout page linked together.'
Assert-Equal $flowTranslation.status 'success' 'food-order-flow translator should succeed'
Assert-Equal ([string]$flowTranslation.task_spec.route_mode) 'food-order-flow' 'food-order-flow route mode should match'
Assert-Equal @($flowTranslation.task_spec.target_pages).Count 2 'food-order-flow should target two pages'
Assert-Equal ([string]$flowTranslation.page_bundle.source) 'registry' 'food-order-flow page bundle should come from registry'
Assert-True ((@($flowTranslation.page_bundle.files.path) -contains 'pages/checkout/index.wxml')) 'food-order-flow should compile checkout page files'
$flowAcceptanceTypes = @($flowTranslation.task_spec.acceptance_checks | ForEach-Object { [string]$_.type })
Assert-In 'route_link' $flowAcceptanceTypes 'food-order-flow should include route link acceptance checks'

New-TestResult -Name 'task-food-order-family' -Data @{
    pass = $true
    route_mode = [string]$translation.task_spec.route_mode
    component_count = @($translation.component_bundles).Count
}
