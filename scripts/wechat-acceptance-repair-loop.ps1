[CmdletBinding()]
param()

if (-not (Get-Command Test-WechatTaskSpec -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-task-spec.ps1"
}

if (-not (Get-Command Invoke-AcceptanceChecks -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-acceptance-checks.ps1"
}

function Get-WechatTaskTargetRelativeBasePath {
    param(
        [Parameter(Mandatory)]$Target
    )

    return ([string]$Target.path).Trim().Trim('/') -replace '/', '\'
}

function Get-WechatTaskBundleFileContentFromDisk {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $fullPath = Join-Path $ProjectDir ($RelativePath -replace '/', '\')
    if (-not (Test-Path $fullPath)) {
        return ''
    }

    return [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
}

function New-WechatTaskPageBundleFromDisk {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)]$TaskSpec
    )

    $targets = @($TaskSpec.target_pages)
    $target = $targets[0]
    $pageName = Split-Path (Get-WechatTaskTargetRelativeBasePath -Target $target) -Leaf
    $files = @()
    foreach ($pageTarget in $targets) {
        $basePath = Get-WechatTaskTargetRelativeBasePath -Target $pageTarget
        $normalizedBase = $basePath -replace '\\', '/'
        $files += @(
            [ordered]@{ path = "$normalizedBase.wxml"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.wxml") }
            [ordered]@{ path = "$normalizedBase.js"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.js") }
            [ordered]@{ path = "$normalizedBase.wxss"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.wxss") }
            [ordered]@{ path = "$normalizedBase.json"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.json") }
        )
    }

    return [ordered]@{
        page_name = $pageName
        files = $files
    }
}

function New-WechatTaskComponentBundleFromDisk {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)]$TaskSpec
    )

    $target = @($TaskSpec.required_components)[0]
    $basePath = Get-WechatTaskTargetRelativeBasePath -Target $target
    $componentName = Split-Path (Split-Path $basePath -Parent) -Leaf
    $normalizedBase = $basePath -replace '\\', '/'

    return [ordered]@{
        component_name = $componentName
        files = @(
            [ordered]@{ path = "$normalizedBase.wxml"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.wxml") }
            [ordered]@{ path = "$normalizedBase.js"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.js") }
            [ordered]@{ path = "$normalizedBase.wxss"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.wxss") }
            [ordered]@{ path = "$normalizedBase.json"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.json") }
        )
    }
}

function New-WechatTaskComponentBundlesFromDisk {
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)]$TaskSpec
    )

    $bundles = @()
    foreach ($target in @($TaskSpec.required_components)) {
        $basePath = Get-WechatTaskTargetRelativeBasePath -Target $target
        $componentName = Split-Path (Split-Path $basePath -Parent) -Leaf
        $normalizedBase = $basePath -replace '\\', '/'
        $bundles += ,([ordered]@{
            component_name = $componentName
            files = @(
                [ordered]@{ path = "$normalizedBase.wxml"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.wxml") }
                [ordered]@{ path = "$normalizedBase.js"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.js") }
                [ordered]@{ path = "$normalizedBase.wxss"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.wxss") }
                [ordered]@{ path = "$normalizedBase.json"; content = (Get-WechatTaskBundleFileContentFromDisk -ProjectDir $ProjectDir -RelativePath "$basePath.json") }
            )
        })
    }
    return @($bundles)
}

function Get-WechatBundleFileEntry {
    param(
        [Parameter(Mandatory)]$Bundle,
        [Parameter(Mandatory)][string]$Suffix
    )

    foreach ($file in @($Bundle.files)) {
        if ([string]$file.path -like "*$Suffix") {
            return $file
        }
    }

    throw "Bundle file entry not found for suffix $Suffix"
}

function Add-WechatMissingMarkupBeforeAnchor {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Anchor,
        [Parameter(Mandatory)][string]$Markup
    )

    if ($Content.Contains($Markup)) {
        return $Content
    }

    if ($Content.Contains($Anchor)) {
        return $Content.Replace($Anchor, "$Markup`n  $Anchor")
    }

    return "$Content`n$Markup"
}

function Add-WechatAcceptanceExpectedTextRepair {
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)]$Miss,
        [Parameter(Mandatory)]$PageBundle
    )

    $wxmlEntry = Get-WechatBundleFileEntry -Bundle $PageBundle -Suffix '.wxml'
    $expected = [string]$Miss.expected
    if ([string]::IsNullOrWhiteSpace($expected) -or $wxmlEntry.content.Contains($expected)) {
        return $false
    }

    switch ([string]$TaskSpec.route_mode) {
        'coupon-empty-state' {
            if ($expected -like '*Claim*' -or $expected -like '*领取*') {
                $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup "    <cta-button text='$expected'></cta-button>"
                return $true
            }
            if ($expected -like '*Rules*' -or $expected -like '*规则*') {
                $markup = @"
  <view class='rules-card'>
    <text class='rules-title'>$expected</text>
  </view>
"@
                $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup $markup
                return $true
            }
        }
        default {
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup "  <text class='acceptance-copy'>$expected</text>"
            return $true
        }
    }

    return $false
}

function Repair-WechatMarketingAcceptanceMiss {
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)]$Miss,
        [Parameter(Mandatory)]$PageBundle
    )

    $wxmlEntry = Get-WechatBundleFileEntry -Bundle $PageBundle -Suffix '.wxml'
    $jsonEntry = Get-WechatBundleFileEntry -Bundle $PageBundle -Suffix '.json'

    switch ([string]$Miss.code) {
        'missing_cta_button' {
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor "<view class='rules-card'>" -Markup "    <cta-button text='Claim Coupon'></cta-button>"
            return $true
        }
        'missing_rules_section' {
            $markup = @"
  <view class='rules-card'>
    <text class='rules-title'>Coupon rules</text>
    <text class='rules-item'>Each account can claim one welcome coupon per day.</text>
  </view>
"@
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup $markup
            return $true
        }
        'missing_component_ref' {
            $title = switch ([string]$TaskSpec.route_mode) {
                'activity-not-started' { 'Campaign Center' }
                'benefits-empty-state' { 'Benefits Center' }
                default { 'Coupon Center' }
            }
            $jsonEntry.content = "{`n  `"navigationBarTitleText`": `"$title`",`n  `"usingComponents`": {`n    `"cta-button`": `"/components/cta-button/index`"`n  }`n}"
            return $true
        }
        'missing_expected_text' {
            return Add-WechatAcceptanceExpectedTextRepair -TaskSpec $TaskSpec -Miss $Miss -PageBundle $PageBundle
        }
        'missing_activity_title' {
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup "    <text class='title'>Campaign Center</text>"
            return $true
        }
        'missing_countdown_placeholder' {
            $markup = @"
  <view class='countdown-box'>
    <text class='countdown-label'>Campaign starts in</text>
    <text class='countdown-value'>02:15:00</text>
  </view>
"@
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor "<cta-button" -Markup $markup
            return $true
        }
        'missing_notify_cta' {
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup "    <cta-button text='Notify Me'></cta-button>"
            return $true
        }
        'missing_benefits_title' {
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup "    <text class='title'>Benefits Center</text>"
            return $true
        }
        'missing_benefits_list' {
            $markup = @"
  <view class='benefits-list'>
    <text class='benefits-title'>Benefits preview</text>
    <text class='benefit-item'>Member-only delivery voucher</text>
    <text class='benefit-item'>Exclusive weekly tasting perk</text>
  </view>
"@
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor "<view class='rules-card'>" -Markup $markup
            return $true
        }
        'missing_benefits_cta' {
            $wxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $wxmlEntry.content -Anchor '</view>' -Markup "    <cta-button text='Unlock Benefits'></cta-button>"
            return $true
        }
    }

    return $false
}

function Repair-WechatProductAcceptanceMiss {
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)]$Miss,
        [Parameter(Mandatory)]$PageBundle,
        [Parameter(Mandatory)]$ComponentBundle
    )

    $pageWxmlEntry = Get-WechatBundleFileEntry -Bundle $PageBundle -Suffix '.wxml'
    $pageJsonEntry = Get-WechatBundleFileEntry -Bundle $PageBundle -Suffix '.json'
    $componentWxmlEntry = Get-WechatBundleFileEntry -Bundle $ComponentBundle -Suffix '.wxml'

    switch ([string]$Miss.code) {
        'missing_product_list_container' {
            $markup = @"
  <view class='product-list'>
    <product-card badge='Featured' title='Sample Product' summary='Restored by acceptance repair.' price='36'></product-card>
  </view>
"@
            $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor "<view class='footer-note'>" -Markup $markup
            return $true
        }
        'missing_price_display' {
            if ([string]$TaskSpec.route_mode -eq 'product-detail') {
                $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor "<text class='benefits-copy'>" -Markup "    <text class='price'>¥58</text>"
            } else {
                $componentWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $componentWxmlEntry.content -Anchor '</view>' -Markup "  <text class='price'>¥{{price}}</text>"
            }
            return $true
        }
        'missing_component_ref' {
            if ([string]$TaskSpec.route_mode -eq 'product-detail') {
                $pageJsonEntry.content = "{`n  `"navigationBarTitleText`": `"Product Detail`",`n  `"usingComponents`": {`n    `"buy-button`": `"/components/buy-button/index`"`n  }`n}"
            } else {
                $pageJsonEntry.content = "{`n  `"navigationBarTitleText`": `"Product Center`",`n  `"usingComponents`": {`n    `"product-card`": `"/components/product-card/index`"`n  }`n}"
            }
            return $true
        }
        'missing_expected_text' {
            return Add-WechatAcceptanceExpectedTextRepair -TaskSpec $TaskSpec -Miss $Miss -PageBundle $PageBundle
        }
        'missing_detail_image' {
            $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor "<view class='detail-card'>" -Markup "  <image class='product-image' src='https://dummyimage.com/720x480/f7e7d7/8b4513.png&text=Product+Image' mode='aspectFill' />"
            return $true
        }
        'missing_detail_title' {
            $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor "<text class='product-description'>" -Markup "    <text class='product-title'>Signature Braised Platter</text>"
            return $true
        }
        'missing_add_to_cart_cta' {
            $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor '</view>' -Markup "    <buy-button text='Add to Cart'></buy-button>"
            return $true
        }
    }

    return $false
}

function Repair-WechatFoodOrderAcceptanceMiss {
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)]$Miss,
        [Parameter(Mandatory)]$PageBundle,
        [Parameter(Mandatory)]$ComponentBundles
    )

    $pageWxmlEntry = @($PageBundle.files | Where-Object { [string]$_.path -eq 'pages/index/index.wxml' })[0]
    $pageJsonEntry = @($PageBundle.files | Where-Object { [string]$_.path -eq 'pages/index/index.json' })[0]
    $checkoutWxmlEntry = @($PageBundle.files | Where-Object { [string]$_.path -eq 'pages/checkout/index.wxml' })[0]
    $foodItemBundle = @($ComponentBundles | Where-Object { [string]$_.component_name -eq 'food-item' })[0]
    $cartSummaryBundle = @($ComponentBundles | Where-Object { [string]$_.component_name -eq 'cart-summary' })[0]
    $foodItemWxmlEntry = if ($null -ne $foodItemBundle) { Get-WechatBundleFileEntry -Bundle $foodItemBundle -Suffix '.wxml' } else { $null }
    $cartSummaryWxmlEntry = if ($null -ne $cartSummaryBundle) { Get-WechatBundleFileEntry -Bundle $cartSummaryBundle -Suffix '.wxml' } else { $null }

    switch ([string]$Miss.code) {
        'missing_food_list' {
            $markup = @"
  <view class='menu-list'>
    <food-item image='https://dummyimage.com/240x240/f3e1d2/8c4a1f.png&text=Dish' name='Braised Pork Rice' description='Signature rice bowl with slow-cooked pork and pickles.' price='18' count='1'></food-item>
  </view>
"@
            $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor "<view class='cart-floating'>" -Markup $markup
            return $true
        }
        'missing_price_display' {
            if ($null -ne $foodItemWxmlEntry) {
                $foodItemWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $foodItemWxmlEntry.content -Anchor "<view class='quantity-controls'>" -Markup "      <text class='price'>`${{price}}</text>"
                return $true
            }
        }
        'missing_quantity_controls' {
            if ($null -ne $foodItemWxmlEntry) {
                $markup = @"
      <view class='quantity-controls'>
        <button class='qty-btn' size='mini'>-</button>
        <text class='qty-value'>{{count}}</text>
        <button class='qty-btn' size='mini'>+</button>
      </view>
"@
                $foodItemWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $foodItemWxmlEntry.content -Anchor "</view>" -Markup $markup
                return $true
            }
        }
        'missing_cart_summary' {
            if ($null -ne $cartSummaryWxmlEntry) {
                $cartSummaryWxmlEntry.content = @"
<view class='cart-summary'>
  <view class='cart-copy'>
    <text class='cart-title'>Cart Summary</text>
    <text class='cart-meta'>{{count}} items | `${{total}}</text>
  </view>
  <button class='cart-btn'>Checkout</button>
</view>
"@
                return $true
            }
            $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor '</view>' -Markup "  <view class='cart-floating'><cart-summary total='30' count='3'></cart-summary></view>"
            return $true
        }
        'missing_component_ref' {
            $pageJsonEntry.content = "{`n  `"navigationBarTitleText`": `"Food Order`",`n  `"usingComponents`": {`n    `"food-item`": `"/components/food-item/index`",`n    `"cart-summary`": `"/components/cart-summary/index`"`n  }`n}"
            return $true
        }
        'missing_checkout_navigator' {
            $pageWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $pageWxmlEntry.content -Anchor "<view class='cart-floating'>" -Markup "  <navigator class='checkout-link' url='/pages/checkout/index'>Review Cart & Checkout</navigator>"
            return $true
        }
        'missing_checkout_route' {
            if ($null -ne $checkoutWxmlEntry -and -not $checkoutWxmlEntry.content.Contains('Checkout Summary')) {
                $checkoutWxmlEntry.content = Add-WechatMissingMarkupBeforeAnchor -Content $checkoutWxmlEntry.content -Anchor "</view>" -Markup "  <text class='title'>Checkout Summary</text>"
            }
            return $false
        }
        'missing_expected_text' {
            return Add-WechatAcceptanceExpectedTextRepair -TaskSpec $TaskSpec -Miss $Miss -PageBundle $PageBundle
        }
    }

    return $false
}

function ConvertTo-WechatBoundaryPlainValue {
    param(
        [Parameter(Mandatory)]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string] -or $Value -is [char] -or $Value -is [bool] -or
        $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
        $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $normalized = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $entry = $Value[$key]
            if ($entry -is [System.Collections.IEnumerable] -and -not ($entry -is [string])) {
                $items = New-Object System.Collections.ArrayList
                foreach ($item in $entry) {
                    [void]$items.Add((ConvertTo-WechatBoundaryPlainValue -Value $item))
                }
                $normalized[[string]$key] = $items
            }
            else {
                $normalized[[string]$key] = ConvertTo-WechatBoundaryPlainValue -Value $entry
            }
        }
        return $normalized
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $normalized = New-Object System.Collections.ArrayList
        foreach ($item in $Value) {
            [void]$normalized.Add((ConvertTo-WechatBoundaryPlainValue -Value ([object]$item)))
        }
        return $normalized
    }

    $properties = $Value.PSObject.Properties | Where-Object { $_.MemberType -in @('NoteProperty', 'Property', 'AliasProperty', 'ScriptProperty') }
    if ($properties.Count -gt 0) {
        $normalized = [ordered]@{}
        foreach ($property in $properties) {
            $entry = $property.Value
            if ($entry -is [System.Collections.IEnumerable] -and -not ($entry -is [string])) {
                $items = New-Object System.Collections.ArrayList
                foreach ($item in $entry) {
                    [void]$items.Add((ConvertTo-WechatBoundaryPlainValue -Value $item))
                }
                $normalized[$property.Name] = $items
            }
            else {
                $normalized[$property.Name] = ConvertTo-WechatBoundaryPlainValue -Value $entry
            }
        }
        return $normalized
    }

    return [string]$Value
}

function ConvertTo-WechatBoundaryJson {
    param(
        [Parameter(Mandatory)]$Value
    )

    return ((ConvertTo-WechatBoundaryPlainValue -Value $Value) | ConvertTo-Json -Depth 100 -Compress)
}

function Split-WechatPageBundleByRoot {
    param(
        [Parameter(Mandatory)]$PageBundle
    )

    $groups = [ordered]@{}
    foreach ($file in @($PageBundle.files)) {
        $normalizedPath = ([string]$file.path).Trim().Trim('/') -replace '\\', '/'
        if ($normalizedPath -notmatch '^(pages/[^/]+/[^/.]+)\.(wxml|js|wxss|json)$') {
            throw "Unsupported page bundle path for acceptance repair split: $normalizedPath"
        }

        $basePath = $Matches[1]
        if (-not $groups.Contains($basePath)) {
            $groups[$basePath] = New-Object System.Collections.ArrayList
        }
        [void]$groups[$basePath].Add($file)
    }

    $splitBundles = New-Object System.Collections.ArrayList
    foreach ($basePath in @($groups.Keys)) {
        $segments = $basePath -split '/'
        $pageName = if ($segments.Count -ge 2) { [string]$segments[1] } else { Split-Path $basePath -Leaf }
        [void]$splitBundles.Add([ordered]@{
            page_name = $pageName
            files = @($groups[$basePath])
        })
    }

    return @($splitBundles)
}

function Get-WechatBoundaryApplyScriptPath {
    param(
        [Parameter(Mandatory)][string]$Operation
    )

    switch ($Operation) {
        'apply_page_bundle' { return (Join-Path $PSScriptRoot 'wechat-apply-bundle.ps1') }
        'apply_component_bundle' { return (Join-Path $PSScriptRoot 'wechat-apply-component-bundle.ps1') }
        'apply_app_json_patch' { return (Join-Path $PSScriptRoot 'wechat-apply-app-json-patch.ps1') }
        default { return $null }
    }
}

function Invoke-WechatDirectApplyFallback {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)]$Payload,
        [Parameter(Mandatory)][string]$TargetWorkspace
    )

    $scriptPath = Get-WechatBoundaryApplyScriptPath -Operation $Operation
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        return $null
    }

    $tempPayloadPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wechat-acceptance-apply-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $json = ConvertTo-WechatBoundaryJson -Value $Payload
        [System.IO.File]::WriteAllText($tempPayloadPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        $combined = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -JsonFilePath $tempPayloadPath -TargetWorkspace $TargetWorkspace 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{
            interface_version = 'mcp_tool_boundary_v1'
            operation = $Operation
            status = if ($exitCode -eq 0) { 'success' } else { 'failed' }
            exit_code = $exitCode
            gate_status = switch ($exitCode) {
                0 { 'pass' }
                1 { 'retryable_fail' }
                2 { 'hard_fail' }
                default { 'unknown' }
            }
            stdout = [string]$combined
            stderr = ''
        }
    }
    finally {
        if (Test-Path $tempPayloadPath) {
            Remove-Item -LiteralPath $tempPayloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-WechatBoundaryOperationWithJsonPayload {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)]$Payload,
        [Parameter(Mandatory)][string]$TargetWorkspace
    )

    $boundaryScript = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
    $tempPayloadPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wechat-acceptance-boundary-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $json = ConvertTo-WechatBoundaryJson -Value $Payload
        [System.IO.File]::WriteAllText($tempPayloadPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        $result = (& $boundaryScript -Operation $Operation -JsonFilePath $tempPayloadPath -TargetWorkspace $TargetWorkspace | ConvertFrom-Json)
        if ($Operation -like 'apply_*' -and
            [string]$result.status -eq 'failed' -and
            [string]$result.gate_status -eq 'retryable_fail' -and
            ([string]$result.stdout) -match 'Thread failed to start') {
            $fallback = Invoke-WechatDirectApplyFallback -Operation $Operation -Payload $Payload -TargetWorkspace $TargetWorkspace
            if ($null -ne $fallback) {
                return $fallback
            }
        }
        return $result
    }
    finally {
        if (Test-Path $tempPayloadPath) {
            Remove-Item -LiteralPath $tempPayloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-AcceptanceRepairLoop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)][string]$ProjectDir,
        [Parameter(Mandatory)]$Acceptance,
        [int]$MaxRounds = 0
    )

    Test-WechatTaskSpec -TaskSpec $TaskSpec | Out-Null

    if (-not (Test-Path $ProjectDir)) {
        throw "Acceptance repair loop requires an existing project directory: $ProjectDir"
    }

    $effectiveMaxRounds = if ($MaxRounds -gt 0) { $MaxRounds } else { [int]$TaskSpec.repair_strategy.max_rounds }
    if ($effectiveMaxRounds -lt 1) {
        $effectiveMaxRounds = 3
    }

    $history = New-Object System.Collections.Generic.List[object]
    $currentAcceptance = $Acceptance

    for ($round = 1; $round -le $effectiveMaxRounds; $round++) {
        if ([string]$currentAcceptance.status -eq 'pass') {
            break
        }

        $missedChecks = @($currentAcceptance.missed_checks)
        $unsupported = @()
        $pageBundle = New-WechatTaskPageBundleFromDisk -ProjectDir $ProjectDir -TaskSpec $TaskSpec
        $componentBundle = New-WechatTaskComponentBundleFromDisk -ProjectDir $ProjectDir -TaskSpec $TaskSpec
        $componentBundles = New-WechatTaskComponentBundlesFromDisk -ProjectDir $ProjectDir -TaskSpec $TaskSpec
        $modifiedCodes = New-Object System.Collections.Generic.List[string]

        foreach ($miss in $missedChecks) {
            $code = [string]$miss.code
            if (@($TaskSpec.repair_strategy.supported_codes) -notcontains $code) {
                $unsupported += $code
                continue
            }

            $repaired = switch ([string]$TaskSpec.repair_strategy.family) {
                'marketing-empty-state' { Repair-WechatMarketingAcceptanceMiss -TaskSpec $TaskSpec -Miss $miss -PageBundle $pageBundle }
                'product-listing' { Repair-WechatProductAcceptanceMiss -TaskSpec $TaskSpec -Miss $miss -PageBundle $pageBundle -ComponentBundle $componentBundle }
                'product-detail' { Repair-WechatProductAcceptanceMiss -TaskSpec $TaskSpec -Miss $miss -PageBundle $pageBundle -ComponentBundle $componentBundle }
                'food-order' { Repair-WechatFoodOrderAcceptanceMiss -TaskSpec $TaskSpec -Miss $miss -PageBundle $pageBundle -ComponentBundles $componentBundles }
                default { $false }
            }

            if ($repaired) {
                $modifiedCodes.Add($code)
            } else {
                $unsupported += $code
            }
        }

        if ($modifiedCodes.Count -eq 0) {
            $history.Add([pscustomobject]@{
                round = $round
                status = 'repair_exhausted'
                missed_codes = @($missedChecks | ForEach-Object { [string]$_.code })
                unsupported_codes = @($unsupported)
            })
            return [pscustomobject]@{
                status = 'repair_exhausted'
                rounds = $round
                history = $history.ToArray()
                acceptance = $currentAcceptance
            }
        }

        $componentValidate = $null
        $componentApply = $null
        foreach ($bundle in @($componentBundles)) {
            $componentValidate = Invoke-WechatBoundaryOperationWithJsonPayload -Operation 'validate_component_bundle' -Payload $bundle -TargetWorkspace $ProjectDir
            if ([string]$componentValidate.gate_status -ne 'pass') {
                $history.Add([pscustomobject]@{
                    round = $round
                    status = 'repair_exhausted'
                    modified_codes = $modifiedCodes.ToArray()
                    failed_stage = 'validate_component_bundle'
                    gate_status = [string]$componentValidate.gate_status
                })
                return [pscustomobject]@{
                    status = 'repair_exhausted'
                    rounds = $round
                    history = $history.ToArray()
                    acceptance = $currentAcceptance
                    component_validate = $componentValidate
                }
            }

            $componentApply = Invoke-WechatBoundaryOperationWithJsonPayload -Operation 'apply_component_bundle' -Payload $bundle -TargetWorkspace $ProjectDir
            if ([string]$componentApply.status -ne 'success') {
                $history.Add([pscustomobject]@{
                    round = $round
                    status = 'repair_exhausted'
                    modified_codes = $modifiedCodes.ToArray()
                    failed_stage = 'apply_component_bundle'
                    gate_status = [string]$componentApply.gate_status
                })
                return [pscustomobject]@{
                    status = 'repair_exhausted'
                    rounds = $round
                    history = $history.ToArray()
                    acceptance = $currentAcceptance
                    component_validate = $componentValidate
                    component_apply = $componentApply
                }
            }
        }

        $pageValidateResults = @()
        $pageApplyResults = @()
        foreach ($pagePayload in @(Split-WechatPageBundleByRoot -PageBundle $pageBundle)) {
            $pageValidate = Invoke-WechatBoundaryOperationWithJsonPayload -Operation 'validate_page_bundle' -Payload $pagePayload -TargetWorkspace $ProjectDir
            $pageValidateResults += ,$pageValidate
            if ([string]$pageValidate.gate_status -ne 'pass') {
                $history.Add([pscustomobject]@{
                    round = $round
                    status = 'repair_exhausted'
                    modified_codes = $modifiedCodes.ToArray()
                    failed_stage = 'validate_page_bundle'
                    gate_status = [string]$pageValidate.gate_status
                })
                return [pscustomobject]@{
                    status = 'repair_exhausted'
                    rounds = $round
                    history = $history.ToArray()
                    acceptance = $currentAcceptance
                    component_validate = $componentValidate
                    component_apply = $componentApply
                    page_validate = $pageValidate
                    page_validations = @($pageValidateResults)
                }
            }

            $pageApply = Invoke-WechatBoundaryOperationWithJsonPayload -Operation 'apply_page_bundle' -Payload $pagePayload -TargetWorkspace $ProjectDir
            $pageApplyResults += ,$pageApply
            if ([string]$pageApply.status -ne 'success') {
                $history.Add([pscustomobject]@{
                    round = $round
                    status = 'repair_exhausted'
                    modified_codes = $modifiedCodes.ToArray()
                    failed_stage = 'apply_page_bundle'
                    gate_status = [string]$pageApply.gate_status
                })
                return [pscustomobject]@{
                    status = 'repair_exhausted'
                    rounds = $round
                    history = $history.ToArray()
                    acceptance = $currentAcceptance
                    component_validate = $componentValidate
                    component_apply = $componentApply
                    page_validate = $pageValidate
                    page_apply = $pageApply
                    page_validations = @($pageValidateResults)
                    page_applications = @($pageApplyResults)
                }
            }
        }

        $pageValidate = $pageValidateResults[0]
        $pageApply = $pageApplyResults[0]

        $currentAcceptance = Invoke-AcceptanceChecks -TaskSpec $TaskSpec -ProjectDir $ProjectDir
        $history.Add([pscustomobject]@{
            round = $round
            status = [string]$currentAcceptance.status
            modified_codes = $modifiedCodes.ToArray()
            remaining_missed_codes = @($currentAcceptance.missed_checks | ForEach-Object { [string]$_.code })
        })

        if ([string]$currentAcceptance.status -eq 'pass') {
            return [pscustomobject]@{
                status = 'pass'
                rounds = $round
                history = $history.ToArray()
                acceptance = $currentAcceptance
                component_validate = $componentValidate
                component_apply = $componentApply
                page_validate = $pageValidate
                page_apply = $pageApply
                page_validations = @($pageValidateResults)
                page_applications = @($pageApplyResults)
            }
        }
    }

    return [pscustomobject]@{
        status = 'repair_exhausted'
        rounds = $effectiveMaxRounds
        history = $history.ToArray()
        acceptance = $currentAcceptance
    }
}
