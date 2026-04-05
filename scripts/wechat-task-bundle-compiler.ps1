[CmdletBinding()]
param()

if (-not (Get-Command Test-WechatTaskSpec -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-task-spec.ps1"
}

if (-not (Get-Command New-WechatMarketingEmptyStateRecipe -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-task-product-routing.ps1"
}

function Get-WechatAssetRegistryPath {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) 'assets\registry.json')
}

function Get-WechatAssetRoot {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) 'assets')
}

function Get-WechatAssetRegistry {
    $registryPath = Get-WechatAssetRegistryPath
    if (-not (Test-Path $registryPath)) {
        return $null
    }

    return (Get-Content $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-WechatRegistryComponentEntry {
    param(
        [Parameter(Mandatory)][string]$ComponentName
    )

    $registry = Get-WechatAssetRegistry
    if ($null -eq $registry) {
        return $null
    }

    foreach ($component in @($registry.components)) {
        if ([string]$component.name -eq $ComponentName) {
            return $component
        }
    }

    return $null
}

function Get-WechatRegistryPageTemplateEntry {
    param(
        [Parameter(Mandatory)][string]$TemplateName
    )

    $registry = Get-WechatAssetRegistry
    if ($null -eq $registry) {
        return $null
    }

    foreach ($template in @($registry.page_templates)) {
        if ([string]$template.name -eq $TemplateName) {
            return $template
        }
    }

    return $null
}

function Resolve-WechatAssetTemplateContent {
    param(
        [Parameter(Mandatory)][string]$Content,
        [hashtable]$TemplateContext = @{}
    )

    $resolved = $Content.TrimEnd("`r", "`n")
    foreach ($key in @($TemplateContext.Keys)) {
        $resolved = $resolved.Replace([string]$key, [string]$TemplateContext[$key])
    }

    return $resolved
}

function Get-BundleFromRegistry {
    param(
        [Parameter(Mandatory)][string]$ComponentName,
        [Parameter(Mandatory)][string]$ComponentPath,
        [hashtable]$TemplateContext = @{}
    )

    $entry = Get-WechatRegistryComponentEntry -ComponentName $ComponentName
    if ($null -eq $entry) {
        return $null
    }

    $assetRoot = Get-WechatAssetRoot
    $basePath = $ComponentPath.Trim().Trim('/') -replace '\\', '/'
    $files = @()
    $entryFiles = $entry.entry_files
    $suffixMap = [ordered]@{
        wxml = '.wxml'
        js   = '.js'
        wxss = '.wxss'
        json = '.json'
    }

    foreach ($key in @($suffixMap.Keys)) {
        $relativePath = $entryFiles.$key
        if ([string]::IsNullOrWhiteSpace([string]$relativePath)) {
            return $null
        }

        $sourcePath = Join-Path $assetRoot (($relativePath -replace '^assets[\\/]', '') -replace '/', '\')
        if (-not (Test-Path $sourcePath)) {
            return $null
        }

        $content = Get-Content $sourcePath -Raw -Encoding UTF8
        $files += [ordered]@{
            path = "$basePath$($suffixMap[$key])"
            content = (Resolve-WechatAssetTemplateContent -Content $content -TemplateContext $TemplateContext)
        }
    }

    return [ordered]@{
        component_name = $ComponentName
        source = 'registry'
        asset_kind = 'component'
        asset_name = $ComponentName
        files = $files
    }
}

function Get-PageFromRegistry {
    param(
        [Parameter(Mandatory)][string]$TemplateName,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$TemplateContext = @{}
    )

    $entry = Get-WechatRegistryPageTemplateEntry -TemplateName $TemplateName
    if ($null -eq $entry) {
        return $null
    }

    $assetRoot = Get-WechatAssetRoot
    $basePath = $PagePath.Trim().Trim('/') -replace '\\', '/'
    $files = @()
    $entryFiles = $entry.entry_files
    $suffixMap = [ordered]@{
        wxml = '.wxml'
        js   = '.js'
        wxss = '.wxss'
        json = '.json'
    }

    foreach ($key in @($suffixMap.Keys)) {
        $relativePath = $entryFiles.$key
        if ([string]::IsNullOrWhiteSpace([string]$relativePath)) {
            return $null
        }

        $sourcePath = Join-Path $assetRoot (($relativePath -replace '^assets[\\/]', '') -replace '/', '\')
        if (-not (Test-Path $sourcePath)) {
            return $null
        }

        $content = Get-Content $sourcePath -Raw -Encoding UTF8
        $files += [ordered]@{
            path = "$basePath$($suffixMap[$key])"
            content = (Resolve-WechatAssetTemplateContent -Content $content -TemplateContext $TemplateContext)
        }
    }

    return [ordered]@{
        page_name = (Get-WechatTaskTargetPageName -PagePath $PagePath)
        source = 'registry'
        asset_kind = 'page_template'
        asset_name = $TemplateName
        files = $files
    }
}

function Get-WechatTaskTargetComponentName {
    param(
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $normalized = $ComponentPath.Trim().Trim('/') -replace '\\', '/'
    if ($normalized -notmatch '^components/([^/]+)/index$') {
        throw "Unsupported component target path: $ComponentPath"
    }

    return $Matches[1]
}

function Get-WechatTaskTargetPageName {
    param(
        [Parameter(Mandatory)][string]$PagePath
    )

    $normalized = $PagePath.Trim().Trim('/') -replace '\\', '/'
    if ($normalized -notmatch '^pages/([^/]+)/([^/]+)$') {
        throw "Unsupported page target path: $PagePath"
    }

    return $Matches[2]
}

function Get-WechatTaskAppPatchValue {
    param(
        [Parameter(Mandatory)]$AppPatch,
        [Parameter(Mandatory)][string]$Name,
        [string]$Default = ''
    )

    if ($null -eq $AppPatch) {
        return $Default
    }

    if ($AppPatch -is [System.Collections.IDictionary]) {
        if ($AppPatch.Contains($Name) -or @($AppPatch.Keys) -contains $Name) {
            return [string]$AppPatch[$Name]
        }
        return $Default
    }

    $property = $AppPatch.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return [string]$property.Value
    }

    return $Default
}

function Get-WechatBundleMetadataValue {
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)][string]$Name,
        [string]$Default = 'unknown'
    )

    if ($null -eq $Bundle) {
        return $Default
    }

    if ($Bundle -is [System.Collections.IDictionary]) {
        if ($Bundle.Contains($Name) -or @($Bundle.Keys) -contains $Name) {
            return [string]$Bundle[$Name]
        }
        return $Default
    }

    $property = $Bundle.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return [string]$property.Value
    }

    return $Default
}

function New-WechatDefaultProductListingRecipe {
    return @{
        route_mode = 'product-listing'
        shell_prompt = 'build a notebook mini program'
        app_title = 'Product Center'
        project_name = 'product-center-app'
        component_prompt = 'Create a reusable product card component for a mobile-first mini program product listing page.'
        component_name = 'product-card'
        featured_badge = 'Featured'
        products = @(
            @{ title = 'Spicy Braised Combo'; price = '38'; summary = 'Balanced meat-and-veg set for first-time customers.' },
            @{ title = 'Signature Duck Wings'; price = '22'; summary = 'Popular marinated wings with a savory glaze.' },
            @{ title = 'Weekend Family Box'; price = '68'; summary = 'Large sharing box with mixed ready-to-heat dishes.' }
        )
        hero_title = 'Featured Products'
        hero_subtitle = 'Browse the current best sellers, signature dishes, and easy re-order picks.'
        section_title = 'Popular picks'
        footer_copy = 'Prices shown are sample placeholders for generated product-listing demos.'
    }
}

function Get-WechatTaskRecipeForSpec {
    param(
        [Parameter(Mandatory)]$TaskSpec
    )

    switch ([string]$TaskSpec.task_family) {
        'marketing-empty-state' {
            return New-WechatMarketingEmptyStateRecipe -Variant ([string]$TaskSpec.route_mode)
        }
        'product-listing' {
            return New-WechatDefaultProductListingRecipe
        }
        'product-detail' {
            return Resolve-WechatProductDetailRecipe -TaskText 'build a product detail page with image, title, description, price, and add to cart CTA'
        }
        'food-order' {
            if ([string]$TaskSpec.route_mode -eq 'food-order-flow') {
                return Resolve-WechatFoodOrderRecipe -TaskText 'build a food order flow with a listing page and a checkout page linked together.'
            }
            return Resolve-WechatFoodOrderRecipe -TaskText 'build a food ordering mini program with a menu list, prices, and a floating cart summary'
        }
        default {
            throw "Unsupported TaskSpec family for bundle compilation: $($TaskSpec.task_family)"
        }
    }
}

function New-WechatTaskAppPatchPayload {
    param(
        [Parameter(Mandatory)]$TaskSpec
    )

    $pagePaths = @($TaskSpec.target_pages | ForEach-Object { [string]$_.path })
    if ($pagePaths.Count -eq 0) {
        throw 'TaskSpec compilation requires at least one target page.'
    }

    return [ordered]@{
        append_pages = $pagePaths
    }
}

function New-WechatMarketingComponentBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $basePath = $ComponentPath.Trim().Trim('/') -replace '\\', '/'

    return [ordered]@{
        component_name = $componentName
        source = 'hardcoded'
        asset_kind = 'component'
        asset_name = $componentName
        files = @(
            [ordered]@{
                path = "$basePath.wxml"
                content = "<view class='cta-wrap'><button class='cta-btn'>{{text}}</button></view>"
            },
            [ordered]@{
                path = "$basePath.js"
                content = @"
Component({
  properties: {
    text: {
      type: String,
      value: "$($Recipe.cta_default_text)"
    }
  },
  data: {},
  methods: {}
})
"@
            },
            [ordered]@{
                path = "$basePath.wxss"
                content = ".cta-wrap { padding: 16rpx 0; }`n.cta-btn { background: #ff7a45; color: #ffffff; border-radius: 999rpx; font-size: 30rpx; }"
            },
            [ordered]@{
                path = "$basePath.json"
                content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}"
            }
        )
    }
}

function New-WechatMarketingComponentBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $registryBundle = Get-BundleFromRegistry -ComponentName $componentName -ComponentPath $ComponentPath -TemplateContext @{
        '__CTA_DEFAULT_TEXT__' = [string]$Recipe.cta_default_text
    }
    if ($null -ne $registryBundle) {
        return $registryBundle
    }

    return (New-WechatMarketingComponentBundleHardcoded -Recipe $Recipe -ComponentPath $ComponentPath)
}

function New-WechatMarketingPageBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $pageName = Get-WechatTaskTargetPageName -PagePath $PagePath
    $basePath = $PagePath.Trim().Trim('/') -replace '\\', '/'
    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)
    $rulesItems = @($Recipe.rules_items | ForEach-Object {
        "    <text class='rules-item'>$_</text>"
    }) -join "`n"
    $countdownMarkup = ''
    if ($Recipe.ContainsKey('countdown_label') -and $Recipe.ContainsKey('countdown_value')) {
        $countdownMarkup = @"
  <view class='countdown-box'>
    <text class='countdown-label'>$($Recipe.countdown_label)</text>
    <text class='countdown-value'>$($Recipe.countdown_value)</text>
  </view>
"@
    }
    $benefitsMarkup = ''
    if ($Recipe.ContainsKey('benefits_title') -and $Recipe.ContainsKey('benefits_items')) {
        $benefitItems = @($Recipe.benefits_items | ForEach-Object {
            "    <text class='benefit-item'>$_</text>"
        }) -join "`n"
        $benefitsMarkup = @"
  <view class='benefits-list'>
    <text class='benefits-title'>$($Recipe.benefits_title)</text>
$benefitItems
  </view>
"@
    }

    return [ordered]@{
        page_name = $pageName
        source = 'hardcoded'
        asset_kind = 'page_template'
        asset_name = [string]$Recipe.route_mode
        files = @(
            [ordered]@{
                path = "$basePath.wxml"
                content = @"
<view class='coupon-page'>
  <view class='hero'>
    <text class='title'>$($Recipe.page_title)</text>
    <text class='subtitle'>$($Recipe.hero_subtitle)</text>
  </view>
  <view class='empty-state'>
    <text class='empty-title'>$($Recipe.empty_title)</text>
    <text class='empty-copy'>$($Recipe.empty_copy)</text>
$countdownMarkup
    <cta-button text='$($Recipe.cta_default_text)'></cta-button>
  </view>
$benefitsMarkup
  <view class='rules-card'>
    <text class='rules-title'>$($Recipe.rules_title)</text>
$rulesItems
  </view>
</view>
"@
            },
            [ordered]@{
                path = "$basePath.js"
                content = @"
Page({
  data: {
    pageMode: '$($Recipe.route_mode)'
  },
  onLoad() {}
})
"@
            },
            [ordered]@{
                path = "$basePath.wxss"
                content = @"
.coupon-page { min-height: 100vh; padding: 32rpx; background: linear-gradient(180deg, #fff7f0 0%, #fff 48%, #fffdf8 100%); }
.hero { margin-bottom: 36rpx; }
.title { display: block; font-size: 48rpx; font-weight: 700; color: #2f241f; }
.subtitle { display: block; margin-top: 12rpx; color: #8a6f63; line-height: 1.6; }
.empty-state { padding: 32rpx; border-radius: 28rpx; background: #ffffff; box-shadow: 0 18rpx 50rpx rgba(255, 122, 69, 0.12); }
.empty-title { display: block; font-size: 36rpx; font-weight: 600; color: #2f241f; }
.empty-copy { display: block; margin-top: 14rpx; color: #7e6a60; line-height: 1.7; }
.countdown-box { margin-top: 18rpx; padding: 18rpx; border-radius: 20rpx; background: #fff4eb; }
.countdown-label { display: block; color: #a64d21; font-size: 24rpx; }
.countdown-value { display: block; margin-top: 8rpx; font-size: 34rpx; font-weight: 700; color: #d9480f; }
.benefits-list { margin-top: 24rpx; padding: 24rpx; border-radius: 22rpx; background: #fffaf5; border: 2rpx dashed #ffd7bf; }
.benefits-title { display: block; margin-bottom: 14rpx; font-size: 28rpx; font-weight: 600; color: #7a4028; }
.benefit-item { display: block; color: #8a6f63; line-height: 1.7; }
.rules-card { margin-top: 28rpx; padding: 28rpx; border-radius: 24rpx; background: #fff; border: 2rpx solid #ffe0cf; }
.rules-title { display: block; margin-bottom: 16rpx; font-size: 30rpx; font-weight: 600; color: #7a4028; }
.rules-item { display: block; color: #8a6f63; line-height: 1.8; }
"@
            },
            [ordered]@{
                path = "$basePath.json"
                content = "{`n  `"navigationBarTitleText`": `"$navigationTitle`",`n  `"usingComponents`": {`n    `"cta-button`": `"/components/cta-button/index`"`n  }`n}"
            }
        )
    }
}

function New-WechatMarketingPageBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)
    $rulesItems = @($Recipe.rules_items | ForEach-Object {
        "    <text class='rules-item'>$_</text>"
    }) -join "`n"
    $countdownMarkup = ''
    if ($Recipe.ContainsKey('countdown_label') -and $Recipe.ContainsKey('countdown_value')) {
        $countdownMarkup = @"
  <view class='countdown-box'>
    <text class='countdown-label'>$($Recipe.countdown_label)</text>
    <text class='countdown-value'>$($Recipe.countdown_value)</text>
  </view>
"@
    }
    $benefitsMarkup = ''
    if ($Recipe.ContainsKey('benefits_title') -and $Recipe.ContainsKey('benefits_items')) {
        $benefitItems = @($Recipe.benefits_items | ForEach-Object {
            "    <text class='benefit-item'>$_</text>"
        }) -join "`n"
        $benefitsMarkup = @"
  <view class='benefits-list'>
    <text class='benefits-title'>$($Recipe.benefits_title)</text>
$benefitItems
  </view>
"@
    }

    $registryPage = Get-PageFromRegistry -TemplateName ([string]$Recipe.route_mode) -PagePath $PagePath -TemplateContext @{
        '__MARKETING_PAGE_TITLE__' = [string]$Recipe.page_title
        '__MARKETING_HERO_SUBTITLE__' = [string]$Recipe.hero_subtitle
        '__MARKETING_EMPTY_TITLE__' = [string]$Recipe.empty_title
        '__MARKETING_EMPTY_COPY__' = [string]$Recipe.empty_copy
        '__MARKETING_COUNTDOWN_MARKUP__' = [string]$countdownMarkup
        '__MARKETING_CTA_TEXT__' = [string]$Recipe.cta_default_text
        '__MARKETING_BENEFITS_MARKUP__' = [string]$benefitsMarkup
        '__MARKETING_RULES_TITLE__' = [string]$Recipe.rules_title
        '__MARKETING_RULES_ITEMS__' = [string]$rulesItems
        '__MARKETING_PAGE_MODE__' = [string]$Recipe.route_mode
        '__MARKETING_NAV_TITLE__' = [string]$navigationTitle
    }
    if ($null -ne $registryPage) {
        return $registryPage
    }

    return (New-WechatMarketingPageBundleHardcoded -Recipe $Recipe -PagePath $PagePath -AppPatch $AppPatch)
}

function New-WechatProductListingComponentBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $registryBundle = Get-BundleFromRegistry -ComponentName $componentName -ComponentPath $ComponentPath -TemplateContext @{
        '__PRODUCT_BADGE__' = [string]$Recipe.featured_badge
    }
    if ($null -ne $registryBundle) {
        return $registryBundle
    }

    $basePath = $ComponentPath.Trim().Trim('/') -replace '\\', '/'

    return [ordered]@{
        component_name = $componentName
        source = 'hardcoded'
        asset_kind = 'component'
        asset_name = $componentName
        files = @(
            [ordered]@{
                path = "$basePath.wxml"
                content = @"
<view class='product-card'>
  <text class='badge'>{{badge}}</text>
  <text class='title'>{{title}}</text>
  <text class='summary'>{{summary}}</text>
  <text class='price'>楼{{price}}</text>
</view>
"@
            },
            [ordered]@{
                path = "$basePath.js"
                content = @"
Component({
  properties: {
    badge: {
      type: String,
      value: "$($Recipe.featured_badge)"
    },
    title: {
      type: String,
      value: "Product Title"
    },
    summary: {
      type: String,
      value: "Product summary."
    },
    price: {
      type: String,
      value: "0"
    }
  },
  data: {},
  methods: {}
})
"@
            },
            [ordered]@{
                path = "$basePath.wxss"
                content = @"
.product-card { padding: 28rpx; border-radius: 24rpx; background: #ffffff; box-shadow: 0 14rpx 40rpx rgba(24, 29, 39, 0.08); }
.badge { display: inline-block; padding: 8rpx 16rpx; border-radius: 999rpx; background: #ffe8d9; color: #a64d21; font-size: 22rpx; }
.title { display: block; margin-top: 18rpx; font-size: 34rpx; font-weight: 600; color: #201815; }
.summary { display: block; margin-top: 12rpx; color: #7d665b; line-height: 1.6; }
.price { display: block; margin-top: 16rpx; font-size: 32rpx; font-weight: 700; color: #d9480f; }
"@
            },
            [ordered]@{
                path = "$basePath.json"
                content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}"
            }
        )
    }
}

function New-WechatProductListingComponentBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $registryBundle = Get-BundleFromRegistry -ComponentName $componentName -ComponentPath $ComponentPath -TemplateContext @{
        '__PRODUCT_BADGE__' = [string]$Recipe.featured_badge
    }
    if ($null -ne $registryBundle) {
        return $registryBundle
    }

    return (New-WechatProductListingComponentBundleHardcoded -Recipe $Recipe -ComponentPath $ComponentPath)
}

function New-WechatProductListingPageBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $pageName = Get-WechatTaskTargetPageName -PagePath $PagePath
    $basePath = $PagePath.Trim().Trim('/') -replace '\\', '/'
    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)
    $cardMarkup = @($Recipe.products | ForEach-Object {
        "    <product-card badge='$($Recipe.featured_badge)' title='$($_.title)' summary='$($_.summary)' price='$($_.price)'></product-card>"
    }) -join "`n"

    return [ordered]@{
        page_name = $pageName
        source = 'hardcoded'
        asset_kind = 'page_template'
        asset_name = 'product-listing'
        files = @(
            [ordered]@{
                path = "$basePath.wxml"
                content = @"
<view class='product-page'>
  <view class='hero'>
    <text class='title'>$($Recipe.hero_title)</text>
    <text class='subtitle'>$($Recipe.hero_subtitle)</text>
  </view>
  <view class='section'>
    <text class='section-title'>$($Recipe.section_title)</text>
    <view class='product-list'>
$cardMarkup
    </view>
  </view>
  <view class='footer-note'>
    <text class='footer-copy'>$($Recipe.footer_copy)</text>
  </view>
</view>
"@
            },
            [ordered]@{
                path = "$basePath.js"
                content = @"
Page({
  data: {
    pageMode: 'product-listing'
  },
  onLoad() {}
})
"@
            },
            [ordered]@{
                path = "$basePath.wxss"
                content = @"
.product-page { min-height: 100vh; padding: 32rpx; background: linear-gradient(180deg, #fffaf5 0%, #ffffff 42%, #fffdf8 100%); }
.hero { margin-bottom: 30rpx; }
.title { display: block; font-size: 48rpx; font-weight: 700; color: #231814; }
.subtitle { display: block; margin-top: 12rpx; color: #7b665c; line-height: 1.6; }
.section { margin-top: 12rpx; }
.section-title { display: block; margin-bottom: 20rpx; font-size: 30rpx; font-weight: 600; color: #8b4513; }
.product-list { display: flex; flex-direction: column; gap: 20rpx; }
.footer-note { margin-top: 28rpx; }
.footer-copy { display: block; color: #8d756b; line-height: 1.6; }
"@
            },
            [ordered]@{
                path = "$basePath.json"
                content = "{`n  `"navigationBarTitleText`": `"$navigationTitle`",`n  `"usingComponents`": {`n    `"product-card`": `"/components/product-card/index`"`n  }`n}"
            }
        )
    }
}

function New-WechatProductListingPageBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)
    $cardMarkup = @($Recipe.products | ForEach-Object {
        "    <product-card badge='$($Recipe.featured_badge)' title='$($_.title)' summary='$($_.summary)' price='$($_.price)'></product-card>"
    }) -join "`n"

    $registryPage = Get-PageFromRegistry -TemplateName 'product-listing' -PagePath $PagePath -TemplateContext @{
        '__PRODUCT_LISTING_HERO_TITLE__' = [string]$Recipe.hero_title
        '__PRODUCT_LISTING_HERO_SUBTITLE__' = [string]$Recipe.hero_subtitle
        '__PRODUCT_LISTING_SECTION_TITLE__' = [string]$Recipe.section_title
        '__PRODUCT_LISTING_CARD_MARKUP__' = [string]$cardMarkup
        '__PRODUCT_LISTING_FOOTER_COPY__' = [string]$Recipe.footer_copy
        '__PRODUCT_LISTING_NAV_TITLE__' = [string]$navigationTitle
    }
    if ($null -ne $registryPage) {
        return $registryPage
    }

    return (New-WechatProductListingPageBundleHardcoded -Recipe $Recipe -PagePath $PagePath -AppPatch $AppPatch)
}

function New-WechatProductDetailComponentBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $basePath = $ComponentPath.Trim().Trim('/') -replace '\\', '/'

    return [ordered]@{
        component_name = $componentName
        source = 'hardcoded'
        asset_kind = 'component'
        asset_name = $componentName
        files = @(
            [ordered]@{ path = "$basePath.wxml"; content = "<view class='buy-wrap'><button class='buy-btn'>{{text}}</button></view>" }
            [ordered]@{ path = "$basePath.js"; content = @"
Component({
  properties: {
    text: {
      type: String,
      value: "$($Recipe.cta_text)"
    }
  },
  data: {},
  methods: {}
})
"@ }
            [ordered]@{ path = "$basePath.wxss"; content = ".buy-wrap { padding-top: 20rpx; }`n.buy-btn { background: #d9480f; color: #ffffff; border-radius: 999rpx; font-size: 30rpx; }" }
            [ordered]@{ path = "$basePath.json"; content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}" }
        )
    }
}

function New-WechatProductDetailComponentBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $registryBundle = Get-BundleFromRegistry -ComponentName $componentName -ComponentPath $ComponentPath -TemplateContext @{
        '__BUY_BUTTON_TEXT__' = [string]$Recipe.cta_text
    }
    if ($null -ne $registryBundle) {
        return $registryBundle
    }

    return (New-WechatProductDetailComponentBundleHardcoded -Recipe $Recipe -ComponentPath $ComponentPath)
}

function New-WechatProductDetailPageBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $pageName = Get-WechatTaskTargetPageName -PagePath $PagePath
    $basePath = $PagePath.Trim().Trim('/') -replace '\\', '/'
    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)

    return [ordered]@{
        page_name = $pageName
        source = 'hardcoded'
        asset_kind = 'page_template'
        asset_name = 'product-detail'
        files = @(
            [ordered]@{ path = "$basePath.wxml"; content = @"
<view class='detail-page'>
  <view class='hero'>
    <text class='title'>$($Recipe.detail_title)</text>
    <text class='subtitle'>$($Recipe.detail_subtitle)</text>
  </view>
  <image class='product-image' src='$($Recipe.image_src)' mode='aspectFill' />
  <view class='detail-card'>
    <text class='product-title'>$($Recipe.product_title)</text>
    <text class='product-description'>$($Recipe.product_description)</text>
    <text class='price'>¥$($Recipe.price)</text>
    <text class='benefits-copy'>$($Recipe.benefits_copy)</text>
    <buy-button text='$($Recipe.cta_text)'></buy-button>
  </view>
</view>
"@ }
            [ordered]@{ path = "$basePath.js"; content = @"
Page({
  data: {
    pageMode: 'product-detail'
  },
  onLoad() {}
})
"@ }
            [ordered]@{ path = "$basePath.wxss"; content = @"
.detail-page { min-height: 100vh; padding: 32rpx; background: linear-gradient(180deg, #fff8f1 0%, #ffffff 44%, #fffdf8 100%); }
.hero { margin-bottom: 24rpx; }
.title { display: block; font-size: 48rpx; font-weight: 700; color: #2a1d18; }
.subtitle { display: block; margin-top: 10rpx; color: #7e695f; line-height: 1.6; }
.product-image { width: 100%; height: 420rpx; border-radius: 28rpx; background: #f5e6dc; }
.detail-card { margin-top: 24rpx; padding: 28rpx; border-radius: 24rpx; background: #ffffff; box-shadow: 0 14rpx 40rpx rgba(24, 29, 39, 0.08); }
.product-title { display: block; font-size: 38rpx; font-weight: 600; color: #271b16; }
.product-description { display: block; margin-top: 14rpx; color: #7d665b; line-height: 1.7; }
.price { display: block; margin-top: 18rpx; font-size: 36rpx; font-weight: 700; color: #d9480f; }
.benefits-copy { display: block; margin-top: 14rpx; color: #8d756b; line-height: 1.6; }
"@ }
            [ordered]@{ path = "$basePath.json"; content = "{`n  `"navigationBarTitleText`": `"$navigationTitle`",`n  `"usingComponents`": {`n    `"buy-button`": `"/components/buy-button/index`"`n  }`n}" }
        )
    }
}

function New-WechatProductDetailPageBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)
    $registryPage = Get-PageFromRegistry -TemplateName 'product-detail' -PagePath $PagePath -TemplateContext @{
        '__PRODUCT_DETAIL_TITLE__' = [string]$Recipe.detail_title
        '__PRODUCT_DETAIL_SUBTITLE__' = [string]$Recipe.detail_subtitle
        '__PRODUCT_DETAIL_IMAGE_SRC__' = [string]$Recipe.image_src
        '__PRODUCT_DETAIL_PRODUCT_TITLE__' = [string]$Recipe.product_title
        '__PRODUCT_DETAIL_PRODUCT_DESCRIPTION__' = [string]$Recipe.product_description
        '__PRODUCT_DETAIL_PRICE__' = [string]$Recipe.price
        '__PRODUCT_DETAIL_BENEFITS_COPY__' = [string]$Recipe.benefits_copy
        '__PRODUCT_DETAIL_CTA_TEXT__' = [string]$Recipe.cta_text
        '__PRODUCT_DETAIL_NAV_TITLE__' = [string]$navigationTitle
    }
    if ($null -ne $registryPage) {
        return $registryPage
    }

    return (New-WechatProductDetailPageBundleHardcoded -Recipe $Recipe -PagePath $PagePath -AppPatch $AppPatch)
}

function New-WechatFoodOrderComponentBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $basePath = $ComponentPath.Trim().Trim('/') -replace '\\', '/'

    switch ($componentName) {
        'food-item' {
            return [ordered]@{
                component_name = $componentName
                source = 'hardcoded'
                asset_kind = 'component'
                asset_name = $componentName
                files = @(
                    [ordered]@{ path = "$basePath.wxml"; content = @"
<view class="food-item">
  <image class="food-image" src="{{image}}" mode="aspectFill" />
  <view class="food-copy">
    <text class="food-name">{{name}}</text>
    <text class="food-desc">{{description}}</text>
    <view class="food-meta">
      <text class="price">`${{price}}</text>
      <view class="quantity-controls">
        <button class="qty-btn" size="mini">-</button>
        <text class="qty-value">{{count}}</text>
        <button class="qty-btn" size="mini">+</button>
      </view>
    </view>
  </view>
</view>
"@ }
                    [ordered]@{ path = "$basePath.js"; content = @"
Component({
  properties: {
    image: {
      type: String,
      value: 'https://dummyimage.com/240x240/f3e1d2/8c4a1f.png&text=Dish'
    },
    name: {
      type: String,
      value: 'Braised Rice Bowl'
    },
    description: {
      type: String,
      value: 'Slow-cooked signature combo with rich sauce.'
    },
    price: {
      type: String,
      value: '18'
    },
    count: {
      type: String,
      value: '1'
    }
  },
  data: {},
  methods: {}
})
"@ }
                    [ordered]@{ path = "$basePath.wxss"; content = @"
.food-item { display: flex; gap: 20rpx; padding: 24rpx; border-radius: 24rpx; background: #ffffff; box-shadow: 0 12rpx 32rpx rgba(40, 27, 20, 0.08); }
.food-image { width: 160rpx; height: 160rpx; border-radius: 20rpx; background: #f6e7da; }
.food-copy { flex: 1; display: flex; flex-direction: column; }
.food-name { font-size: 32rpx; font-weight: 600; color: #2d1f18; }
.food-desc { margin-top: 10rpx; color: #81695c; line-height: 1.6; }
.food-meta { margin-top: 18rpx; display: flex; align-items: center; justify-content: space-between; }
.price { font-size: 34rpx; font-weight: 700; color: #d9480f; }
.quantity-controls { display: flex; align-items: center; gap: 12rpx; }
.qty-btn { width: 56rpx; height: 56rpx; line-height: 56rpx; padding: 0; border-radius: 999rpx; background: #fff2e8; color: #b44c1a; }
.qty-value { min-width: 32rpx; text-align: center; color: #573a2f; }
"@ }
                    [ordered]@{ path = "$basePath.json"; content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}" }
                )
            }
        }
        'cart-summary' {
            return [ordered]@{
                component_name = $componentName
                source = 'hardcoded'
                asset_kind = 'component'
                asset_name = $componentName
                files = @(
                    [ordered]@{ path = "$basePath.wxml"; content = @"
<view class="cart-summary">
  <view class="cart-copy">
    <text class="cart-title">Cart Summary</text>
    <text class="cart-meta">{{count}} items | `${{total}}</text>
  </view>
  <button class="cart-btn">Checkout</button>
</view>
"@ }
                    [ordered]@{ path = "$basePath.js"; content = @"
Component({
  properties: {
    total: {
      type: String,
      value: '56'
    },
    count: {
      type: String,
      value: '3'
    }
  },
  data: {},
  methods: {}
})
"@ }
                    [ordered]@{ path = "$basePath.wxss"; content = @"
.cart-summary { display: flex; align-items: center; justify-content: space-between; padding: 22rpx 24rpx; border-radius: 999rpx; background: #2f1d15; box-shadow: 0 16rpx 40rpx rgba(47, 29, 21, 0.24); }
.cart-copy { display: flex; flex-direction: column; }
.cart-title { color: #fff7f2; font-size: 28rpx; font-weight: 600; }
.cart-meta { margin-top: 6rpx; color: #f6d8c4; font-size: 22rpx; }
.cart-btn { min-width: 180rpx; border-radius: 999rpx; background: #ff8b4d; color: #ffffff; font-size: 28rpx; }
"@ }
                    [ordered]@{ path = "$basePath.json"; content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}" }
                )
            }
        }
        default {
            throw "Unsupported food-order component: $componentName"
        }
    }
}

function New-WechatFoodOrderComponentBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $componentName = Get-WechatTaskTargetComponentName -ComponentPath $ComponentPath
    $registryBundle = Get-BundleFromRegistry -ComponentName $componentName -ComponentPath $ComponentPath
    if ($null -ne $registryBundle) {
        return $registryBundle
    }

    return (New-WechatFoodOrderComponentBundleHardcoded -Recipe $Recipe -ComponentPath $ComponentPath)
}

function New-WechatFoodOrderPageBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $pageName = Get-WechatTaskTargetPageName -PagePath $PagePath
    $basePath = $PagePath.Trim().Trim('/') -replace '\\', '/'
    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)
    $categoryLines = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt @($Recipe.categories).Count; $index++) {
        $indent = if ($index -eq 0) { '        ' } else { '    ' }
        $categoryLines.Add(('{0}<view class="category-chip">{1}</view>' -f $indent, $Recipe.categories[$index])) | Out-Null
    }
    $categoryMarkup = @($categoryLines) -join "`n"
    $itemMarkup = @($Recipe.items | ForEach-Object {
        "    <food-item image='$($_.image)' name='$($_.name)' description='$($_.description)' price='$($_.price)' count='$($_.count)'></food-item>"
    }) -join "`n"
    $cartSection = @"
  <view class="cart-floating">
    <cart-summary total="$($Recipe.total)" count="$($Recipe.count)"></cart-summary>
  </view>
"@
    $checkoutLinkCss = ''
    if ([string]$Recipe.route_mode -eq 'food-order-flow') {
        $cartSection = @"
  <navigator class="checkout-link" url="/pages/checkout/index">$($Recipe.checkout_nav_label)</navigator>
  <view class="cart-floating">
    <cart-summary total="$($Recipe.total)" count="$($Recipe.count)"></cart-summary>
  </view>
"@
        $checkoutLinkCss = ".checkout-link { display: inline-flex; align-items: center; justify-content: center; margin-bottom: 20rpx; padding: 18rpx 24rpx; border-radius: 999rpx; background: #2f1d15; color: #fff7f2; font-size: 26rpx; }"
    }

    return [ordered]@{
        page_name = $pageName
        source = 'hardcoded'
        asset_kind = 'page_template'
        asset_name = 'food-order'
        files = @(
            [ordered]@{ path = "$basePath.wxml"; content = @"
<view class="food-order-page">
  <view class="hero">
    <text class="title">$($Recipe.hero_title)</text>
    <text class="subtitle">$($Recipe.hero_subtitle)</text>
  </view>
  <scroll-view class="category-strip" scroll-x="true" enable-flex="true">
$categoryMarkup
  </scroll-view>
  <view class="menu-list">
$itemMarkup
  </view>
$cartSection
</view>
"@ }
            [ordered]@{ path = "$basePath.js"; content = @"
Page({
  data: {
    pageMode: 'food-order',
    cartTotal: '$($Recipe.total)',
    cartCount: '$($Recipe.count)'
  },
  onLoad() {}
})
"@ }
            [ordered]@{ path = "$basePath.wxss"; content = (@"
.food-order-page { min-height: 100vh; padding: 28rpx; background: linear-gradient(180deg, #fff7f0 0%, #ffffff 40%, #fffdf9 100%); }
.hero { margin-bottom: 24rpx; }
.title { display: block; font-size: 48rpx; font-weight: 700; color: #2c1d15; }
.subtitle { display: block; margin-top: 10rpx; color: #7c675a; line-height: 1.6; }
.category-strip { white-space: nowrap; margin-bottom: 24rpx; }
.category-chip { display: inline-flex; align-items: center; justify-content: center; margin-right: 16rpx; padding: 12rpx 24rpx; border-radius: 999rpx; background: #fff0e3; color: #aa531f; font-size: 24rpx; }
.menu-list { display: flex; flex-direction: column; gap: 20rpx; padding-bottom: 140rpx; }
.cart-floating { position: sticky; bottom: 20rpx; margin-top: 28rpx; }
$checkoutLinkCss
"@).TrimEnd("`r", "`n") }
            [ordered]@{ path = "$basePath.json"; content = "{`n  `"navigationBarTitleText`": `"$navigationTitle`",`n  `"usingComponents`": {`n    `"food-item`": `"/components/food-item/index`",`n    `"cart-summary`": `"/components/cart-summary/index`"`n  }`n}" }
        )
    }
}

function New-WechatFoodOrderPageBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.app_title)
    $categoryMarkup = @($Recipe.categories | ForEach-Object { "    <view class=""category-chip"">$_</view>" }) -join "`n"
    $itemMarkup = @($Recipe.items | ForEach-Object {
        "    <food-item image='$($_.image)' name='$($_.name)' description='$($_.description)' price='$($_.price)' count='$($_.count)'></food-item>"
    }) -join "`n"
    $navigatorMarkup = ''
    if ([string]$Recipe.route_mode -eq 'food-order-flow') {
        $navigatorMarkup = @"
  <navigator class="checkout-link" url="/pages/checkout/index">$($Recipe.checkout_nav_label)</navigator>
"@
    }

    $registryPage = Get-PageFromRegistry -TemplateName 'food-order' -PagePath $PagePath -TemplateContext @{
        '__FOOD_ORDER_TITLE__' = [string]$Recipe.hero_title
        '__FOOD_ORDER_SUBTITLE__' = [string]$Recipe.hero_subtitle
        '__FOOD_ORDER_CATEGORY_MARKUP__' = [string]$categoryMarkup
        '__FOOD_ORDER_ITEM_MARKUP__' = [string]$itemMarkup
        '__FOOD_ORDER_NAVIGATOR_MARKUP__' = [string]$navigatorMarkup
        '__FOOD_ORDER_TOTAL__' = [string]$Recipe.total
        '__FOOD_ORDER_COUNT__' = [string]$Recipe.count
        '__FOOD_ORDER_NAV_TITLE__' = [string]$navigationTitle
    }
    if ($null -ne $registryPage) {
        if (-not [string]::IsNullOrWhiteSpace($navigatorMarkup)) {
            $wxmlEntry = @($registryPage.files | Where-Object { $_.path -like '*.wxml' })[0]
            $wxssEntry = @($registryPage.files | Where-Object { $_.path -like '*.wxss' })[0]
            if ($null -ne $wxmlEntry -and -not $wxmlEntry.content.Contains('/pages/checkout/index')) {
                $wxmlEntry.content = $wxmlEntry.content.Replace('  <view class="cart-floating">', "$navigatorMarkup`n  <view class=""cart-floating"">")
            }
            if ($null -ne $wxssEntry -and -not $wxssEntry.content.Contains('.checkout-link')) {
                $wxssEntry.content = $wxssEntry.content.TrimEnd("`r", "`n") + "`n.checkout-link { display: inline-flex; align-items: center; justify-content: center; margin-bottom: 20rpx; padding: 18rpx 24rpx; border-radius: 999rpx; background: #2f1d15; color: #fff7f2; font-size: 26rpx; }"
            }
        }
        return $registryPage
    }

    return (New-WechatFoodOrderPageBundleHardcoded -Recipe $Recipe -PagePath $PagePath -AppPatch $AppPatch)
}

function New-WechatFoodCheckoutPageBundleHardcoded {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $pageName = Get-WechatTaskTargetPageName -PagePath $PagePath
    $basePath = $PagePath.Trim().Trim('/') -replace '\\', '/'
    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.checkout_title)

    return [ordered]@{
        page_name = $pageName
        source = 'hardcoded'
        asset_kind = 'page_template'
        asset_name = 'food-checkout'
        files = @(
            [ordered]@{ path = "$basePath.wxml"; content = @"
<view class='food-checkout-page'>
  <view class='checkout-hero'>
    <text class='title'>$($Recipe.checkout_title)</text>
    <text class='subtitle'>$($Recipe.checkout_subtitle)</text>
  </view>
  <view class='checkout-card'>
    <view class='checkout-row'>
      <text class='label'>Items</text>
      <text class='value'>$($Recipe.count) dishes</text>
    </view>
    <view class='checkout-row'>
      <text class='label'>Delivery</text>
      <text class='value'>Express pickup in 20 min</text>
    </view>
    <view class='checkout-row total-row'>
      <text class='label'>Total</text>
      <text class='value'>$($Recipe.total)</text>
    </view>
  </view>
  <button class='checkout-submit'>$($Recipe.checkout_cta)</button>
</view>
"@ }
            [ordered]@{ path = "$basePath.js"; content = @"
Page({
  data: {
    pageMode: 'food-checkout',
    total: '$($Recipe.total)',
    count: '$($Recipe.count)'
  },
  onLoad() {}
})
"@ }
            [ordered]@{ path = "$basePath.wxss"; content = @"
.food-checkout-page { min-height: 100vh; padding: 28rpx; background: linear-gradient(180deg, #fff8f1 0%, #ffffff 42%, #fffdf7 100%); }
.checkout-hero { margin-bottom: 24rpx; }
.title { display: block; font-size: 46rpx; font-weight: 700; color: #2b1d16; }
.subtitle { display: block; margin-top: 10rpx; color: #7a6659; line-height: 1.6; }
.checkout-card { padding: 28rpx; border-radius: 24rpx; background: #ffffff; box-shadow: 0 12rpx 32rpx rgba(40, 27, 20, 0.08); }
.checkout-row { display: flex; justify-content: space-between; align-items: center; padding: 18rpx 0; border-bottom: 1rpx solid #f1e5da; }
.checkout-row:last-child { border-bottom: none; }
.label { color: #7a6659; font-size: 26rpx; }
.value { color: #2b1d16; font-size: 28rpx; font-weight: 600; }
.total-row .value { color: #d9480f; font-size: 34rpx; }
.checkout-submit { margin-top: 28rpx; border-radius: 999rpx; background: #ff8b4d; color: #ffffff; font-size: 30rpx; }
"@ }
            [ordered]@{ path = "$basePath.json"; content = "{`n  `"navigationBarTitleText`": `"$navigationTitle`",`n  `"usingComponents`": {}`n}" }
        )
    }
}

function New-WechatFoodCheckoutPageBundle {
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$PagePath,
        [hashtable]$AppPatch = @{}
    )

    $navigationTitle = Get-WechatTaskAppPatchValue -AppPatch $AppPatch -Name 'navigationBarTitleText' -Default ([string]$Recipe.checkout_title)
    $registryPage = Get-PageFromRegistry -TemplateName 'food-checkout' -PagePath $PagePath -TemplateContext @{
        '__FOOD_CHECKOUT_TITLE__' = [string]$Recipe.checkout_title
        '__FOOD_CHECKOUT_SUBTITLE__' = [string]$Recipe.checkout_subtitle
        '__FOOD_CHECKOUT_TOTAL__' = [string]$Recipe.total
        '__FOOD_CHECKOUT_COUNT__' = [string]$Recipe.count
        '__FOOD_CHECKOUT_CTA__' = [string]$Recipe.checkout_cta
        '__FOOD_CHECKOUT_NAV_TITLE__' = [string]$navigationTitle
    }
    if ($null -ne $registryPage) {
        return $registryPage
    }

    return (New-WechatFoodCheckoutPageBundleHardcoded -Recipe $Recipe -PagePath $PagePath -AppPatch $AppPatch)
}

function Merge-WechatPageBundles {
    param(
        [Parameter(Mandatory)][object[]]$PageBundles,
        [Parameter(Mandatory)][string]$AssetName
    )

    $sources = @($PageBundles | ForEach-Object { Get-WechatBundleMetadataValue -Bundle $_ -Name 'source' -Default 'unknown' } | Select-Object -Unique)
    $mergedSource = if ($sources.Count -eq 1) { [string]$sources[0] } elseif ($sources.Count -gt 1) { 'mixed' } else { 'unknown' }
    $allFiles = @()
    foreach ($bundle in $PageBundles) {
        $allFiles += @($bundle.files)
    }

    return [ordered]@{
        page_name = [string]$PageBundles[0].page_name
        source = $mergedSource
        asset_kind = 'page_template'
        asset_name = $AssetName
        files = $allFiles
    }
}

function Invoke-TaskSpecToBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$TaskSpec
    )

    Test-WechatTaskSpec -TaskSpec $TaskSpec | Out-Null

    $recipe = Get-WechatTaskRecipeForSpec -TaskSpec $TaskSpec
    $targetPage = @($TaskSpec.target_pages)[0]
    $targetComponent = @($TaskSpec.required_components)[0]
    if ($null -eq $targetPage) {
        throw 'TaskSpec compilation requires one target page.'
    }
    if ($null -eq $targetComponent) {
        throw 'TaskSpec compilation requires one required component.'
    }

    $pageBundle = $null
    $componentBundle = $null

    switch ([string]$TaskSpec.task_family) {
        'marketing-empty-state' {
            $componentBundle = New-WechatMarketingComponentBundle -Recipe $recipe -ComponentPath ([string]$targetComponent.path)
            $pageBundle = New-WechatMarketingPageBundle -Recipe $recipe -PagePath ([string]$targetPage.path) -AppPatch $TaskSpec.app_patch
        }
        'product-listing' {
            $componentBundle = New-WechatProductListingComponentBundle -Recipe $recipe -ComponentPath ([string]$targetComponent.path)
            $pageBundle = New-WechatProductListingPageBundle -Recipe $recipe -PagePath ([string]$targetPage.path) -AppPatch $TaskSpec.app_patch
        }
        'product-detail' {
            $componentBundle = New-WechatProductDetailComponentBundle -Recipe $recipe -ComponentPath ([string]$targetComponent.path)
            $pageBundle = New-WechatProductDetailPageBundle -Recipe $recipe -PagePath ([string]$targetPage.path) -AppPatch $TaskSpec.app_patch
        }
        'food-order' {
            $componentBundles = @()
            foreach ($componentTarget in @($TaskSpec.required_components)) {
                $componentBundles += ,(New-WechatFoodOrderComponentBundle -Recipe $recipe -ComponentPath ([string]$componentTarget.path))
            }
            $componentBundle = if ($componentBundles.Count -gt 0) { $componentBundles[0] } else { $null }
            if ([string]$TaskSpec.route_mode -eq 'food-order-flow') {
                $orderPageBundle = New-WechatFoodOrderPageBundle -Recipe $recipe -PagePath 'pages/index/index' -AppPatch $TaskSpec.app_patch
                $checkoutPageBundle = New-WechatFoodCheckoutPageBundle -Recipe $recipe -PagePath 'pages/checkout/index' -AppPatch @{ navigationBarTitleText = $Recipe.checkout_title }
                $pageBundle = Merge-WechatPageBundles -PageBundles @($orderPageBundle, $checkoutPageBundle) -AssetName 'food-order-flow'
            }
            else {
                $pageBundle = New-WechatFoodOrderPageBundle -Recipe $recipe -PagePath ([string]$targetPage.path) -AppPatch $TaskSpec.app_patch
            }
        }
        default {
            throw "Unsupported TaskSpec family for compilation: $($TaskSpec.task_family)"
        }
    }

    if ($null -eq $componentBundles) {
        $componentBundles = if ($null -ne $componentBundle) { @($componentBundle) } else { @() }
    }

    $componentSources = @($componentBundles | ForEach-Object { Get-WechatBundleMetadataValue -Bundle $_ -Name 'source' -Default 'unknown' } | Select-Object -Unique)
    $componentSource = if ($componentSources.Count -eq 1) { [string]$componentSources[0] } elseif ($componentSources.Count -gt 1) { 'mixed' } else { 'unknown' }

    return [pscustomobject]@{
        status = 'success'
        task_family = [string]$TaskSpec.task_family
        route_mode = [string]$TaskSpec.route_mode
        page_bundle = $pageBundle
        component_bundle = $componentBundle
        component_bundles = @($componentBundles)
        bundle_sources = [pscustomobject]@{
            page = Get-WechatBundleMetadataValue -Bundle $pageBundle -Name 'source' -Default 'unknown'
            component = $componentSource
        }
        app_patch = (New-WechatTaskAppPatchPayload -TaskSpec $TaskSpec)
    }
}
