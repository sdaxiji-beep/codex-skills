[CmdletBinding()]
param(
    [ValidateSet('ok', 'skipped', 'failed')]
    [string]$Variant = 'ok',
    [switch]$UseAutomator = $true,
    [switch]$AsJson
)

. "$PSScriptRoot\wechat-get-port.ps1"
. "$PSScriptRoot\wechat-automator-port.ps1"

function Get-WechatCliPath {
    $candidate = Get-ChildItem -Path 'C:\Program Files (x86)\Tencent' -Filter 'cli.bat' -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($candidate) {
        return $candidate
    }

    return 'C:\Program Files (x86)\Tencent\鐎甸偊鍠曟穱濡沞b鐎殿喒鍋撻柛娆愬灱閳ь剙鎳庢导鎰板礂缁屽儯li.bat'
}

function Get-WorkspaceRoot {
    return (Split-Path $PSScriptRoot -Parent)
}

function Get-ReadonlyDefaultProjectPath {
    if (-not [string]::IsNullOrWhiteSpace($env:WECHAT_DEFAULT_PROJECT_PATH)) {
        return $env:WECHAT_DEFAULT_PROJECT_PATH
    }

    $workspaceRoot = Get-WorkspaceRoot
    $localConfigPath = Join-Path $workspaceRoot 'config\\local-release.config.json'
    if (Test-Path $localConfigPath) {
        try {
            $config = Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace([string]$config.projectRoot)) {
                return [string]$config.projectRoot
            }
        }
        catch {
        }
    }

    return (Join-Path $workspaceRoot 'sandbox')
}

function Test-AutomatorPort {
    param([int]$Port = 9420)
    $match = netstat -an | Select-String ":$Port"
    return [bool]$match
}

function Get-FreeAutomatorPort {
    param(
        [string]$ProjectPath = '',
        [int]$PreferredPort = 9420,
        [int]$MaxScan = 50
    )

    $candidatePorts = Get-ProjectScopedAutomatorPortCandidates `
        -ProjectPath $ProjectPath `
        -BasePort $PreferredPort `
        -PortSpan ([Math]::Max(8, [Math]::Min($MaxScan, 40))) `
        -ExtraScan ([Math]::Max(0, $MaxScan - 40))

    foreach ($candidate in $candidatePorts) {
        if (Test-TcpPort -Port $candidate -TimeoutMs 250) {
            return $candidate
        }
    }

    foreach ($candidate in $candidatePorts) {
        if (-not (Test-TcpPort -Port $candidate -TimeoutMs 250)) {
            return $candidate
        }
    }

    throw "No free automator port available near $PreferredPort"
}

function Test-TcpPort {
    param(
        [int]$Port,
        [int]$TimeoutMs = 500
    )

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $ok = $tcp.ConnectAsync('127.0.0.1', $Port).Wait($TimeoutMs)
        $tcp.Close()
        return $ok
    }
    catch {
        return $false
    }
}

function Invoke-ExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [int]$TimeoutMs = 15000
    )

    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if (-not $proc.WaitForExit($TimeoutMs)) {
            $proc.Kill()
            throw "Command timeout: $FilePath"
        }

        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            StdOut   = (Get-Content $stdout -Raw -ErrorAction SilentlyContinue)
            StdErr   = (Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
        }
    }
    finally {
        Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue
    }
}

function Get-ExternalCommandText {
    param($CommandResult)

    return (([string]$CommandResult.StdOut) + "`n" + ([string]$CommandResult.StdErr)).Trim()
}

function Test-WechatCliFatalOutput {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return ($Text -match 'invalid appid' -or
        $Text -match 'code:\s*10' -or
        $Text -match '\[error\]')
}

function Ensure-AutomatorPort {
    param(
        [string]$ProjectPath = '',
        [int]$AutoPort = 9420
    )

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $ProjectPath = Get-ReadonlyDefaultProjectPath
    }

    if (Test-AutomatorPort -Port $AutoPort) {
        Write-Verbose "[AUTOMATOR] Port $AutoPort already available."
        return $AutoPort
    }

    $cliPath = Get-WechatCliPath
    if (-not (Test-Path $cliPath)) {
        throw "WeChat CLI not found: $cliPath"
    }

    if (Test-AutomatorPort -Port $AutoPort) {
        Write-Verbose "[AUTOMATOR] Port $AutoPort already available."
        return $AutoPort
    }

    Write-Verbose "[AUTOMATOR] Opening project before starting automation port $AutoPort."
    $openCmd = Invoke-ExternalCommand -FilePath $cliPath -ArgumentList @(
        'open',
        '--project', $ProjectPath
    ) -TimeoutMs 30000
    $openText = Get-ExternalCommandText -CommandResult $openCmd
    if (Test-WechatCliFatalOutput -Text $openText) {
        throw "Open project for automator failed: $openText"
    }

    Start-Sleep -Seconds 2

    Write-Verbose "[AUTOMATOR] Starting automation port $AutoPort."
    Start-Process -FilePath $cliPath -ArgumentList @(
        'auto',
        '--project', $ProjectPath,
        '--auto-port', $AutoPort
    ) -WindowStyle Hidden | Out-Null

    for ($i = 0; $i -lt 30 -and -not (Test-AutomatorPort -Port $AutoPort); $i++) {
        Start-Sleep -Seconds 1
    }
    if (-not (Test-AutomatorPort -Port $AutoPort)) {
        throw "Automation port $AutoPort unavailable after CLI startup."
    }

    return $AutoPort
}

function Get-AutomatorPageInfo {
    param(
        [string]$ProjectPath = '',
        [int]$AutoPort = 0
    )

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $ProjectPath = Get-ReadonlyDefaultProjectPath
    }

    if ($AutoPort -le 0) {
        $AutoPort = Get-FreeAutomatorPort -ProjectPath $ProjectPath
    }

    Write-Verbose "[AUTOMATOR] Ensuring automation port $AutoPort."
    $AutoPort = Ensure-AutomatorPort -ProjectPath $ProjectPath -AutoPort $AutoPort

    $probeScript = Join-Path (Get-WorkspaceRoot) 'probe-automator.js'
    if (-not (Test-Path $probeScript)) {
        throw "Probe script missing: $probeScript"
    }

    $lastError = $null
    $prevPort = $env:WECHAT_DEVTOOLS_PORT
    $env:WECHAT_DEVTOOLS_PORT = [string]$AutoPort
    try {
        for ($i = 0; $i -lt 3; $i++) {
            try {
                $cmd = Invoke-ExternalCommand -FilePath 'node' -ArgumentList @($probeScript) -TimeoutMs 15000
                $stdout = $cmd.StdOut
                $stderr = $cmd.StdErr

                Write-Verbose "[AUTOMATOR] exitCode: $($cmd.ExitCode)"
                Write-Verbose "[AUTOMATOR] stderr: $stderr"
                Write-Verbose "[AUTOMATOR] stdout: $stdout"

                $jsonLine = ($stdout -split "`n" |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { $_ -match '^\{' } |
                    Select-Object -Last 1)

                if ($jsonLine) {
                    try {
                        return ($jsonLine | ConvertFrom-Json)
                    }
                    catch {
                        Write-Verbose "[AUTOMATOR] JSON parse failed: $_"
                        return $null
                    }
                }

                if ($cmd.ExitCode -ne 0 -and -not [string]::IsNullOrWhiteSpace([string]$cmd.ExitCode)) {
                    Write-Verbose "[AUTOMATOR] probe failed, exitCode=$($cmd.ExitCode)"
                    return $null
                }

                if (-not $jsonLine) {
                    Write-Verbose '[AUTOMATOR] no JSON line found.'
                    Write-Verbose "[AUTOMATOR] stdout raw: $stdout"
                    return $null
                }
            }
            catch {
                $lastError = $_
                Start-Sleep -Seconds 2
            }
        }
    }
    finally {
        if ($null -eq $prevPort) {
            Remove-Item Env:WECHAT_DEVTOOLS_PORT -ErrorAction SilentlyContinue
        }
        else {
            $env:WECHAT_DEVTOOLS_PORT = $prevPort
        }
    }

    throw "Automator probe failed after retries. $lastError"
}

function Get-VariantContract {
    param([string]$Variant)

    switch ($Variant) {
        'ok' {
            return @{
                exit_code           = 0
                page_validation     = @{
                    status              = 'ok'
                    reason              = 'image_unchanged'
                    result_level        = 'pass'
                    raw_result_level    = 'pass'
                    result_level_policy = 'raw'
                    page_state_class    = 'state_unchanged'
                    semantic_kind       = 'page_outcome'
                    interpretation      = 'static_like'
                }
                page_candidate_kind = 'outcome_unchanged'
                page_catalog_id     = 'page_outcome_unchanged_v1'
                page_catalog_label  = 'Outcome Unchanged'
                page_family_label   = 'Outcome'
            }
        }
        'skipped' {
            return @{
                exit_code           = 3
                page_validation     = @{
                    status              = 'skipped'
                    reason              = 'tap_capture_before_after_not_available'
                    result_level        = 'pass'
                    raw_result_level    = 'warn'
                    result_level_policy = 'normalize_skipped_capture_unavailable'
                    page_state_class    = 'evidence_missing'
                    semantic_kind       = 'evidence_state'
                    interpretation      = 'missing_capture'
                }
                page_candidate_kind = 'evidence_missing'
                page_catalog_id     = 'page_evidence_missing_v1'
                page_catalog_label  = 'Evidence Missing'
                page_family_label   = 'Evidence'
            }
        }
        'failed' {
            return @{
                exit_code           = 2
                page_validation     = @{
                    status              = 'failed'
                    reason              = 'hash_compare_failed'
                    result_level        = 'warn'
                    raw_result_level    = 'warn'
                    result_level_policy = 'raw'
                    page_state_class    = 'compare_failed'
                    semantic_kind       = 'failure_state'
                    interpretation      = 'compare_failed'
                }
                page_candidate_kind = 'compare_failed'
                page_catalog_id     = 'page_compare_failed_v1'
                page_catalog_label  = 'Compare Failed'
                page_family_label   = 'Failure'
            }
        }
    }
}

function Set-PageValidationSignature {
    param(
        [hashtable]$FlowResult,
        [string]$Source
    )

      $sig = @{
          contract_version = 'page_signature_contract_v1'
          candidates       = @($FlowResult.page.path)
          confidence       = 1.0
          source           = $Source
        reason           = if ($Source -eq 'automator_current_page_v1') { 'current_page_detected' } else { 'derived_from_page_state' }
        label            = $FlowResult.page.path
        family           = $FlowResult.page_validation.page_state_class
        kind             = $FlowResult.page_candidate_kind
        page_data_keys   = @()
        page_data_count  = 0
        page_elements    = @{}
          page_element_count = 0
          page_name        = $null
          page_understood  = $false
          is_valid         = $false
          issues           = @()
          semantic_status  = 'unknown'
          semantic_reason  = ''
      }

    if (-not $sig.source) {
        $sig.source = 'unknown'
    }
    if ($null -eq $sig.confidence -or $sig.confidence -lt 0 -or $sig.confidence -gt 1) {
        $sig.confidence = 0.0
    }
    if (-not $sig.candidates) {
        $sig.candidates = @()
    }
      if ($null -eq $sig.reason) {
          $sig.reason = ''
      }
      if (-not $sig.semantic_status) {
          $sig.semantic_status = 'unknown'
      }
      if ($null -eq $sig.semantic_reason) {
          $sig.semantic_reason = ''
      }

      $FlowResult.page_signature = $sig
      return $FlowResult
}

function Add-RuleContracts {
    param([hashtable]$FlowResult)

    $semanticKind = $FlowResult.page_validation.semantic_kind
    $rulePass = $semanticKind -eq 'page_outcome'
    $ruleReason = if ($rulePass) { 'valid_page_outcome' } elseif ($semanticKind -eq 'evidence_state') { 'evidence_state_not_page_outcome' } else { 'failure_state_not_page_outcome' }

    $FlowResult.rule_verdict = @{
        rule_id     = 'page-outcome-required-v1'
        rule_pass   = $rulePass
        rule_reason = $ruleReason
    }
    $FlowResult.rule_summary = @{
        rule_summary_status = if ($rulePass) { 'rule_pass' } else { 'rule_fail' }
        rule_summary_reason = $ruleReason
        rule_summary_level  = if ($rulePass) { 'pass' } else { 'warn' }
    }
    $FlowResult.rules_overview = @{
        total_rules         = 1
        passed_rules        = if ($rulePass) { 1 } else { 0 }
        failed_rules        = if ($rulePass) { 0 } else { 1 }
        overall_rule_status = if ($rulePass) { 'pass' } else { 'warn' }
    }
    return $FlowResult
}

function Add-ScenarioContracts {
    param([hashtable]$FlowResult)

    $FlowResult.validator_runtime = @{
        contract_version         = 'validator_runtime_v1'
        runtime_collect_evidence = 'ok'
        runtime_evaluate_rules   = if ($FlowResult.rule_verdict.rule_pass) { 'ok' } else { 'warn' }
    }
    return $FlowResult
}

function New-FlowResult {
    param(
        [ValidateSet('ok', 'skipped', 'failed')]
        [string]$Variant,
        [pscustomobject]$PageInfo,
        [string]$Source,
        [int]$ServicePort = 0,
        [int]$AutomatorPort = 0
    )

    $variantContract = Get-VariantContract -Variant $Variant
    $flow = @{
        contract_version = 'page_validation_contract_v2'
        exit_code        = $variantContract.exit_code
        page             = @{
            path  = $PageInfo.path
            query = $PageInfo.query
        }
        page_validation  = $variantContract.page_validation
        page_candidate   = $PageInfo.path
        page_candidate_kind = $variantContract.page_candidate_kind
        page_candidate_label = $PageInfo.path
        page_candidate_family = $variantContract.page_candidate_kind
        page_catalog_id  = $variantContract.page_catalog_id
        page_catalog_version = 'page_catalog_v1'
        page_catalog_label = $variantContract.page_catalog_label
        page_family_label = $variantContract.page_family_label
        interface_version = 'v1'
    }

    $flow = Set-PageValidationSignature -FlowResult $flow -Source $Source
    if ($ServicePort -gt 0) {
        $flow.devtools_port = [int]$ServicePort
    }
    if ($AutomatorPort -gt 0) {
        $flow.automator_port = [int]$AutomatorPort
    }
    if ($PageInfo.PSObject.Properties.Name -contains 'data_keys' -and $null -ne $PageInfo.data_keys) {
        $flow.page_signature.page_data_keys = @($PageInfo.data_keys)
    }
    if ($PageInfo.PSObject.Properties.Name -contains 'data_count' -and $null -ne $PageInfo.data_count) {
        $flow.page_signature.page_data_count = [int]$PageInfo.data_count
    }
    if ($PageInfo.PSObject.Properties.Name -contains 'elements_found' -and $null -ne $PageInfo.elements_found) {
        $flow.page_signature.page_elements = $PageInfo.elements_found
        $flow.page_signature.page_element_count = @($PageInfo.elements_found.Keys).Count
    }
    if ($PageInfo.PSObject.Properties.Name -contains 'page_name' -and $null -ne $PageInfo.page_name) {
        $flow.page_signature.page_name = $PageInfo.page_name
    }
    if ($PageInfo.PSObject.Properties.Name -contains 'page_understood') {
        $flow.page_signature.page_understood = [bool]$PageInfo.page_understood
    }
    if ($PageInfo.PSObject.Properties.Name -contains 'is_valid') {
        $flow.page_signature.is_valid = [bool]$PageInfo.is_valid
    }
      if ($PageInfo.PSObject.Properties.Name -contains 'issues' -and $null -ne $PageInfo.issues) {
          $flow.page_signature.issues = @($PageInfo.issues)
      }
      if (-not $flow.page_signature.page_understood) {
          $flow.page_signature.semantic_status = 'unknown'
          $flow.page_signature.semantic_reason = 'no_page_config'
      }
      elseif (-not $flow.page_signature.is_valid) {
          $flow.page_signature.semantic_status = 'invalid'
          $flow.page_signature.semantic_reason = if (@($flow.page_signature.issues).Count -gt 0) {
              @($flow.page_signature.issues)[0]
          }
          else {
              'page_semantic_invalid'
          }
      }
      else {
          $flow.page_signature.semantic_status = 'valid'
          $flow.page_signature.semantic_reason = if ($flow.page_signature.page_name) {
              "page:$($flow.page_signature.page_name)"
          }
          else {
              'page_semantic_valid'
          }
      }
      $flow = Add-RuleContracts -FlowResult $flow
      $flow = Add-ScenarioContracts -FlowResult $flow
      return $flow
}

function Invoke-FlowViaAutomator {
    [CmdletBinding()]
    param(
        [string]$ProjectPath = '',
        [ValidateSet('ok', 'skipped', 'failed')]
        [string]$Variant = 'ok'
    )

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $ProjectPath = Get-ReadonlyDefaultProjectPath
    }

    try {
        $servicePort = Get-WechatDevtoolsPort
        $automatorPort = Get-FreeAutomatorPort -ProjectPath $ProjectPath
        Write-Verbose "[AUTOMATOR] Service port: $servicePort"
        Write-Verbose "[AUTOMATOR] Automator port: $automatorPort"
        $pageInfo = Get-AutomatorPageInfo -ProjectPath $ProjectPath -AutoPort $automatorPort
        if ($null -eq $pageInfo) {
            Write-Verbose "[AUTOMATOR] Page probe unavailable, fallback."
            return Invoke-Flow -Variant $Variant
        }
        return (New-FlowResult `
            -Variant $Variant `
            -PageInfo $pageInfo `
            -Source 'automator_current_page_v1' `
            -ServicePort $servicePort `
            -AutomatorPort $automatorPort)
    }
    catch {
        Write-Verbose "[AUTOMATOR] Falling back to classic flow: $_"
        return Invoke-Flow -Variant $Variant
    }
}

function Invoke-Flow {
    [CmdletBinding()]
    param(
        [ValidateSet('ok', 'skipped', 'failed')]
        [string]$Variant = 'ok'
    )

    $fallbackPage = [pscustomobject]@{
        path  = 'pages/store/home/index'
        query = @{}
    }
    return (New-FlowResult -Variant $Variant -PageInfo $fallbackPage -Source 'page_state_class_mapping_v1')
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = if ($UseAutomator) {
        Invoke-FlowViaAutomator -Variant $Variant -Verbose:$VerbosePreference
    }
    else {
        Invoke-Flow -Variant $Variant -Verbose:$VerbosePreference
    }

    if ($AsJson) {
        $result | ConvertTo-Json -Depth 8
    }
    else {
        $result
    }
}
