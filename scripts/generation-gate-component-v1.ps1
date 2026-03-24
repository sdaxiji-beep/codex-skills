. (Join-Path $PSScriptRoot 'generation-gate-ast-policy.ps1')

function Add-GenerationGateComponentV1Error {
    param(
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$Message,
        [switch]$Hard
    )

    $Result.Errors.Add($Message)
    if ($Hard) {
        $Result.Status = 'hard_fail'
        return
    }

    if ($Result.Status -eq 'pass') {
        $Result.Status = 'retryable_fail'
    }
}

function Get-GenerationGateComponentV1AstHybridMode {
    return (Get-WechatAstHybridMode)
}

function Get-GenerationGateComponentV1AstPromotedSeverities {
    return (Get-WechatAstPromotedSeverities)
}

function Invoke-GenerationGateComponentV1AstShadow {
    param(
        [Parameter(Mandatory)][string]$JsonPayload
    )

    $result = [pscustomobject]@{
        executed = $false
        available = $false
        parser = 'none'
        diagnostics = @()
        error = $null
    }

    $validatorScript = Join-Path $PSScriptRoot 'validators\validate-bundle-ast.mjs'
    if (-not (Test-Path $validatorScript)) {
        $result.error = "validator_missing:$validatorScript"
        return $result
    }

    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $nodeCommand) {
        $result.error = 'node_missing'
        return $result
    }

    $tempInputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("gate-component-v1-ast-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        [System.IO.File]::WriteAllText($tempInputPath, $JsonPayload, (New-Object System.Text.UTF8Encoding($false)))
        $rawOutput = & $nodeCommand.Source $validatorScript --input $tempInputPath 2>$null
        if ($LASTEXITCODE -ne 0) {
            $result.error = "validator_exit_code:$LASTEXITCODE"
            return $result
        }

        $parsed = $rawOutput | ConvertFrom-Json -ErrorAction Stop
        $result.executed = $true
        $result.available = [bool]$parsed.ok
        if ($parsed.PSObject.Properties.Name -contains 'parser_name') {
            $result.parser = [string]$parsed.parser_name
        }
        if ($parsed.PSObject.Properties.Name -contains 'diagnostics' -and $null -ne $parsed.diagnostics) {
            $result.diagnostics = @($parsed.diagnostics)
        }
        return $result
    }
    catch {
        $result.error = "validator_exception:$($_.Exception.Message)"
        return $result
    }
    finally {
        if (Test-Path $tempInputPath) {
            Remove-Item -Path $tempInputPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Write-GenerationGateComponentV1AstShadowArtifact {
    param(
        [Parameter(Mandatory)]$ShadowResult,
        [Parameter(Mandatory)]$GateResult
    )

    try {
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $artifactDir = Join-Path $repoRoot 'artifacts\wechat-devtools\generation-gate'
        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

        $errorCount = Get-WechatAstErrorDiagnosticCount -Diagnostics $ShadowResult.diagnostics
        $gateHasError = @($GateResult.Errors).Count -gt 0

        $hybridMode = Get-GenerationGateComponentV1AstHybridMode
        $promotedSeverities = Get-GenerationGateComponentV1AstPromotedSeverities
        $promotedCount = Get-WechatAstPromotedDiagnosticCount -Diagnostics $ShadowResult.diagnostics -PromotedSeverities $promotedSeverities

        $artifact = [pscustomobject]@{
            generated_at = (Get-Date).ToString('o')
            gate_kind = 'component'
            gate_status = [string]$GateResult.Status
            gate_error_count = @($GateResult.Errors).Count
            hybrid_mode = $hybridMode
            promoted_severities = @($promotedSeverities)
            shadow_executed = [bool]$ShadowResult.executed
            shadow_available = [bool]$ShadowResult.available
            shadow_parser = [string]$ShadowResult.parser
            shadow_error_count = $errorCount
            promoted_error_count = if ($hybridMode) { Get-WechatAstErrorDiagnosticCount -Diagnostics $ShadowResult.diagnostics } else { 0 }
            promoted_diagnostic_count = if ($hybridMode) { $promotedCount } else { 0 }
            shadow_error = $ShadowResult.error
            shadow_mismatch = ($errorCount -gt 0 -and -not $gateHasError)
            diagnostics = @($ShadowResult.diagnostics)
        }

        $json = $artifact | ConvertTo-Json -Depth 10
        $latestPath = Join-Path $artifactDir 'component-ast-shadow-latest.json'
        $timestampPath = Join-Path $artifactDir ("component-ast-shadow-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.json')
        [System.IO.File]::WriteAllText($latestPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText($timestampPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    }
    catch {
        # Stage 2A shadow mode must never change gate verdict.
    }
}

function Apply-GenerationGateComponentV1AstHybridErrors {
    param(
        [Parameter(Mandatory)]$ShadowResult,
        [Parameter(Mandatory)]$GateResult
    )

    if (-not (Get-GenerationGateComponentV1AstHybridMode)) {
        return
    }

    if (-not $ShadowResult.executed -or -not $ShadowResult.available) {
        return
    }

    $promotedSeverities = Get-GenerationGateComponentV1AstPromotedSeverities
    $promotedDiagnostics = @(Get-WechatAstDiagnosticsBySeverity -Diagnostics $ShadowResult.diagnostics -Severities $promotedSeverities)

    foreach ($diag in $promotedDiagnostics) {
        Add-GenerationGateComponentV1Error -Result $GateResult -Message (New-WechatAstGateMessage -Diagnostic $diag)
    }
}

function Get-GenerationGateComponentV1AllowedJsonKeys {
    return @(
        'component',
        'usingComponents',
        'styleIsolation',
        'virtualHost',
        'multipleSlots'
    )
}

function Get-GenerationGateComponentV1AllowedTags {
    return @(
        'view',
        'text',
        'image',
        'button',
        'scroll-view',
        'input',
        'textarea',
        'form',
        'label',
        'picker',
        'picker-view',
        'picker-view-column',
        'switch',
        'slider',
        'swiper',
        'swiper-item',
        'checkbox',
        'checkbox-group',
        'radio',
        'radio-group',
        'navigator',
        'icon',
        'progress',
        'rich-text',
        'movable-area',
        'movable-view',
        'cover-image',
        'cover-view',
        'block',
        'slot'
    )
}

function Get-GenerationGateComponentV1VoidTags {
    return @(
        'image',
        'input',
        'icon',
        'progress',
        'checkbox',
        'radio',
        'switch',
        'slider'
    )
}

function Test-GenerationGateComponentV1WxmlBalance {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string[]]$AllowedTags,
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$Path
    )

    $voidTags = Get-GenerationGateComponentV1VoidTags
    $stack = New-Object System.Collections.Generic.Stack[string]
    $tagMatches = [regex]::Matches($Content, '<\s*(/)?\s*([a-zA-Z][\w-]*)\b[^>]*(/?)>')

    foreach ($match in $tagMatches) {
        $isClosing = $match.Groups[1].Success
        $tagName = $match.Groups[2].Value.ToLowerInvariant()
        $isExplicitSelfClosing = $match.Groups[3].Success -and $match.Groups[3].Value -eq '/'
        $isVoidTag = $voidTags -contains $tagName

        if ($AllowedTags -notcontains $tagName) {
            Add-GenerationGateComponentV1Error -Result $Result -Message "WXML Error: Found unauthorized tag <$tagName> in '$Path'."
            continue
        }

        if ($isClosing) {
            if ($stack.Count -eq 0) {
                Add-GenerationGateComponentV1Error -Result $Result -Message "WXML Error: Found closing tag </$tagName> without matching open tag in '$Path'."
                continue
            }

            $openTag = $stack.Pop()
            if ($openTag -ne $tagName) {
                Add-GenerationGateComponentV1Error -Result $Result -Message "WXML Error: Tag mismatch in '$Path'. Expected </$openTag> but found </$tagName>."
            }
            continue
        }

        if (-not $isExplicitSelfClosing -and -not $isVoidTag) {
            $stack.Push($tagName)
        }
    }

    while ($stack.Count -gt 0) {
        $unclosed = $stack.Pop()
        Add-GenerationGateComponentV1Error -Result $Result -Message "WXML Error: Unclosed tag <$unclosed> in '$Path'."
    }
}

function Invoke-GenerationGateComponentV1 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonPayload
    )

    $result = [PSCustomObject]@{
        Status = 'pass'
        Errors = [System.Collections.Generic.List[string]]::new()
    }

    $bundle = $null
    try {
        $bundle = ConvertFrom-Json -InputObject $JsonPayload -ErrorAction Stop
    }
    catch {
        Add-GenerationGateComponentV1Error -Result $result -Message 'Parse Error: Unable to parse JSON payload. Output must be raw JSON without Markdown fences.'
        return $result
    }

    if ($null -eq $bundle.component_name -or [string]::IsNullOrWhiteSpace([string]$bundle.component_name)) {
        Add-GenerationGateComponentV1Error -Result $result -Message 'Contract Error: component_name is required.'
    }

    $files = @($bundle.files)
    if ($files.Count -eq 0) {
        Add-GenerationGateComponentV1Error -Result $result -Message 'Contract Error: files[] must contain at least one generated file.'
        return $result
    }

    $allowedJsonKeys = Get-GenerationGateComponentV1AllowedJsonKeys
    $defaultAllowedTags = Get-GenerationGateComponentV1AllowedTags
    $pathPattern = '^components/[a-zA-Z0-9_-]+/index\.(wxml|js|wxss|json)$'
    $hardBanPattern = '^(app\.(js|json|wxss)|project\.config\.json|pages/|scripts/|templates/)'
    $seenPaths = @{}
    $componentRoots = @{}
    $childComponentTags = @{}

    foreach ($file in $files) {
        $path = [string]$file.path
        $content = [string]$file.content

        if ([string]::IsNullOrWhiteSpace($path)) {
            Add-GenerationGateComponentV1Error -Result $result -Message 'Contract Error: each file entry must include a non-empty path.'
            continue
        }

        if ($seenPaths.ContainsKey($path)) {
            Add-GenerationGateComponentV1Error -Result $result -Message "Contract Error: duplicate path '$path' detected."
            continue
        }
        $seenPaths[$path] = $true

        if ($path -match $hardBanPattern) {
            Add-GenerationGateComponentV1Error -Result $result -Message "Path Error: '$path' is outside the component sandbox." -Hard
            continue
        }

        if ($path -notmatch $pathPattern) {
            Add-GenerationGateComponentV1Error -Result $result -Message "Path Error: '$path' must match components/<name>/index.(wxml|js|wxss|json)." -Hard
            continue
        }

        $componentRoot = ($path -replace '/index\.[^./]+$', '')
        $componentRoots[$componentRoot] = $true

        if ([string]::IsNullOrWhiteSpace($content)) {
            Add-GenerationGateComponentV1Error -Result $result -Message "Contract Error: '$path' has empty content."
            continue
        }

        if ($path.EndsWith('.json')) {
            try {
                $jsonObject = ConvertFrom-Json -InputObject $content -ErrorAction Stop
            }
            catch {
                Add-GenerationGateComponentV1Error -Result $result -Message "JSON Error: '$path' is not valid JSON."
                continue
            }

            if ($jsonObject.component -ne $true) {
                Add-GenerationGateComponentV1Error -Result $result -Message "JSON Error: '$path' must include component=true in the component config."
            }

            $keys = @($jsonObject.PSObject.Properties.Name)
            foreach ($key in $keys) {
                if ($allowedJsonKeys -notcontains $key) {
                    Add-GenerationGateComponentV1Error -Result $result -Message "JSON Error: Key '$key' is not allowed in component config '$path'."
                }
            }

            $componentTags = @()
            if ($jsonObject.usingComponents) {
                if ($jsonObject.usingComponents -isnot [psobject] -and $jsonObject.usingComponents -isnot [hashtable]) {
                    Add-GenerationGateComponentV1Error -Result $result -Message "JSON Error: usingComponents in '$path' must be an object."
                }
                else {
                    $componentTags = @($jsonObject.usingComponents.PSObject.Properties.Name | ForEach-Object {
                        ([string]$_).ToLowerInvariant()
                    })
                }
            }
            $childComponentTags[$componentRoot] = $componentTags
        }
    }

    if ($componentRoots.Count -gt 1) {
        Add-GenerationGateComponentV1Error -Result $result -Message 'Contract Error: V1 only supports generating a single component root per bundle.'
    }

    if ($bundle.component_name -and $componentRoots.Count -eq 1) {
        $onlyComponentRoot = @($componentRoots.Keys)[0]
        $expectedRoot = "components/$([string]$bundle.component_name)"
        if ($onlyComponentRoot -ne $expectedRoot) {
            Add-GenerationGateComponentV1Error -Result $result -Message "Contract Error: component_name '$($bundle.component_name)' does not match generated component root '$onlyComponentRoot'."
        }
    }

    foreach ($file in $files) {
        $path = [string]$file.path
        $content = [string]$file.content

        if ($path -notmatch $pathPattern) {
            continue
        }

        $componentRoot = ($path -replace '/index\.[^./]+$', '')
        $componentTags = @()
        if ($childComponentTags.ContainsKey($componentRoot)) {
            $componentTags = @($childComponentTags[$componentRoot] | Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_)
            })
        }
        $allowedTags = @($defaultAllowedTags) + $componentTags

        if ($content -match 'document\.|window\.|localStorage\.') {
            Add-GenerationGateComponentV1Error -Result $result -Message "Runtime Error: Found forbidden DOM/BOM API in '$path'."
        }

        if ($content -match 'fetch\s*\(|axios\.') {
            Add-GenerationGateComponentV1Error -Result $result -Message "Runtime Error: Found forbidden Web request API in '$path'. Use wx.* APIs instead."
        }

        if ($path.EndsWith('.wxml')) {
            if ($content -match '<\s*(div|span|a|img|p|ul|li|html|body|script)\b') {
                Add-GenerationGateComponentV1Error -Result $result -Message "WXML Error: Found unauthorized HTML tag in '$path'."
            }
            Test-GenerationGateComponentV1WxmlBalance -Content $content -AllowedTags $allowedTags -Result $result -Path $path
        }
        elseif ($path.EndsWith('.js')) {
            if ($content -match 'Page\s*\(') {
                Add-GenerationGateComponentV1Error -Result $result -Message "JS Error: '$path' cannot use Page(). Components must use Component()."
            }
            if ($content -notmatch '^\s*Component\s*\(\s*\{[\s\S]*\}\s*\)\s*;?\s*$') {
                Add-GenerationGateComponentV1Error -Result $result -Message "JS Error: '$path' must be wrapped in Component({ ... })."
            }
            if ($content -notmatch 'properties\s*:') {
                Add-GenerationGateComponentV1Error -Result $result -Message "JS Error: '$path' must declare a properties object."
            }
            if ($content -match '\b(Date|Map|Set|Promise)\b') {
                Add-GenerationGateComponentV1Error -Result $result -Message "JS Error: '$path' uses unsupported property or runtime types for Component v1."
            }
        }
        elseif ($path.EndsWith('.wxss')) {
            if ($content -match '(?<![\w-])(?:\d+|\d*\.\d+)(px|em|rem)\b') {
                Add-GenerationGateComponentV1Error -Result $result -Message "WXSS Error: '$path' uses unsupported or discouraged units. Prefer rpx."
            }
            if ($content -match '(^|\s|}|,)(page|body|html)(\s*\{|,)') {
                Add-GenerationGateComponentV1Error -Result $result -Message "WXSS Error: '$path' uses forbidden global selectors (page/body/html)."
            }
        }
    }

    $shadowResult = Invoke-GenerationGateComponentV1AstShadow -JsonPayload $JsonPayload
    Apply-GenerationGateComponentV1AstHybridErrors -ShadowResult $shadowResult -GateResult $result
    Write-GenerationGateComponentV1AstShadowArtifact -ShadowResult $shadowResult -GateResult $result

    return $result
}
