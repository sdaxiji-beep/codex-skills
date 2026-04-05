[CmdletBinding()]
param()

function Resolve-WechatTaskIntent {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $text = $TaskText.Trim()
    $normalized = $text.ToLowerInvariant()
    $repoRoot = Split-Path $PSScriptRoot -Parent

    $route = [ordered]@{
        input     = $TaskText
        intent    = 'unknown'
        mode      = 'none'
        task_family = $null
        task_spec = $null
        page_bundle = $null
        component_bundle = $null
        component_bundles = $null
        app_patch = $null
        translation_source = $null
        spec_path = $null
        safe      = $true
        requires_confirmation = $false
        reason    = 'no_route_matched'
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        $route.reason = 'empty_input'
        return [pscustomobject]$route
    }

    if ($normalized -match '\bhelp\b|\bcommands?\b') {
        $route.intent = 'help'
        $route.mode = 'help'
        $route.reason = 'matched_help_keywords'
        return [pscustomobject]$route
    }

    $marketingRecipe = Resolve-WechatMarketingEmptyStateRecipe -TaskText $text
    if ($null -ne $marketingRecipe) {
        $route.intent = 'generated-product'
        $route.mode = [string]$marketingRecipe.route_mode
        $route.reason = 'matched_marketing_empty_state_recipe'
        return [pscustomobject]$route
    }

    $productRecipe = Resolve-WechatProductListingRecipe -TaskText $text
    if ($null -ne $productRecipe) {
        $route.intent = 'generated-product'
        $route.mode = [string]$productRecipe.route_mode
        $route.task_family = 'product-listing'
        $route.reason = 'matched_product_listing_recipe'
        return [pscustomobject]$route
    }

    $productDetailRecipe = Resolve-WechatProductDetailRecipe -TaskText $text
    $translation = Invoke-WechatTaskTranslator -TaskText $text
    if ($null -ne $translation -and $translation.status -eq 'success' -and $null -ne $translation.task_spec) {
        $route.intent = 'generated-product'
        $route.mode = [string]$translation.task_spec.route_mode
        $route.task_family = [string]$translation.task_spec.task_family
        $route.task_spec = $translation.task_spec
        $route.page_bundle = $translation.page_bundle
        $route.component_bundle = $translation.component_bundle
        $route.component_bundles = $translation.component_bundles
        $route.app_patch = $translation.app_patch
        $route.translation_source = [string]$translation.source
        $route.reason = [string]$translation.reason
        return [pscustomobject]$route
    }

    if ($normalized -match 'sandbox\s+create\s+file|create\s+sandbox\s+js|沙盒.*创建.*js') {
        $route.intent = 'spec'
        $route.mode = 'sandbox-create'
        $route.spec_path = Join-Path $repoRoot 'specs\task-202-sandbox-create-file.json'
        $route.reason = 'matched_sandbox_create_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'sandbox\s+modify\s+app\.js\s+rollback|modify\s+sandbox\s+app\s+rollback|沙盒.*app\.js.*回滚') {
        $route.intent = 'spec'
        $route.mode = 'sandbox-modify-rollback'
        $route.spec_path = Join-Path $repoRoot 'specs\task-203-sandbox-modify-rollback.json'
        $route.reason = 'matched_sandbox_modify_rollback_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'sandbox|lab execute|dispatcher proof|sandbox proof') {
        $route.intent = 'spec'
        $route.mode = 'sandbox-execute'
        $route.spec_path = Join-Path $repoRoot 'specs\task-201-sandbox-dispatcher-proof.json'
        $route.reason = 'matched_sandbox_execution_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'preview|qrcode|qr') {
        $route.intent = 'spec'
        $route.mode = 'preview'
        $route.spec_path = Join-Path $repoRoot 'specs\task-003-preview.json'
        $route.reason = 'matched_preview_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'cloud-changed|changed cloud|changed-only') {
        $route.intent = 'spec'
        $route.mode = 'cloud-changed'
        $route.spec_path = Join-Path $repoRoot 'specs\task-007-cloud-changed.json'
        $route.reason = 'matched_cloud_changed_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'timercancelorder|timer cancel order|cancel order log|timer log') {
        $route.intent = 'spec'
        $route.mode = 'real-write'
        $route.spec_path = Join-Path $repoRoot 'specs\task-add-log-to-timer.json'
        $route.safe = $false
        $route.requires_confirmation = $true
        $route.reason = 'matched_timer_cancel_order_write_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match '\bgetorder\b|get order|order query log|add log to getorder') {
        $route.intent = 'spec'
        $route.mode = 'real-write'
        $route.spec_path = Join-Path $repoRoot 'specs\task-005-add-log-getOrder-v2.json'
        $route.safe = $false
        $route.requires_confirmation = $true
        $route.reason = 'matched_get_order_write_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'list-functions|cloud functions|function inventory|diagnostic|read-only') {
        $route.intent = 'spec'
        $route.mode = 'list-functions'
        $route.spec_path = Join-Path $repoRoot 'specs\task-006-readonly-diagnostic.json'
        $route.reason = 'matched_readonly_diagnostic_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'readonly check|read-only check|health check|mcp health|mcp status') {
        $route.intent = 'readonly-check'
        $route.mode = 'readonly-check'
        $route.reason = 'matched_readonly_check_keywords'
        return [pscustomobject]$route
    }

    if ($normalized -match 'validate|layer 4|regression|test suite') {
        $route.intent = 'validation'
        $route.mode = 'validate'
        $route.reason = 'matched_validation_keywords'
        return [pscustomobject]$route
    }

    return [pscustomobject]$route
}

function Get-WechatTaskCandidates {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $text = $TaskText.Trim()
    $normalized = $text.ToLowerInvariant()
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $candidates = @()

    if ([string]::IsNullOrWhiteSpace($text)) {
        return @()
    }

    if ($normalized -match 'preview|qrcode|qr|release|publish') {
        $candidates += [pscustomobject]@{
            label                 = 'preview-current-project'
            summary               = 'Generate a preview QR for the current project'
            intent                = 'spec'
            mode                  = 'preview'
            spec_path             = Join-Path $repoRoot 'specs\task-003-preview.json'
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    $marketingRecipe = Resolve-WechatMarketingEmptyStateRecipe -TaskText $text
    if ($null -ne $marketingRecipe) {
        $candidates += [pscustomobject]@{
            label                 = ('generated-{0}' -f $marketingRecipe.route_mode)
            summary               = ('Create a generated {0} marketing page shell with CTA and supporting copy' -f $marketingRecipe.route_mode)
            intent                = 'generated-product'
            mode                  = [string]$marketingRecipe.route_mode
            spec_path             = $null
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    $productRecipe = Resolve-WechatProductListingRecipe -TaskText $text
    if ($null -ne $productRecipe) {
        $candidates += [pscustomobject]@{
            label                 = 'generated-product-listing'
            summary               = 'Create a generated product listing mini program shell with reusable product cards'
            intent                = 'generated-product'
            mode                  = [string]$productRecipe.route_mode
            spec_path             = $null
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    $productDetailRecipe = Resolve-WechatProductDetailRecipe -TaskText $text
    if ($null -ne $productDetailRecipe) {
        $candidates += [pscustomobject]@{
            label                 = 'generated-product-detail'
            summary               = 'Create a generated product detail mini program page with image, description, price, and add-to-cart CTA'
            intent                = 'generated-product'
            mode                  = [string]$productDetailRecipe.route_mode
            spec_path             = $null
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if (($null -eq $marketingRecipe) -and ($null -eq $productRecipe) -and ($null -eq $productDetailRecipe)) {
        $translation = Invoke-WechatTaskTranslator -TaskText $text
        if ($null -ne $translation -and $translation.status -eq 'success' -and $null -ne $translation.task_spec) {
            $summary = switch ([string]$translation.task_spec.task_family) {
                'product-listing' { 'Create a translated product-listing mini program shell from natural-language intent' }
                'marketing-empty-state' { 'Create a translated marketing empty-state mini program shell from natural-language intent' }
                default { 'Create a translated generated-product mini program shell from natural-language intent' }
            }

            $candidates += [pscustomobject]@{
                label                 = ('translated-{0}' -f $translation.task_spec.route_mode)
                summary               = $summary
                intent                = 'generated-product'
                mode                  = [string]$translation.task_spec.route_mode
                spec_path             = $null
                safe                  = $true
                requires_confirmation = $false
                rank                  = 1
            }
        }
    }

    if ($normalized -match 'sandbox|lab execute|dispatcher proof|sandbox proof') {
        $candidates += [pscustomobject]@{
            label                 = 'sandbox-dispatcher-proof'
            summary               = 'Run a sandbox-only dispatcher proof task through spec execution'
            intent                = 'spec'
            mode                  = 'sandbox-execute'
            spec_path             = Join-Path $repoRoot 'specs\task-201-sandbox-dispatcher-proof.json'
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if ($normalized -match 'sandbox\s+create\s+file|create\s+sandbox\s+js|沙盒.*创建.*js') {
        $candidates += [pscustomobject]@{
            label                 = 'sandbox-create-file'
            summary               = 'Create a sandbox JS file and validate creation'
            intent                = 'spec'
            mode                  = 'sandbox-create'
            spec_path             = Join-Path $repoRoot 'specs\task-202-sandbox-create-file.json'
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if ($normalized -match 'sandbox\s+modify\s+app\.js\s+rollback|modify\s+sandbox\s+app\s+rollback|沙盒.*app\.js.*回滚') {
        $candidates += [pscustomobject]@{
            label                 = 'sandbox-modify-rollback'
            summary               = 'Modify sandbox app.js marker and rollback in validation command'
            intent                = 'spec'
            mode                  = 'sandbox-modify-rollback'
            spec_path             = Join-Path $repoRoot 'specs\task-203-sandbox-modify-rollback.json'
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if ($normalized -match 'validate|layer 4|regression|test') {
        $candidates += [pscustomobject]@{
            label                 = 'run-validation'
            summary               = 'Run the validation pipeline without deployment'
            intent                = 'validation'
            mode                  = 'validate'
            spec_path             = $null
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if ($normalized -match 'list-functions|cloud functions|function inventory|diagnostic|read-only') {
        $candidates += [pscustomobject]@{
            label                 = 'readonly-cloud-diagnostic'
            summary               = 'Run a read-only cloud function inventory diagnostic'
            intent                = 'spec'
            mode                  = 'list-functions'
            spec_path             = Join-Path $repoRoot 'specs\task-006-readonly-diagnostic.json'
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if ($normalized -match 'readonly check|read-only check|health check|mcp health|mcp status') {
        $candidates += [pscustomobject]@{
            label                 = 'readonly-mcp-check'
            summary               = 'Run the consolidated readonly MCP status/history/trend check'
            intent                = 'readonly-check'
            mode                  = 'readonly-check'
            spec_path             = $null
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if ($normalized -match 'cloud-changed|changed cloud|changed-only') {
        $candidates += [pscustomobject]@{
            label                 = 'deploy-changed-cloud-functions'
            summary               = 'Deploy only cloud functions currently detected as changed'
            intent                = 'spec'
            mode                  = 'cloud-changed'
            spec_path             = Join-Path $repoRoot 'specs\task-007-cloud-changed.json'
            safe                  = $true
            requires_confirmation = $false
            rank                  = 1
        }
    }

    if ($normalized -match '\bgetorder\b|get order|order query log|add log') {
        $candidates += [pscustomobject]@{
            label                 = 'write-log-getorder'
            summary               = 'Add entry and exit logs to getOrder'
            intent                = 'spec'
            mode                  = 'real-write'
            spec_path             = Join-Path $repoRoot 'specs\task-005-add-log-getOrder-v2.json'
            safe                  = $false
            requires_confirmation = $true
            rank                  = 2
        }
    }

    if ($normalized -match 'timercancelorder|timer cancel order|cancel order log|timer log|add log') {
        $candidates += [pscustomobject]@{
            label                 = 'write-log-timercancelorder'
            summary               = 'Add entry and exit logs to timerCancelOrder'
            intent                = 'spec'
            mode                  = 'real-write'
            spec_path             = Join-Path $repoRoot 'specs\task-add-log-to-timer.json'
            safe                  = $false
            requires_confirmation = $true
            rank                  = 3
        }
    }

    return @($candidates | Sort-Object rank, label)
}

function Get-RecommendedWechatTask {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $candidates = @(Get-WechatTaskCandidates -TaskText $TaskText)
    if ($candidates.Count -eq 0) {
        return $null
    }

    return $candidates[0]
}

function Get-WechatTaskHandoff {
    param(
        [Parameter(Mandatory)][string]$TaskText
    )

    $route = Resolve-WechatTaskIntent -TaskText $TaskText
    $candidates = @(Get-WechatTaskCandidates -TaskText $TaskText)
    $recommended = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }

    $guardStatus = if ($null -eq $recommended) {
        'no_match'
    }
    elseif ($recommended.safe -and -not $recommended.requires_confirmation) {
        'safe_to_run'
    }
    elseif ($recommended.requires_confirmation) {
        'confirmation_required'
    }
    else {
        'guarded'
    }

    return [pscustomobject]@{
        input              = $TaskText
        route_intent       = $route.intent
        route_mode         = $route.mode
        route_reason       = $route.reason
        recommended        = $recommended
        candidate_count    = $candidates.Count
        candidates         = $candidates
        guard_status       = $guardStatus
        requires_approval  = ($guardStatus -eq 'confirmation_required')
        recommended_spec   = if ($recommended) { $recommended.spec_path } else { $null }
    }
}

function Invoke-WechatTask {
    param(
        [Parameter(Mandatory)][string]$TaskText,
        [switch]$ResolveOnly,
        [switch]$SuggestOnly,
        [switch]$RecommendOnly,
        [switch]$HandoffOnly,
        [switch]$AllowWriteRoute,
        [ValidateSet('auto', 'suite', 'embedded')]
        [string]$ValidationModeOverride = 'auto'
    )

    $candidates = @(Get-WechatTaskCandidates -TaskText $TaskText)
    if ($SuggestOnly) {
        return $candidates
    }
    if ($RecommendOnly) {
        return Get-RecommendedWechatTask -TaskText $TaskText
    }
    if ($HandoffOnly) {
        return Get-WechatTaskHandoff -TaskText $TaskText
    }

    $route = Resolve-WechatTaskIntent -TaskText $TaskText
    if ($ResolveOnly) {
        return $route
    }

    switch ($route.intent) {
        'help' {
            if (Get-Command Get-WechatHelp -ErrorAction SilentlyContinue) {
                Get-WechatHelp
            }
            return @{
                status = 'resolved'
                intent = 'help'
                route  = $route
            }
        }
        'validation' {
            $validation = Invoke-AgenticValidation -ValidationMode $ValidationModeOverride
            return @{
                status = $validation.status
                intent = 'validation'
                route  = $route
                result = $validation
            }
        }
        'readonly-check' {
            if (-not (Get-Command Invoke-WechatReadonlyCheck -ErrorAction SilentlyContinue)) {
                return @{
                    status = 'failed'
                    intent = 'readonly-check'
                    route  = $route
                    error  = 'readonly_check_command_not_found'
                }
            }

            $checkRaw = Invoke-WechatReadonlyCheck -AsJson 2>&1 | Out-String
            try {
                $check = $checkRaw | ConvertFrom-Json
            } catch {
                return @{
                    status = 'failed'
                    intent = 'readonly-check'
                    route  = $route
                    error  = 'readonly_check_parse_failed'
                    output = $checkRaw
                }
            }

            return @{
                status = if ($check.stable) { 'success' } else { 'failed' }
                intent = 'readonly-check'
                route  = $route
                result = $check
            }
        }
        'generated-product' {
            if ($null -ne $route.task_spec -and [string]$route.translation_source -eq 'translator') {
                $execution = Invoke-WechatTaskExecution `
                    -TaskSpec $route.task_spec `
                    -PageBundle $route.page_bundle `
                    -ComponentBundle $route.component_bundle `
                    -ComponentBundles $route.component_bundles `
                    -AppPatch $route.app_patch `
                    -Preview $false

                return @{
                    status = $execution.status
                    intent = 'generated-product'
                    route  = $route
                    result = $execution
                }
            }

            switch ($route.mode) {
                'coupon-empty-state' {
                    $productResult = Invoke-WechatCouponEmptyStateTask -TaskText $TaskText -RunRepairLoop $true
                    return @{
                        status = $productResult.status
                        intent = 'generated-product'
                        route  = $route
                        result = $productResult
                    }
                }
                'activity-not-started' {
                    $recipe = Resolve-WechatMarketingEmptyStateRecipe -TaskText $TaskText
                    $productResult = Invoke-WechatMarketingEmptyStateTask -Recipe $recipe -TaskText $TaskText -RunRepairLoop $true
                    return @{
                        status = $productResult.status
                        intent = 'generated-product'
                        route  = $route
                        result = $productResult
                    }
                }
                'benefits-empty-state' {
                    $recipe = Resolve-WechatMarketingEmptyStateRecipe -TaskText $TaskText
                    $productResult = Invoke-WechatMarketingEmptyStateTask -Recipe $recipe -TaskText $TaskText -RunRepairLoop $true
                    return @{
                        status = $productResult.status
                        intent = 'generated-product'
                        route  = $route
                        result = $productResult
                    }
                }
                'product-listing' {
                    $recipe = Resolve-WechatProductListingRecipe -TaskText $TaskText
                    $productResult = Invoke-WechatProductListingTask -Recipe $recipe -TaskText $TaskText -RunRepairLoop $true
                    return @{
                        status = $productResult.status
                        intent = 'generated-product'
                        route  = $route
                        result = $productResult
                    }
                }
                'product-detail' {
                    $recipe = Resolve-WechatProductDetailRecipe -TaskText $TaskText
                    $productResult = Invoke-WechatProductDetailTask -Recipe $recipe -TaskText $TaskText -RunRepairLoop $true
                    return @{
                        status = $productResult.status
                        intent = 'generated-product'
                        route  = $route
                        result = $productResult
                    }
                }
                default {
                    return @{
                        status = 'failed'
                        intent = 'generated-product'
                        route  = $route
                        error  = 'unsupported_generated_product_mode'
                    }
                }
            }
        }
        'spec' {
            if (-not $route.spec_path -or -not (Test-Path $route.spec_path)) {
                return @{
                    status = 'failed'
                    intent = 'spec'
                    route  = $route
                    error  = 'spec_not_found'
                }
            }

            if (($route.requires_confirmation -or -not $route.safe) -and -not $AllowWriteRoute) {
                return @{
                    status = 'confirmation_required'
                    intent = 'spec'
                    route  = $route
                    error  = 'unsafe_route_requires_explicit_confirmation'
                }
            }

            $specResult = Invoke-AgenticLoopFromSpec -SpecPath $route.spec_path -ValidationModeOverride $ValidationModeOverride
            return @{
                status = $specResult.status
                intent = 'spec'
                route  = $route
                result = $specResult
            }
        }
        default {
            $recommended = if ($candidates.Count -gt 0) { $candidates[0] } else { $null }
            return @{
                status = 'unroutable'
                intent = 'unknown'
                route  = $route
                suggestions = $candidates
                recommended = $recommended
            }
        }
    }
}
