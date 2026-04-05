[CmdletBinding()]
param()

function Get-WechatAcceptanceFileContent {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $normalized = $RelativePath.Trim().Trim('/') -replace '/', '\'
    $fullPath = Join-Path $ProjectDir $normalized
    if (-not (Test-Path $fullPath)) {
        return $null
    }

    return [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
}

function Add-WechatAcceptanceMiss {
    param(
        [System.Collections.Generic.List[object]]$MissedChecks,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Target,
        [string]$Expected = '',
        [string]$Reason = ''
    )

    $entry = [ordered]@{
        code = $Code
        target = $Target
    }

    if (-not [string]::IsNullOrWhiteSpace($Expected)) {
        $entry.expected = $Expected
    }
    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        $entry.reason = $Reason
    }

    $MissedChecks.Add([pscustomobject]$entry)
}

function Test-WechatAcceptanceExpectedText {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)]$Check,
        [System.Collections.Generic.List[object]]$MissedChecks
    )

    $content = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath ([string]$Check.target)
    if ($null -eq $content) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target ([string]$Check.target) -Expected ([string]$Check.expected) -Reason 'target_file_not_found'
        return
    }

    $expected = [string]$Check.expected
    if ([string]::IsNullOrWhiteSpace($expected)) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'invalid_acceptance_rule' -Target ([string]$Check.target) -Reason 'expected_text_missing'
        return
    }

    if (-not $content.Contains($expected)) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_expected_text' -Target ([string]$Check.target) -Expected $expected -Reason 'text_not_found'
    }
}

function Test-WechatAcceptanceComponentRef {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)]$Check,
        [System.Collections.Generic.List[object]]$MissedChecks
    )

    $content = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath ([string]$Check.target)
    if ($null -eq $content) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target ([string]$Check.target) -Expected ([string]$Check.expected) -Reason 'target_file_not_found'
        return
    }

    $expected = [string]$Check.expected
    if ([string]::IsNullOrWhiteSpace($expected)) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'invalid_acceptance_rule' -Target ([string]$Check.target) -Reason 'expected_component_missing'
        return
    }

    if (-not ($content.Contains("""$expected""") -or $content.Contains("'$expected'") -or $content.Contains($expected))) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_component_ref' -Target ([string]$Check.target) -Expected $expected -Reason 'component_reference_not_found'
    }
}

function Test-WechatAcceptanceRouteLink {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)]$Check,
        [System.Collections.Generic.List[object]]$MissedChecks
    )

    $content = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath ([string]$Check.target)
    if ($null -eq $content) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target ([string]$Check.target) -Expected ([string]$Check.expected) -Reason 'target_file_not_found'
        return
    }

    $expected = [string]$Check.expected
    if ([string]::IsNullOrWhiteSpace($expected)) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'invalid_acceptance_rule' -Target ([string]$Check.target) -Reason 'expected_route_missing'
        return
    }

    if (-not ($content.Contains($expected) -or $content.Contains('<navigator'))) {
        Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_checkout_navigator' -Target ([string]$Check.target) -Expected $expected -Reason 'route_link_not_found'
    }
}

function Invoke-WechatFamilyAcceptanceChecks {
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)][string]$ProjectDir,
        [System.Collections.Generic.List[object]]$MissedChecks
    )

    switch ([string]$TaskSpec.route_mode) {
        'coupon-empty-state' {
            $pageWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'pages/index/index.wxml'
            if ($null -eq $pageWxml) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target 'pages/index/index.wxml' -Reason 'target_file_not_found'
                return
            }

            if (-not ($pageWxml.Contains('<cta-button') -or $pageWxml.Contains('<button'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_cta_button' -Target 'pages/index/index.wxml' -Reason 'cta_button_not_found'
            }
            if (-not ($pageWxml.Contains('rules-card') -or $pageWxml.Contains('Coupon rules'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_rules_section' -Target 'pages/index/index.wxml' -Reason 'rules_section_not_found'
            }
        }
        'activity-not-started' {
            $pageWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'pages/index/index.wxml'
            if ($null -eq $pageWxml) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target 'pages/index/index.wxml' -Reason 'target_file_not_found'
                return
            }

            if (-not ($pageWxml.Contains('Campaign Center') -or $pageWxml.Contains('event has not started'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_activity_title' -Target 'pages/index/index.wxml' -Reason 'activity_title_not_found'
            }
            if (-not ($pageWxml.Contains('countdown') -or $pageWxml.Contains('Campaign starts in') -or $pageWxml.Contains('02:15:00'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_countdown_placeholder' -Target 'pages/index/index.wxml' -Reason 'countdown_not_found'
            }
            if (-not ($pageWxml.Contains('Notify Me') -or $pageWxml.Contains('<cta-button'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_notify_cta' -Target 'pages/index/index.wxml' -Reason 'notify_cta_not_found'
            }
        }
        'benefits-empty-state' {
            $pageWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'pages/index/index.wxml'
            if ($null -eq $pageWxml) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target 'pages/index/index.wxml' -Reason 'target_file_not_found'
                return
            }

            if (-not ($pageWxml.Contains('Benefits Center') -or $pageWxml.Contains('No benefits unlocked'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_benefits_title' -Target 'pages/index/index.wxml' -Reason 'benefits_title_not_found'
            }
            if (-not ($pageWxml.Contains('benefits-list') -or $pageWxml.Contains('benefit-item') -or $pageWxml.Contains('Benefits preview'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_benefits_list' -Target 'pages/index/index.wxml' -Reason 'benefits_list_not_found'
            }
            if (-not ($pageWxml.Contains('Unlock Benefits') -or $pageWxml.Contains('<cta-button'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_benefits_cta' -Target 'pages/index/index.wxml' -Reason 'benefits_cta_not_found'
            }
        }
        'product-listing' {
            $pageWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'pages/index/index.wxml'
            $componentWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'components/product-card/index.wxml'
            if ($null -eq $pageWxml) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target 'pages/index/index.wxml' -Reason 'target_file_not_found'
                return
            }

            if (-not ($pageWxml.Contains('product-list') -or $pageWxml.Contains('<scroll-view') -or $pageWxml.Contains('<product-card'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_product_list_container' -Target 'pages/index/index.wxml' -Reason 'product_list_container_not_found'
            }
            if (($null -eq $componentWxml) -or (-not ($componentWxml.Contains('price') -or $componentWxml.Contains('{{price}}')))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_price_display' -Target 'components/product-card/index.wxml' -Reason 'price_display_not_found'
            }
        }
        'product-detail' {
            $pageWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'pages/index/index.wxml'
            if ($null -eq $pageWxml) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target 'pages/index/index.wxml' -Reason 'target_file_not_found'
                return
            }

            if (-not $pageWxml.Contains('<image')) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_detail_image' -Target 'pages/index/index.wxml' -Reason 'detail_image_not_found'
            }
            if (-not ($pageWxml.Contains('product-title') -or $pageWxml.Contains('Signature Braised Platter'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_detail_title' -Target 'pages/index/index.wxml' -Reason 'detail_title_not_found'
            }
            if (-not $pageWxml.Contains('price')) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_price_display' -Target 'pages/index/index.wxml' -Reason 'detail_price_not_found'
            }
            if (-not ($pageWxml.Contains('Add to Cart') -or $pageWxml.Contains('<buy-button'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_add_to_cart_cta' -Target 'pages/index/index.wxml' -Reason 'detail_cta_not_found'
            }
        }
        'food-order' {
            $pageWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'pages/index/index.wxml'
            $appJson = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'app.json'
            $foodItemWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'components/food-item/index.wxml'
            $cartSummaryWxml = Get-WechatAcceptanceFileContent -ProjectDir $ProjectDir -RelativePath 'components/cart-summary/index.wxml'
            if ($null -eq $pageWxml) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_target_file' -Target 'pages/index/index.wxml' -Reason 'target_file_not_found'
                return
            }

            if (-not ($pageWxml.Contains('menu-list') -or $pageWxml.Contains('<food-item'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_food_list' -Target 'pages/index/index.wxml' -Reason 'food_list_not_found'
            }
            if (($null -eq $foodItemWxml) -or (-not ($foodItemWxml.Contains('price') -and ($foodItemWxml.Contains('{{price}}') -or $foodItemWxml.Contains('${{price}}'))))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_price_display' -Target 'components/food-item/index.wxml' -Reason 'food_price_not_found'
            }
            if (($null -eq $foodItemWxml) -or (-not $foodItemWxml.Contains('quantity-controls'))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_quantity_controls' -Target 'components/food-item/index.wxml' -Reason 'quantity_controls_not_found'
            }
            if (($null -eq $cartSummaryWxml) -or (-not ($cartSummaryWxml.Contains('Cart Summary') -or $pageWxml.Contains('<cart-summary')))) {
                Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_cart_summary' -Target 'components/cart-summary/index.wxml' -Reason 'cart_summary_not_found'
            }
            if ([string]$TaskSpec.route_mode -eq 'food-order-flow') {
                if (-not ($pageWxml.Contains('/pages/checkout/index') -or $pageWxml.Contains('<navigator'))) {
                    Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_checkout_navigator' -Target 'pages/index/index.wxml' -Expected '/pages/checkout/index' -Reason 'checkout_navigator_not_found'
                }
                if (($null -eq $appJson) -or (-not ($appJson.Contains('pages/index/index') -and $appJson.Contains('pages/checkout/index')))) {
                    Add-WechatAcceptanceMiss -MissedChecks $MissedChecks -Code 'missing_checkout_route' -Target 'app.json' -Expected 'pages/checkout/index' -Reason 'checkout_route_not_registered'
                }
            }
        }
    }
}

function Invoke-AcceptanceChecks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    Test-WechatTaskSpec -TaskSpec $TaskSpec | Out-Null

    $missedChecks = New-Object 'System.Collections.Generic.List[object]'
    foreach ($check in @($TaskSpec.acceptance_checks)) {
        switch ([string]$check.type) {
            'page_text' {
                Test-WechatAcceptanceExpectedText -ProjectDir $ProjectDir -Check $check -MissedChecks $missedChecks
            }
            'component_ref' {
                Test-WechatAcceptanceComponentRef -ProjectDir $ProjectDir -Check $check -MissedChecks $missedChecks
            }
            'route_link' {
                Test-WechatAcceptanceRouteLink -ProjectDir $ProjectDir -Check $check -MissedChecks $missedChecks
            }
            default {
                Add-WechatAcceptanceMiss -MissedChecks $missedChecks -Code 'unsupported_acceptance_rule' -Target ([string]$check.target) -Expected ([string]$check.expected) -Reason ([string]$check.type)
            }
        }
    }

    Invoke-WechatFamilyAcceptanceChecks -TaskSpec $TaskSpec -ProjectDir $ProjectDir -MissedChecks $missedChecks

    $status = if ($missedChecks.Count -eq 0) { 'pass' } else { 'retry' }
    $missedChecksArray = $missedChecks.ToArray()
    return [pscustomobject]@{
        status = $status
        route_mode = [string]$TaskSpec.route_mode
        task_family = [string]$TaskSpec.task_family
        missed_checks = $missedChecksArray
        checked_count = @($TaskSpec.acceptance_checks).Count
    }
}
