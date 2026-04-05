[CmdletBinding()]
param()

function Write-WechatTaskUtf8Json {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 20
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function New-WechatTaskBundlePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$Slug
    )

    $taskRoot = Join-Path $ProjectDir '.agents\tasks'
    New-Item -ItemType Directory -Force -Path $taskRoot | Out-Null
    return (Join-Path $taskRoot ("{0}.json" -f $Slug))
}

function New-WechatMarketingEmptyStateRecipe {
    param(
        [Parameter(Mandatory)][string]$Variant
    )

    switch ($Variant) {
        'coupon-empty-state' {
            return @{
                route_mode = 'coupon-empty-state'
                component_prompt = 'Create a reusable coupon CTA button component with a configurable text label.'
                shell_prompt = 'build a notebook mini program'
                page_spec_prompt = 'Create a clean mobile-first coupon center empty-state page shell.'
                app_title = 'Coupon Center'
                project_name = 'coupon-center-app'
                cta_component = 'cta-button'
                cta_default_text = 'Claim Coupon'
                page_title = 'Coupon Center'
                hero_subtitle = 'Your offers will appear here once new campaigns are available.'
                empty_title = 'No coupons available yet'
                empty_copy = 'Follow the latest promotions and claim your first coupon when the next activity starts.'
                rules_title = 'Coupon rules'
                rules_items = @(
                    '1. One coupon can be claimed per account during each campaign.',
                    '2. Coupons are applied automatically when order conditions are met.',
                    '3. Expired or redeemed coupons cannot be restored.'
                )
            }
        }
        'activity-not-started' {
            return @{
                route_mode = 'activity-not-started'
                component_prompt = 'Create a reusable campaign CTA button component with a configurable text label.'
                shell_prompt = 'build a notebook mini program'
                page_spec_prompt = 'Create a clean mobile-first campaign page that shows an activity has not started yet.'
                app_title = 'Campaign Center'
                project_name = 'campaign-center-app'
                cta_component = 'cta-button'
                cta_default_text = 'Notify Me'
                page_title = 'Campaign Center'
                hero_subtitle = 'Major seasonal campaigns, flash deals, and new member offers will land here.'
                empty_title = 'The event has not started yet'
                empty_copy = 'Save this page and come back when the campaign countdown ends to unlock the first wave of offers.'
                countdown_label = 'Campaign starts in'
                countdown_value = '02:15:00'
                rules_title = 'Activity notes'
                rules_items = @(
                    '1. Campaign offers become visible once the event officially starts.',
                    '2. Reminders help you return on time, but stock is still limited.',
                    '3. Event rules may change before the final launch phase.'
                )
            }
        }
        'benefits-empty-state' {
            return @{
                route_mode = 'benefits-empty-state'
                component_prompt = 'Create a reusable benefits CTA button component with a configurable text label.'
                shell_prompt = 'build a notebook mini program'
                page_spec_prompt = 'Create a clean mobile-first benefits center empty-state page shell.'
                app_title = 'Benefits Center'
                project_name = 'benefits-center-app'
                cta_component = 'cta-button'
                cta_default_text = 'Unlock Benefits'
                page_title = 'Benefits Center'
                hero_subtitle = 'Membership perks, delivery vouchers, and exclusive rewards will appear here after activation.'
                empty_title = 'No benefits unlocked yet'
                empty_copy = 'Complete the current activation steps to unlock your first benefits package and save it to your account.'
                benefits_title = 'Benefits preview'
                benefits_items = @(
                    'Member-only delivery voucher',
                    'Exclusive weekly tasting perk',
                    'Points multiplier on combo orders'
                )
                rules_title = 'Benefits policy'
                rules_items = @(
                    '1. Benefits are activated only after the current membership requirements are met.',
                    '2. Some benefits can be claimed once per cycle, others unlock automatically.',
                    '3. Benefits are account-bound and cannot be transferred to other users.'
                )
            }
        }
        default {
            throw "Unsupported marketing empty-state variant: $Variant"
        }
    }
}

function Resolve-WechatMarketingEmptyStateRecipe {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $normalized = $TaskText.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    $couponHint = $normalized -match 'coupon|claim coupon|coupon center'
    $couponSupport = $normalized -match 'empty-state|empty state|no coupons|claim|cta|button|rules|rule text|policy|campaign'
    if ($couponHint -and $couponSupport) {
        return New-WechatMarketingEmptyStateRecipe -Variant 'coupon-empty-state'
    }

    $activityHint = $normalized -match 'activity|campaign|event|launch'
    $activitySupport = $normalized -match 'not started|not-started|coming soon|upcoming|countdown|notify|remind'
    if ($activityHint -and $activitySupport) {
        return New-WechatMarketingEmptyStateRecipe -Variant 'activity-not-started'
    }

    $benefitsHint = $normalized -match 'benefits|benefit center|benefit centre|privilege|privileges|member perks|perks|welfare'
    $benefitsSupport = $normalized -match 'empty|empty-state|unlock|claim|activate|activation|cta|button'
    if ($benefitsHint -and $benefitsSupport) {
        return New-WechatMarketingEmptyStateRecipe -Variant 'benefits-empty-state'
    }

    return $null
}

function Resolve-WechatProductListingRecipe {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $normalized = $TaskText.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    $productHint = $normalized -match 'product|products|goods|catalog|catalogue|shop|store'
    $listingHint = $normalized -match 'list|listing|grid|shelf|cards|browse'
    if (-not ($productHint -and $listingHint)) {
        return $null
    }

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

function Resolve-WechatProductDetailRecipe {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $normalized = $TaskText.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    $productHint = $normalized -match 'product|goods|item|shop|store|sku'
    $detailHint = $normalized -match 'detail|details|detail page|view detail|product detail'
    if (-not ($productHint -and $detailHint)) {
        return $null
    }

    return @{
        route_mode = 'product-detail'
        shell_prompt = 'build a notebook mini program'
        app_title = 'Product Detail'
        project_name = 'product-detail-app'
        component_prompt = 'Create a reusable add-to-cart CTA button component for a product detail mini program page.'
        component_name = 'buy-button'
        image_src = 'https://dummyimage.com/720x480/f7e7d7/8b4513.png&text=Product+Image'
        product_title = 'Signature Braised Platter'
        product_description = 'A ready-to-heat selection with rich braised flavor, layered spices, and a family-size portion.'
        price = '58'
        detail_title = 'Product Detail'
        detail_subtitle = 'Everything you need before placing the order.'
        cta_text = 'Add to Cart'
        benefits_copy = 'Includes reheating guide, serving suggestion, and limited-time member discount.'
    }
}

function Resolve-WechatFoodOrderRecipe {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $normalized = $TaskText.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $null
    }

    $foodHint = $normalized -match 'food-order|food order|menu|takeout|delivery|restaurant|meal|order food'
    $chineseHint = $false
    if (-not ($foodHint -or $chineseHint)) {
        return $null
    }

    $flowHint = $normalized -match 'checkout|check out|linked together|flow|multi-page|multi page'

    return @{
        route_mode = $(if ($flowHint) { 'food-order-flow' } else { 'food-order' })
        shell_prompt = 'build a notebook mini program'
        app_title = 'Food Order'
        project_name = 'food-order-app'
        hero_title = 'Order Your Meal'
        hero_subtitle = 'Browse categories, pick dishes, and keep the cart visible while ordering.'
        checkout_title = 'Checkout Summary'
        checkout_subtitle = 'Review your dishes and confirm the order before payment.'
        checkout_cta = 'Place Order'
        checkout_nav_label = 'Review Cart and Checkout'
        checkout_page_path = 'pages/checkout/index'
        categories = @('Popular', 'Rice Bowls', 'Braised Dishes', 'Drinks')
        items = @(
            @{ name = 'Braised Pork Rice'; description = 'Signature rice bowl with slow-cooked pork and pickles.'; price = '18'; count = '1'; image = 'https://dummyimage.com/240x240/f3e1d2/8c4a1f.png&text=Pork+Rice' },
            @{ name = 'Spicy Tofu Box'; description = 'Silky tofu with chili oil, mushroom, and sesame greens.'; price = '16'; count = '0'; image = 'https://dummyimage.com/240x240/f7e6d7/8b4d22.png&text=Tofu+Box' },
            @{ name = 'Plum Juice'; description = 'House drink to pair with the main meal.'; price = '6'; count = '2'; image = 'https://dummyimage.com/240x240/f9ead7/9f5a2b.png&text=Drink' }
        )
        total = '30'
        count = '3'
    }
}

function Set-WechatMarketingProjectIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$NavigationTitle,
        [Parameter(Mandatory)][string]$ProjectName
    )

    $appJsonPath = Join-Path $ProjectDir 'app.json'
    $projectConfigPath = Join-Path $ProjectDir 'project.config.json'

    if (-not (Test-Path $appJsonPath)) {
        throw "Coupon task identity update failed: missing app.json at $appJsonPath"
    }

    if (-not (Test-Path $projectConfigPath)) {
        throw "Coupon task identity update failed: missing project.config.json at $projectConfigPath"
    }

    $appJson = Get-Content $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $appJson.window) {
        $appJson | Add-Member -MemberType NoteProperty -Name 'window' -Value ([ordered]@{})
    }
    $appJson.window.navigationBarTitleText = $NavigationTitle
    Write-WechatTaskUtf8Json -Path $appJsonPath -Value $appJson

    $projectConfig = Get-Content $projectConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $projectConfig.projectname = $ProjectName
    Write-WechatTaskUtf8Json -Path $projectConfigPath -Value $projectConfig

    return [pscustomobject]@{
        status = 'success'
        app_title = $NavigationTitle
        project_name = $ProjectName
    }
}

function Test-WechatCouponEmptyStateTask {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $normalized = $TaskText.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $false
    }

    $couponHint = $normalized -match 'coupon|claim coupon|coupon center'
    $emptyHint = $normalized -match 'empty-state|empty state|no coupons|empty'
    $ctaHint = $normalized -match 'cta|claim|button'
    $rulesHint = $normalized -match 'rules|rule text|policy'

    return ($couponHint -and ($emptyHint -or $ctaHint -or $rulesHint))
}

function Invoke-WechatMarketingEmptyStateTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$TaskText,
        [string]$OutputDir = '',
        [bool]$Open = $false,
        [bool]$Preview = $false,
        [bool]$RunRepairLoop = $false,
        [int]$MaxRepairRounds = 2
    )

    $create = Invoke-WechatCreate `
        -Prompt $Recipe.shell_prompt `
        -OutputDir $OutputDir `
        -Open $false `
        -Preview $false `
        -RunFastGate $false

    if ($create.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'create'
            reason = 'project_shell_create_failed'
            create_result = $create
        }
    }

    $projectDir = $create.project_dir
    $identityUpdate = Set-WechatMarketingProjectIdentity `
        -ProjectDir $projectDir `
        -NavigationTitle $Recipe.app_title `
        -ProjectName $Recipe.project_name

    $componentStep = Invoke-WechatGenerateComponent `
        -Prompt $Recipe.component_prompt `
        -ComponentPath 'components/cta-button/index' `
        -TargetWorkspace $projectDir

    if ($componentStep.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'component-spec'
            reason = 'component_spec_generation_failed'
            project_dir = $projectDir
            component_result = $componentStep
        }
    }

    $componentBundle = @{
        component_name = $Recipe.cta_component
        files = @(
            @{
                path = 'components/cta-button/index.wxml'
                content = "<view class='cta-wrap'><button class='cta-btn'>{{text}}</button></view>"
            },
            @{
                path = 'components/cta-button/index.js'
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
            @{
                path = 'components/cta-button/index.wxss'
                content = ".cta-wrap { padding: 16rpx 0; }`n.cta-btn { background: #ff7a45; color: #ffffff; border-radius: 999rpx; font-size: 30rpx; }"
            },
            @{
                path = 'components/cta-button/index.json'
                content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}"
            }
        )
    }

    $componentBundle | ConvertTo-Json -Depth 10 | Set-Content -Path $componentStep.bundle_path -Encoding UTF8
    $componentApply = & (Join-Path $PSScriptRoot 'wechat-apply-component-bundle.ps1') `
        -JsonFilePath $componentStep.bundle_path `
        -TargetWorkspace $projectDir

    if ($componentApply.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'component-apply'
            reason = 'component_bundle_apply_failed'
            project_dir = $projectDir
            component_result = $componentApply
        }
    }

    $pageBundlePath = New-WechatTaskBundlePath -ProjectDir $projectDir -Slug ("marketing-page-{0}" -f $Recipe.route_mode)

    $rulesItems = @($Recipe.rules_items | ForEach-Object {
        "    <text class='rules-item'>$_</text>"
    }) -join "`n"

    $pageBundle = @{
        page_name = 'index'
        files = @(
            @{
                path = 'pages/index/index.wxml'
                content = @"
<view class='coupon-page'>
  <view class='hero'>
    <text class='title'>$($Recipe.page_title)</text>
    <text class='subtitle'>$($Recipe.hero_subtitle)</text>
  </view>
  <view class='empty-state'>
    <text class='empty-title'>$($Recipe.empty_title)</text>
    <text class='empty-copy'>$($Recipe.empty_copy)</text>
    <cta-button text='$($Recipe.cta_default_text)'></cta-button>
  </view>
  <view class='rules-card'>
    <text class='rules-title'>$($Recipe.rules_title)</text>
$rulesItems
  </view>
</view>
"@
            },
            @{
                path = 'pages/index/index.js'
                content = @"
Page({
  data: {
    pageMode: '$($Recipe.route_mode)'
  },
  onLoad() {}
})
"@
            },
            @{
                path = 'pages/index/index.wxss'
                content = @"
.coupon-page { min-height: 100vh; padding: 32rpx; background: linear-gradient(180deg, #fff7f0 0%, #fff 48%, #fffdf8 100%); }
.hero { margin-bottom: 36rpx; }
.title { display: block; font-size: 48rpx; font-weight: 700; color: #2f241f; }
.subtitle { display: block; margin-top: 12rpx; color: #8a6f63; line-height: 1.6; }
.empty-state { padding: 32rpx; border-radius: 28rpx; background: #ffffff; box-shadow: 0 18rpx 50rpx rgba(255, 122, 69, 0.12); }
.empty-title { display: block; font-size: 36rpx; font-weight: 600; color: #2f241f; }
.empty-copy { display: block; margin-top: 14rpx; color: #7e6a60; line-height: 1.7; }
.rules-card { margin-top: 28rpx; padding: 28rpx; border-radius: 24rpx; background: #fff; border: 2rpx solid #ffe0cf; }
.rules-title { display: block; margin-bottom: 16rpx; font-size: 30rpx; font-weight: 600; color: #7a4028; }
.rules-item { display: block; color: #8a6f63; line-height: 1.8; }
"@
            },
            @{
                path = 'pages/index/index.json'
                content = "{`n  `"navigationBarTitleText`": `"$($Recipe.app_title)`",`n  `"usingComponents`": {`n    `"cta-button`": `"/components/cta-button/index`"`n  }`n}"
            }
        )
    }

    $pageBundle | ConvertTo-Json -Depth 10 | Set-Content -Path $pageBundlePath -Encoding UTF8
    $pageApply = & (Join-Path $PSScriptRoot 'wechat-apply-bundle.ps1') `
        -JsonFilePath $pageBundlePath `
        -TargetWorkspace $projectDir

    if ($pageApply.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'page-apply'
            reason = 'page_bundle_apply_failed'
            project_dir = $projectDir
            page_result = $pageApply
        }
    }

    $openResult = @{ status = 'skipped' }
    if ($Open) {
        $openResult = Invoke-GeneratedProjectOpen -ProjectPath $projectDir
    }

    $previewResult = @{ status = 'skipped' }
    if ($Preview) {
        $previewResult = Invoke-GeneratedProjectPreview -ProjectPath $projectDir -RequireConfirm $false
    }

    $repairLoop = $null
    if ($RunRepairLoop) {
        . (Join-Path (Split-Path $PSScriptRoot -Parent) 'diagnostics\Invoke-RepairLoopAuto.ps1')
        $repairLoop = Invoke-RepairLoopAuto `
            -PagePath 'pages/index/index' `
            -ProjectPath $projectDir `
            -MaxRounds $MaxRepairRounds `
            -PreferredDetector 'screenshot' `
            -RepairConfidenceThreshold 0.50 `
            -EnforcePageRecognition:$false
    }

    $finalStatus = 'success'
    if ($RunRepairLoop -and $null -ne $repairLoop) {
        $finalStatus = [string]$repairLoop.status
    }

    return @{
        status = $finalStatus
        route_family = $Recipe.route_mode
        task = $TaskText
        project_dir = $projectDir
        template = $create.template
        project_identity = $identityUpdate
        open_status = if ($openResult.status) { $openResult.status } else { 'unknown' }
        preview_status = if ($previewResult.status) { $previewResult.status } else { 'unknown' }
        preview_result = $previewResult
        repair_loop = $repairLoop
        component_written = Test-Path (Join-Path $projectDir 'components\cta-button\index.js')
        page_written = Test-Path (Join-Path $projectDir 'pages\index\index.wxml')
    }
}

function Invoke-WechatProductListingTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$TaskText,
        [string]$OutputDir = '',
        [bool]$Open = $false,
        [bool]$Preview = $false,
        [bool]$RunRepairLoop = $false,
        [int]$MaxRepairRounds = 2
    )

    $create = Invoke-WechatCreate `
        -Prompt $Recipe.shell_prompt `
        -OutputDir $OutputDir `
        -Open $false `
        -Preview $false `
        -RunFastGate $false

    if ($create.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'create'
            reason = 'project_shell_create_failed'
            create_result = $create
        }
    }

    $projectDir = $create.project_dir
    $identityUpdate = Set-WechatMarketingProjectIdentity `
        -ProjectDir $projectDir `
        -NavigationTitle $Recipe.app_title `
        -ProjectName $Recipe.project_name

    $componentStep = Invoke-WechatGenerateComponent `
        -Prompt $Recipe.component_prompt `
        -ComponentPath 'components/product-card/index' `
        -TargetWorkspace $projectDir

    if ($componentStep.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'component-spec'
            reason = 'component_spec_generation_failed'
            project_dir = $projectDir
            component_result = $componentStep
        }
    }

    $componentBundle = @{
        component_name = $Recipe.component_name
        files = @(
            @{
                path = 'components/product-card/index.wxml'
                content = @"
<view class='product-card'>
  <text class='badge'>{{badge}}</text>
  <text class='title'>{{title}}</text>
  <text class='summary'>{{summary}}</text>
  <text class='price'>妤納{price}}</text>
</view>
"@
            },
            @{
                path = 'components/product-card/index.js'
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
            @{
                path = 'components/product-card/index.wxss'
                content = @"
.product-card { padding: 28rpx; border-radius: 24rpx; background: #ffffff; box-shadow: 0 14rpx 40rpx rgba(24, 29, 39, 0.08); }
.badge { display: inline-block; padding: 8rpx 16rpx; border-radius: 999rpx; background: #ffe8d9; color: #a64d21; font-size: 22rpx; }
.title { display: block; margin-top: 18rpx; font-size: 34rpx; font-weight: 600; color: #201815; }
.summary { display: block; margin-top: 12rpx; color: #7d665b; line-height: 1.6; }
.price { display: block; margin-top: 16rpx; font-size: 32rpx; font-weight: 700; color: #d9480f; }
"@
            },
            @{
                path = 'components/product-card/index.json'
                content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}"
            }
        )
    }

    $componentBundle | ConvertTo-Json -Depth 10 | Set-Content -Path $componentStep.bundle_path -Encoding UTF8
    $componentApply = & (Join-Path $PSScriptRoot 'wechat-apply-component-bundle.ps1') `
        -JsonFilePath $componentStep.bundle_path `
        -TargetWorkspace $projectDir

    if ($componentApply.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'component-apply'
            reason = 'component_bundle_apply_failed'
            project_dir = $projectDir
            component_result = $componentApply
        }
    }

    $cardMarkup = @($Recipe.products | ForEach-Object {
        "    <product-card badge='$($Recipe.featured_badge)' title='$($_.title)' summary='$($_.summary)' price='$($_.price)'></product-card>"
    }) -join "`n"
    $pageBundlePath = New-WechatTaskBundlePath -ProjectDir $projectDir -Slug 'product-listing-page'

    $pageBundle = @{
        page_name = 'index'
        files = @(
            @{
                path = 'pages/index/index.wxml'
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
            @{
                path = 'pages/index/index.js'
                content = @"
Page({
  data: {
    pageMode: 'product-listing'
  },
  onLoad() {}
})
"@
            },
            @{
                path = 'pages/index/index.wxss'
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
            @{
                path = 'pages/index/index.json'
                content = "{`n  `"navigationBarTitleText`": `"$($Recipe.app_title)`",`n  `"usingComponents`": {`n    `"product-card`": `"/components/product-card/index`"`n  }`n}"
            }
        )
    }

    $pageBundle | ConvertTo-Json -Depth 10 | Set-Content -Path $pageBundlePath -Encoding UTF8
    $pageApply = & (Join-Path $PSScriptRoot 'wechat-apply-bundle.ps1') `
        -JsonFilePath $pageBundlePath `
        -TargetWorkspace $projectDir

    if ($pageApply.status -ne 'success') {
        return @{
            status = 'failed'
            stage = 'page-apply'
            reason = 'page_bundle_apply_failed'
            project_dir = $projectDir
            page_result = $pageApply
        }
    }

    $repairLoop = $null
    if ($RunRepairLoop) {
        . (Join-Path (Split-Path $PSScriptRoot -Parent) 'diagnostics\Invoke-RepairLoopAuto.ps1')
        $repairLoop = Invoke-RepairLoopAuto `
            -PagePath 'pages/index/index' `
            -ProjectPath $projectDir `
            -MaxRounds $MaxRepairRounds `
            -PreferredDetector 'screenshot' `
            -RepairConfidenceThreshold 0.50 `
            -EnforcePageRecognition:$false
    }

    $finalStatus = 'success'
    if ($RunRepairLoop -and $null -ne $repairLoop) {
        $finalStatus = [string]$repairLoop.status
    }

    return @{
        status = $finalStatus
        route_family = $Recipe.route_mode
        task = $TaskText
        project_dir = $projectDir
        template = $create.template
        project_identity = $identityUpdate
        repair_loop = $repairLoop
        component_written = Test-Path (Join-Path $projectDir 'components\product-card\index.js')
        page_written = Test-Path (Join-Path $projectDir 'pages\index\index.wxml')
    }
}

function Invoke-WechatProductDetailTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$TaskText,
        [string]$OutputDir = '',
        [bool]$Open = $false,
        [bool]$Preview = $false,
        [bool]$RunRepairLoop = $false,
        [int]$MaxRepairRounds = 2
    )

    if (-not (Get-Command New-WechatTaskSpecFromProductRecipe -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\wechat-task-translator.ps1"
    }

    if (-not (Get-Command Invoke-WechatTaskExecution -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\wechat-task-executor.ps1"
    }

    $taskSpec = New-WechatTaskSpecFromProductRecipe -Recipe $Recipe -Goal $TaskText
    $compiled = Invoke-TaskSpecToBundle -TaskSpec $taskSpec
    $execution = Invoke-WechatTaskExecution `
        -TaskSpec $taskSpec `
        -PageBundle $compiled.page_bundle `
        -ComponentBundle $compiled.component_bundle `
        -AppPatch $compiled.app_patch `
        -OutputDir $OutputDir `
        -Preview $Preview

    $projectDir = if ($execution.PSObject.Properties.Name -contains 'project_dir') {
        [string]$execution.project_dir
    }
    else {
        ''
    }

    return @{
        status = [string]$execution.status
        route_family = $Recipe.route_mode
        task = $TaskText
        project_dir = $projectDir
        template = 'notebook'
        project_identity = $execution.project_identity
        preview_result = $execution.preview_result
        acceptance = $execution.acceptance
        acceptance_repair_loop = $execution.acceptance_repair_loop
        execution_result = $execution
        component_written = if ([string]::IsNullOrWhiteSpace($projectDir)) { $false } else { Test-Path (Join-Path $projectDir 'components\buy-button\index.js') }
        page_written = if ([string]::IsNullOrWhiteSpace($projectDir)) { $false } else { Test-Path (Join-Path $projectDir 'pages\index\index.wxml') }
        open_status = if ($Open) { 'not_supported' } else { 'skipped' }
        repair_loop = if ($RunRepairLoop) { $execution.acceptance_repair_loop } else { $null }
        max_repair_rounds = $MaxRepairRounds
    }
}

function Invoke-WechatCouponEmptyStateTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskText,
        [string]$OutputDir = '',
        [bool]$Open = $false,
        [bool]$Preview = $false,
        [bool]$RunRepairLoop = $false,
        [int]$MaxRepairRounds = 2
    )

    $recipe = New-WechatMarketingEmptyStateRecipe -Variant 'coupon-empty-state'
    return Invoke-WechatMarketingEmptyStateTask `
        -Recipe $recipe `
        -TaskText $TaskText `
        -OutputDir $OutputDir `
        -Open $Open `
        -Preview $Preview `
        -RunRepairLoop $RunRepairLoop `
        -MaxRepairRounds $MaxRepairRounds
}
