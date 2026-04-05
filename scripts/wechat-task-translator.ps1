[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-task-spec.ps1"

if (-not (Get-Command Invoke-TaskSpecToBundle -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-task-bundle-compiler.ps1"
}

if (-not (Get-Command Resolve-WechatMarketingEmptyStateRecipe -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-task-product-routing.ps1"
}

function New-WechatTaskSpecFromMarketingRecipe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$Goal
    )

    $repairStrategy = switch ([string]$Recipe.route_mode) {
        'activity-not-started' {
            New-WechatTaskRepairStrategy -Family 'marketing-empty-state' -MaxRounds 3 -SupportedCodes @(
                'missing_activity_title',
                'missing_countdown_placeholder',
                'missing_notify_cta',
                'missing_expected_text',
                'missing_component_ref'
            )
        }
        'benefits-empty-state' {
            New-WechatTaskRepairStrategy -Family 'marketing-empty-state' -MaxRounds 3 -SupportedCodes @(
                'missing_benefits_title',
                'missing_benefits_list',
                'missing_benefits_cta',
                'missing_expected_text',
                'missing_component_ref'
            )
        }
        default {
            New-WechatTaskRepairStrategy -Family 'marketing-empty-state' -MaxRounds 3 -SupportedCodes @(
                'missing_cta_button',
                'missing_rules_section',
                'missing_expected_text',
                'missing_component_ref'
            )
        }
    }

    return (New-WechatTaskSpec `
        -TaskIntent 'generated-product' `
        -TaskFamily 'marketing-empty-state' `
        -RouteMode $Recipe.route_mode `
        -Goal $Goal `
        -TargetPages @(
            (New-WechatTaskTarget -Path 'pages/index/index' -BundleKind 'page')
        ) `
        -RequiredComponents @(
            (New-WechatTaskTarget -Path ('components/{0}/index' -f $Recipe.cta_component) -BundleKind 'component')
        ) `
        -AppPatch @{
            navigationBarTitleText = $Recipe.app_title
            projectname = $Recipe.project_name
        } `
        -AcceptanceChecks @(
            (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.page_title),
            (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.cta_default_text),
            (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.rules_title)
        ) `
        -RepairStrategy $repairStrategy)
}

function New-WechatTaskSpecFromProductRecipe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$Goal
    )

    $acceptanceChecks = switch ([string]$Recipe.route_mode) {
        'product-detail' {
            @(
                (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.product_title),
                (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.cta_text),
                (New-WechatTaskAcceptanceCheck -Type 'component_ref' -Target 'pages/index/index.json' -Expected $Recipe.component_name)
            )
        }
        default {
            @(
                (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.hero_title),
                (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.section_title),
                (New-WechatTaskAcceptanceCheck -Type 'component_ref' -Target 'pages/index/index.json' -Expected $Recipe.component_name)
            )
        }
    }

    $repairStrategy = switch ([string]$Recipe.route_mode) {
        'product-detail' {
            New-WechatTaskRepairStrategy -Family 'product-detail' -MaxRounds 3 -SupportedCodes @(
                'missing_detail_image',
                'missing_detail_title',
                'missing_price_display',
                'missing_add_to_cart_cta',
                'missing_component_ref',
                'missing_expected_text'
            )
        }
        default {
            New-WechatTaskRepairStrategy -Family 'product-listing' -MaxRounds 3 -SupportedCodes @(
                'missing_product_list_container',
                'missing_price_display',
                'missing_expected_text',
                'missing_component_ref'
            )
        }
    }

    return (New-WechatTaskSpec `
        -TaskIntent 'generated-product' `
        -TaskFamily ([string]$Recipe.route_mode) `
        -RouteMode $Recipe.route_mode `
        -Goal $Goal `
        -TargetPages @(
            (New-WechatTaskTarget -Path 'pages/index/index' -BundleKind 'page')
        ) `
        -RequiredComponents @(
            (New-WechatTaskTarget -Path ('components/{0}/index' -f $Recipe.component_name) -BundleKind 'component')
        ) `
        -AppPatch @{
            navigationBarTitleText = $Recipe.app_title
            projectname = $Recipe.project_name
        } `
        -AcceptanceChecks $acceptanceChecks `
        -RepairStrategy $repairStrategy)
}

function New-WechatTaskSpecFromFoodOrderRecipe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Recipe,
        [Parameter(Mandatory)][string]$Goal
    )

    $repairStrategy = New-WechatTaskRepairStrategy -Family 'food-order' -MaxRounds 3 -SupportedCodes @(
        'missing_food_list',
        'missing_price_display',
        'missing_cart_summary',
        'missing_quantity_controls',
        'missing_checkout_navigator',
        'missing_component_ref',
        'missing_expected_text'
    )

    $targetPages = @(
        (New-WechatTaskTarget -Path 'pages/index/index' -BundleKind 'page')
    )
    $acceptanceChecks = @(
        (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.hero_title),
        (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected $Recipe.hero_subtitle),
        (New-WechatTaskAcceptanceCheck -Type 'component_ref' -Target 'pages/index/index.json' -Expected 'food-item'),
        (New-WechatTaskAcceptanceCheck -Type 'component_ref' -Target 'pages/index/index.json' -Expected 'cart-summary')
    )
    $routingConfig = @{
        multi_page_mode = $false
        routing_targets = @()
    }

    if ([string]$Recipe.route_mode -eq 'food-order-flow') {
        $targetPages += ,(New-WechatTaskTarget -Path 'pages/checkout/index' -BundleKind 'page')
        $acceptanceChecks += ,(New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/checkout/index.wxml' -Expected $Recipe.checkout_title)
        $acceptanceChecks += ,(New-WechatTaskAcceptanceCheck -Type 'route_link' -Target 'pages/index/index.wxml' -Expected '/pages/checkout/index')
        $routingConfig = @{
            multi_page_mode = $true
            routing_targets = @(
                @{
                    from = 'pages/index/index'
                    to = 'pages/checkout/index'
                    label = $Recipe.checkout_nav_label
                }
            )
        }
    }

    return (New-WechatTaskSpec `
        -TaskIntent 'generated-product' `
        -TaskFamily 'food-order' `
        -RouteMode ([string]$Recipe.route_mode) `
        -Goal $Goal `
        -TargetPages $targetPages `
        -RequiredComponents @(
            (New-WechatTaskTarget -Path 'components/food-item/index' -BundleKind 'component'),
            (New-WechatTaskTarget -Path 'components/cart-summary/index' -BundleKind 'component')
        ) `
        -AppPatch @{
            navigationBarTitleText = $Recipe.app_title
            projectname = $Recipe.project_name
        } `
        -AcceptanceChecks $acceptanceChecks `
        -RepairStrategy $repairStrategy `
        -RoutingConfig $routingConfig)
}

function Invoke-WechatTaskTranslator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $text = $TaskText.Trim()
    $normalized = $text.ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return [pscustomobject]@{
            status = 'no_match'
            source = 'translator'
            reason = 'empty_input'
            task_spec = $null
        }
    }

    function New-WechatSuccessfulTranslationResult {
        param(
            [Parameter(Mandatory)][string]$Reason,
            [Parameter(Mandatory)]$TaskSpec
        )

        $compiled = Invoke-TaskSpecToBundle -TaskSpec $TaskSpec
        return [pscustomobject]@{
            status = 'success'
            source = 'translator'
            reason = $Reason
            task_spec = $TaskSpec
            page_bundle = $compiled.page_bundle
            component_bundle = $compiled.component_bundle
            component_bundles = $compiled.component_bundles
            app_patch = $compiled.app_patch
        }
    }

    $marketingRecipe = Resolve-WechatMarketingEmptyStateRecipe -TaskText $text
    if ($null -ne $marketingRecipe) {
        return New-WechatSuccessfulTranslationResult `
            -Reason 'recipe_bridge_marketing' `
            -TaskSpec (New-WechatTaskSpecFromMarketingRecipe -Recipe $marketingRecipe -Goal $text)
    }

    $productRecipe = Resolve-WechatProductListingRecipe -TaskText $text
    if ($null -ne $productRecipe) {
        return New-WechatSuccessfulTranslationResult `
            -Reason 'recipe_bridge_product' `
            -TaskSpec (New-WechatTaskSpecFromProductRecipe -Recipe $productRecipe -Goal $text)
    }

    $productDetailRecipe = Resolve-WechatProductDetailRecipe -TaskText $text
    if ($null -ne $productDetailRecipe) {
        return New-WechatSuccessfulTranslationResult `
            -Reason 'recipe_bridge_product_detail' `
            -TaskSpec (New-WechatTaskSpecFromProductRecipe -Recipe $productDetailRecipe -Goal $text)
    }

    $foodOrderRecipe = Resolve-WechatFoodOrderRecipe -TaskText $text
    if ($null -ne $foodOrderRecipe) {
        return New-WechatSuccessfulTranslationResult `
            -Reason 'recipe_bridge_food_order' `
            -TaskSpec (New-WechatTaskSpecFromFoodOrderRecipe -Recipe $foodOrderRecipe -Goal $text)
    }

    $productHint = $normalized -match 'product|goods|catalog|catalogue|shop|store|menu|item'
    $listingHint = $normalized -match 'list|listing|cards|price|browse|showcase|grid'
    if ($productHint -and $listingHint) {
        $recipe = Resolve-WechatProductListingRecipe -TaskText 'build a product listing mini program page with featured goods cards, prices, and a clean mobile-first catalog layout'
        return New-WechatSuccessfulTranslationResult `
            -Reason 'translator_product_listing' `
            -TaskSpec (New-WechatTaskSpecFromProductRecipe -Recipe $recipe -Goal $text)
    }

    $detailHint = $normalized -match 'product detail|detail page|view detail|details'
    if ($productHint -and $detailHint) {
        $recipe = Resolve-WechatProductDetailRecipe -TaskText 'build a product detail mini program page with product image, title, description, price, and an add to cart CTA'
        return New-WechatSuccessfulTranslationResult `
            -Reason 'translator_product_detail' `
            -TaskSpec (New-WechatTaskSpecFromProductRecipe -Recipe $recipe -Goal $text)
    }

    $foodOrderHint = ($normalized -match 'food-order|food order|menu|takeout|delivery') -or ($text -match '点餐|外卖|菜单')
    if ($foodOrderHint) {
        $recipe = Resolve-WechatFoodOrderRecipe -TaskText 'build a food ordering mini program with a menu list, prices, and a floating cart summary'
        return New-WechatSuccessfulTranslationResult `
            -Reason 'translator_food_order' `
            -TaskSpec (New-WechatTaskSpecFromFoodOrderRecipe -Recipe $recipe -Goal $text)
    }

    $couponHint = $normalized -match 'coupon|coupon center|claim coupon'
    if ($couponHint) {
        $recipe = New-WechatMarketingEmptyStateRecipe -Variant 'coupon-empty-state'
        return New-WechatSuccessfulTranslationResult `
            -Reason 'translator_coupon_empty_state' `
            -TaskSpec (New-WechatTaskSpecFromMarketingRecipe -Recipe $recipe -Goal $text)
    }

    $activityHint = $normalized -match 'activity|campaign|event|not started|coming soon|upcoming'
    if ($activityHint) {
        $recipe = New-WechatMarketingEmptyStateRecipe -Variant 'activity-not-started'
        return New-WechatSuccessfulTranslationResult `
            -Reason 'translator_activity_not_started' `
            -TaskSpec (New-WechatTaskSpecFromMarketingRecipe -Recipe $recipe -Goal $text)
    }

    $benefitsHint = $normalized -match 'benefits|privilege|privileges|perks|member perks'
    if ($benefitsHint) {
        $recipe = New-WechatMarketingEmptyStateRecipe -Variant 'benefits-empty-state'
        return New-WechatSuccessfulTranslationResult `
            -Reason 'translator_benefits_empty_state' `
            -TaskSpec (New-WechatTaskSpecFromMarketingRecipe -Recipe $recipe -Goal $text)
    }

    return [pscustomobject]@{
        status = 'no_match'
        source = 'translator'
        reason = 'no_translator_match'
        task_spec = $null
    }
}
