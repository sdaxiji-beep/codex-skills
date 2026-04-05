param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

function Get-TextHash {
    param([Parameter(Mandatory)][string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
}

$validatorScript = Join-Path $PSScriptRoot 'wechat-asset-registry-validator.ps1'
$validatorResult = & $validatorScript | ConvertFrom-Json
Assert-Equal $validatorResult.status 'pass' 'asset registry validator should pass before migration parity checks'
Assert-Equal ([int]$validatorResult.component_count) 5 'asset registry validator should see all migrated components'
Assert-Equal ([int]$validatorResult.page_template_count) 5 'asset registry validator should see all migrated page templates'

$registryPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\registry.json'
Assert-True (Test-Path $registryPath) 'asset registry should exist'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("asset-registry-negative-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $badRegistryPath = Join-Path $tempRoot 'registry.bad.json'
    $badRegistry = Get-Content $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $badRegistry.components[0].entry_files.wxml = 'assets/components/product-card/index.wxml'
    $badRegistry.components[1].dependencies = @('missing-component')
    $badRegistry.components[2].acceptance_rules = @('component_ref', 'unknown_rule')
    $badRegistry.page_templates[0].dependencies = @('missing-component')
    $badRegistry.page_templates[2].acceptance_rules = @('component_ref', 'unknown_page_rule')
    $badRegistry | ConvertTo-Json -Depth 10 | Set-Content -Path $badRegistryPath -Encoding UTF8

    $badValidatorResult = & $validatorScript -RegistryPath $badRegistryPath | ConvertFrom-Json
    Assert-Equal $badValidatorResult.status 'fail' 'validator should fail malformed registry variants'
    $violationCodes = @($badValidatorResult.violations | ForEach-Object { [string]$_.code })
    Assert-In 'name_path_mismatch' $violationCodes 'validator should catch component name/path mismatch'
    Assert-In 'unresolved_dependency' $violationCodes 'validator should catch unresolved dependencies'
    Assert-In 'unmapped_acceptance_rule' $violationCodes 'validator should catch unmapped acceptance rules'
    Assert-In 'unresolved_page_dependency' $violationCodes 'validator should catch unresolved page dependencies'
    Assert-In 'unmapped_page_acceptance_rule' $violationCodes 'validator should catch unmapped page acceptance rules'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$registry = Get-Content $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Equal $registry.schema_version 'asset_registry_v1' 'registry schema version should match'

$ctaEntry = @($registry.components | Where-Object { [string]$_.name -eq 'cta-button' })[0]
Assert-NotEmpty $ctaEntry 'cta-button should be registered in asset registry'
Assert-Equal ([string]$ctaEntry.family) 'marketing-empty-state' 'cta-button registry family should match'

$foodItemEntry = @($registry.components | Where-Object { [string]$_.name -eq 'food-item' })[0]
Assert-NotEmpty $foodItemEntry 'food-item should be registered in asset registry'
Assert-Equal ([string]$foodItemEntry.family) 'food-order' 'food-item registry family should match'

$cartSummaryEntry = @($registry.components | Where-Object { [string]$_.name -eq 'cart-summary' })[0]
Assert-NotEmpty $cartSummaryEntry 'cart-summary should be registered in asset registry'
Assert-Equal ([string]$cartSummaryEntry.family) 'food-order' 'cart-summary registry family should match'

$couponPageTemplate = @($registry.page_templates | Where-Object { [string]$_.name -eq 'coupon-empty-state' })[0]
Assert-NotEmpty $couponPageTemplate 'coupon-empty-state page template should be registered in asset registry'
Assert-In 'cta-button' @($couponPageTemplate.dependencies) 'coupon-empty-state page template should depend on cta-button'

$listingPageTemplate = @($registry.page_templates | Where-Object { [string]$_.name -eq 'product-listing' })[0]
Assert-NotEmpty $listingPageTemplate 'product-listing page template should be registered in asset registry'
Assert-In 'product-card' @($listingPageTemplate.dependencies) 'product-listing page template should depend on product-card'

$detailPageTemplate = @($registry.page_templates | Where-Object { [string]$_.name -eq 'product-detail' })[0]
Assert-NotEmpty $detailPageTemplate 'product-detail page template should be registered in asset registry'
Assert-In 'buy-button' @($detailPageTemplate.dependencies) 'product-detail page template should depend on buy-button'

$foodOrderPageTemplate = @($registry.page_templates | Where-Object { [string]$_.name -eq 'food-order' })[0]
Assert-NotEmpty $foodOrderPageTemplate 'food-order page template should be registered in asset registry'
Assert-In 'food-item' @($foodOrderPageTemplate.dependencies) 'food-order page template should depend on food-item'
Assert-In 'cart-summary' @($foodOrderPageTemplate.dependencies) 'food-order page template should depend on cart-summary'
Assert-In 'food-checkout' @($foodOrderPageTemplate.related_pages) 'food-order page template should declare food-checkout as a related page'

$foodCheckoutPageTemplate = @($registry.page_templates | Where-Object { [string]$_.name -eq 'food-checkout' })[0]
Assert-NotEmpty $foodCheckoutPageTemplate 'food-checkout page template should be registered in asset registry'
Assert-Equal ([string]$foodCheckoutPageTemplate.family) 'food-order' 'food-checkout page template family should match'

$recipe = New-WechatMarketingEmptyStateRecipe -Variant 'coupon-empty-state'
$hardcoded = New-WechatMarketingComponentBundleHardcoded -Recipe $recipe -ComponentPath 'components/cta-button/index'
$registryBacked = New-WechatMarketingComponentBundle -Recipe $recipe -ComponentPath 'components/cta-button/index'
Assert-Equal $registryBacked.component_name $hardcoded.component_name 'registry-backed component name should match hardcoded component name'
Assert-Equal @($registryBacked.files).Count @($hardcoded.files).Count 'registry-backed file count should match hardcoded file count'
foreach ($expectedFile in @($hardcoded.files)) {
    $actualFile = @($registryBacked.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed output hash should match hardcoded content for $($expectedFile.path)"
}

$listingRecipe = New-WechatDefaultProductListingRecipe
$legacyProductBundle = New-WechatProductListingComponentBundleHardcoded -Recipe $listingRecipe -ComponentPath 'components/product-card/index'
$registryProductBundle = New-WechatProductListingComponentBundle -Recipe $listingRecipe -ComponentPath 'components/product-card/index'
foreach ($expectedFile in @($legacyProductBundle.files)) {
    $actualFile = @($registryProductBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed product-card output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed product-card hash should match legacy content for $($expectedFile.path)"
}

$detailRecipe = Resolve-WechatProductDetailRecipe -TaskText 'build a product detail page with image, title, description, price, and add to cart CTA'
$legacyBuyButtonBundle = New-WechatProductDetailComponentBundleHardcoded -Recipe $detailRecipe -ComponentPath 'components/buy-button/index'
$registryBuyButtonBundle = New-WechatProductDetailComponentBundle -Recipe $detailRecipe -ComponentPath 'components/buy-button/index'
foreach ($expectedFile in @($legacyBuyButtonBundle.files)) {
    $actualFile = @($registryBuyButtonBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed buy-button output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed buy-button hash should match legacy content for $($expectedFile.path)"
}

$foodOrderRecipe = Resolve-WechatFoodOrderRecipe -TaskText 'build a food ordering mini program with a menu list, prices, and a floating cart summary'
$legacyFoodItemBundle = New-WechatFoodOrderComponentBundleHardcoded -Recipe $foodOrderRecipe -ComponentPath 'components/food-item/index'
$registryFoodItemBundle = New-WechatFoodOrderComponentBundle -Recipe $foodOrderRecipe -ComponentPath 'components/food-item/index'
foreach ($expectedFile in @($legacyFoodItemBundle.files)) {
    $actualFile = @($registryFoodItemBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed food-item output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed food-item hash should match legacy content for $($expectedFile.path)"
}

$legacyCartSummaryBundle = New-WechatFoodOrderComponentBundleHardcoded -Recipe $foodOrderRecipe -ComponentPath 'components/cart-summary/index'
$registryCartSummaryBundle = New-WechatFoodOrderComponentBundle -Recipe $foodOrderRecipe -ComponentPath 'components/cart-summary/index'
foreach ($expectedFile in @($legacyCartSummaryBundle.files)) {
    $actualFile = @($registryCartSummaryBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed cart-summary output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed cart-summary hash should match legacy content for $($expectedFile.path)"
}

$legacyCouponPageBundle = New-WechatMarketingPageBundleHardcoded -Recipe $recipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Coupon Center' }
$registryCouponPageBundle = New-WechatMarketingPageBundle -Recipe $recipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Coupon Center' }
foreach ($expectedFile in @($legacyCouponPageBundle.files)) {
    $actualFile = @($registryCouponPageBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed coupon page output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed coupon page hash should match legacy content for $($expectedFile.path)"
}
$registryCouponPageJson = [string](@($registryCouponPageBundle.files | Where-Object { $_.path -eq 'pages/index/index.json' })[0].content)
Assert-True ($registryCouponPageJson -match '/components/cta-button/index') 'registry-backed coupon page json should reference cta-button component'

$legacyPageBundle = New-WechatProductListingPageBundleHardcoded -Recipe $listingRecipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Product Center' }
$registryPageBundle = New-WechatProductListingPageBundle -Recipe $listingRecipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Product Center' }
foreach ($expectedFile in @($legacyPageBundle.files)) {
    $actualFile = @($registryPageBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed product-listing page output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed product-listing page hash should match legacy content for $($expectedFile.path)"
}
$registryPageJson = [string](@($registryPageBundle.files | Where-Object { $_.path -eq 'pages/index/index.json' })[0].content)
Assert-True ($registryPageJson -match '/components/product-card/index') 'registry-backed product-listing page json should reference product-card component'

$legacyDetailPageBundle = New-WechatProductDetailPageBundleHardcoded -Recipe $detailRecipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Product Center' }
$registryDetailPageBundle = New-WechatProductDetailPageBundle -Recipe $detailRecipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Product Center' }
foreach ($expectedFile in @($legacyDetailPageBundle.files)) {
    $actualFile = @($registryDetailPageBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed product-detail page output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed product-detail page hash should match legacy content for $($expectedFile.path)"
}
$registryDetailPageJson = [string](@($registryDetailPageBundle.files | Where-Object { $_.path -eq 'pages/index/index.json' })[0].content)
Assert-True ($registryDetailPageJson -match '/components/buy-button/index') 'registry-backed product-detail page json should reference buy-button component'

$legacyFoodOrderPageBundle = New-WechatFoodOrderPageBundleHardcoded -Recipe $foodOrderRecipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Food Order' }
$registryFoodOrderPageBundle = New-WechatFoodOrderPageBundle -Recipe $foodOrderRecipe -PagePath 'pages/index/index' -AppPatch @{ navigationBarTitleText = 'Food Order' }
foreach ($expectedFile in @($legacyFoodOrderPageBundle.files)) {
    $actualFile = @($registryFoodOrderPageBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed food-order page output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed food-order page hash should match legacy content for $($expectedFile.path)"
}
$registryFoodOrderPageJson = [string](@($registryFoodOrderPageBundle.files | Where-Object { $_.path -eq 'pages/index/index.json' })[0].content)
Assert-True ($registryFoodOrderPageJson -match '/components/food-item/index') 'registry-backed food-order page json should reference food-item component'
Assert-True ($registryFoodOrderPageJson -match '/components/cart-summary/index') 'registry-backed food-order page json should reference cart-summary component'

$foodFlowRecipe = Resolve-WechatFoodOrderRecipe -TaskText 'build a food order flow with a listing page and a checkout page linked together.'
$legacyFoodCheckoutPageBundle = New-WechatFoodCheckoutPageBundleHardcoded -Recipe $foodFlowRecipe -PagePath 'pages/checkout/index' -AppPatch @{ navigationBarTitleText = 'Checkout Summary' }
$registryFoodCheckoutPageBundle = New-WechatFoodCheckoutPageBundle -Recipe $foodFlowRecipe -PagePath 'pages/checkout/index' -AppPatch @{ navigationBarTitleText = 'Checkout Summary' }
foreach ($expectedFile in @($legacyFoodCheckoutPageBundle.files)) {
    $actualFile = @($registryFoodCheckoutPageBundle.files | Where-Object { $_.path -eq $expectedFile.path })[0]
    Assert-NotEmpty $actualFile "registry-backed food-checkout page output should include $($expectedFile.path)"
    Assert-Equal (Get-TextHash -Text ([string]$actualFile.content)) (Get-TextHash -Text ([string]$expectedFile.content)) "registry-backed food-checkout page hash should match legacy content for $($expectedFile.path)"
}

$fallback = Get-BundleFromRegistry -ComponentName 'missing-component' -ComponentPath 'components/missing-component/index'
Assert-True ($null -eq $fallback) 'registry lookup should return null for unregistered component'

$productBundle = New-WechatProductListingComponentBundle -Recipe (New-WechatDefaultProductListingRecipe) -ComponentPath 'components/product-card/index'
Assert-Equal $productBundle.component_name 'product-card' 'unregistered product-card should still compile through hardcoded fallback'

New-TestResult -Name 'asset-registry-migration' -Data @{
    pass = $true
    exit_code = 0
    registry_schema = [string]$registry.schema_version
    migrated_component = 'cta-button,product-card,buy-button,food-item,cart-summary'
    migrated_page_template = 'coupon-empty-state,product-listing,product-detail,food-order,food-checkout'
    fallback_component = 'product-card'
}
