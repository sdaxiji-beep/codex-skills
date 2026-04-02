[CmdletBinding()]
param()

function Get-AutoFixProbeScriptPath {
    return Join-Path (Split-Path $PSScriptRoot -Parent) 'probe-automator.js'
}

function Invoke-AutoFixLoop {
    param(
        [string]$ProjectPath,
        [int]$MaxRounds = 3,
        [bool]$RequireConfirm = $true,
        [string]$TestSuitePath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\\test-wechat-skill.ps1')"
    )

    Write-Host "[AUTOFIX] Starting auto-fix loop, max rounds: $MaxRounds"

    for ($round = 1; $round -le $MaxRounds; $round++) {
        Write-Host "[AUTOFIX] Round $round"
        Write-Host '[AUTOFIX] Running validation...'

        $output = & powershell -ExecutionPolicy Bypass -File $TestSuitePath -SkipSmoke 2>&1 | Out-String
        $failures = @()
        $parsedSummary = $null
        $success = $false
        $passed = 0
        $failed = 0

        # Collect any JSON blocks from raw output (brace-balanced parser).
        $jsonBlocks = @()
        $depth = 0
        $inString = $false
        $escape = $false
        $buffer = New-Object System.Text.StringBuilder

        foreach ($ch in $output.ToCharArray()) {
            if ($escape) {
                $escape = $false
                if ($depth -gt 0) { [void]$buffer.Append($ch) }
                continue
            }

            if ($ch -eq '\') {
                $escape = $true
                if ($depth -gt 0) { [void]$buffer.Append($ch) }
                continue
            }

            if ($ch -eq '"') {
                $inString = -not $inString
                if ($depth -gt 0) { [void]$buffer.Append($ch) }
                continue
            }

            if (-not $inString) {
                if ($ch -eq '{') {
                    if ($depth -eq 0) { [void]$buffer.Clear() }
                    $depth++
                }
                elseif ($ch -eq '}') {
                    $depth--
                }
            }

            if ($depth -gt 0) { [void]$buffer.Append($ch) }

            if ($depth -eq 0 -and $buffer.Length -gt 0) {
                $blockText = $buffer.ToString()
                try {
                    $jsonBlocks += ($blockText | ConvertFrom-Json -ErrorAction Stop)
                }
                catch {
                }
                [void]$buffer.Clear()
            }
        }

        if ($jsonBlocks.Count -eq 0) {
            # Fallback: find the last line that starts a JSON block and parse to end.
            $lines = $output -split "`n"
            $startIndex = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].Trim() -match '^\{') {
                    $startIndex = $i
                }
            }
            if ($startIndex -ge 0) {
                $candidate = ($lines[$startIndex..($lines.Count - 1)] -join "`n")
                try {
                    $jsonBlocks += ($candidate | ConvertFrom-Json -ErrorAction Stop)
                }
                catch {
                }
            }
        }

        if ($jsonBlocks.Count -eq 0) {
            # Fallback: extract the last full JSON object around the test summary.
            $modeIndex = $output.LastIndexOf('"mode"')
            if ($modeIndex -ge 0) {
                $start = $output.LastIndexOf('{', $modeIndex)
                $end = $output.LastIndexOf('}')
                if ($start -ge 0 -and $end -gt $start) {
                    $candidate = $output.Substring($start, $end - $start + 1)
                    try {
                        $jsonBlocks += ($candidate | ConvertFrom-Json -ErrorAction Stop)
                    }
                    catch {
                    }
                }
            }
        }

        foreach ($json in $jsonBlocks) {
            if ($json.PSObject.Properties.Name -contains 'success') {
                $success = [bool]$json.success
            }
            if ($json.PSObject.Properties.Name -contains 'passed') {
                $passed = [int]$json.passed
            }
            if ($json.PSObject.Properties.Name -contains 'failed') {
                $failed = [int]$json.failed
            }
        }

        if (-not $success) {
            if ($output -match '"success"\s*:\s*true') {
                $success = $true
            }
            elseif ($output -match 'success\s*=\s*true') {
                $success = $true
            }
            if ($output -match '"passed"\s*:\s*(\d+)') {
                $passed = [int]$Matches[1]
            }
            elseif ($output -match 'passed\s*=\s*(\d+)') {
                $passed = [int]$Matches[1]
            }
            if ($output -match '"failed"\s*:\s*(\d+)') {
                $failed = [int]$Matches[1]
            }
            elseif ($output -match 'failed\s*=\s*(\d+)') {
                $failed = [int]$Matches[1]
            }
        }

        if ($success) {
            Write-Host "[AUTOFIX] Validation passed, no fix needed. (passed=$passed failed=$failed)"
            return @{
                status  = 'success'
                rounds  = $round
                message = 'validation passed'
            }
        }

        foreach ($json in $jsonBlocks) {
            if ($json.results) {
                $failedItems = $json.results |
                    Where-Object { $_.PSObject.Properties.Name -contains 'pass' -and -not $_.pass } |
                    ForEach-Object { '{0}: {1}' -f $_.name, $_.output }
                if ($failedItems) { $failures += $failedItems }
            }

            if ($json.PSObject.Properties.Name -contains 'pass' -and $json.pass -eq $false) {
                $msg = if ($json.error) { $json.error }
                elseif ($json.reason) { $json.reason }
                elseif ($json.test) { "$($json.test) failed" }
                else { $json | ConvertTo-Json -Compress }
                $failures += $msg
            }
        }

        if (-not $failures -or $failures.Count -eq 0) {
            $failures = @('Validation failed - check artifacts/autofix-report-round*.json')
        }

        $pageState = $null
        try {
            $probeScript = Get-AutoFixProbeScriptPath
            $probeRaw = (& node $probeScript 2>$null | Out-String).Trim()
            if ($probeRaw) {
                $pageState = $probeRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
            }
        }
        catch {
        }

        $pageContext = @{
            path            = $null
            page_name       = $null
            page_understood = $false
            is_valid        = $false
            issues          = @()
            data_keys       = @()
            page_elements   = @{}
            validation      = @{}
            data_count      = 0
            element_count   = 0
            semantic_status = 'unknown'
            semantic_reason = ''
        }

        if ($null -ne $pageState) {
            if ($pageState.PSObject.Properties.Name -contains 'path') { $pageContext.path = $pageState.path }
            if ($pageState.PSObject.Properties.Name -contains 'page_name') { $pageContext.page_name = $pageState.page_name }
            if ($pageState.PSObject.Properties.Name -contains 'page_understood') { $pageContext.page_understood = [bool]$pageState.page_understood }
            if ($pageState.PSObject.Properties.Name -contains 'is_valid') { $pageContext.is_valid = [bool]$pageState.is_valid }
            if ($pageState.PSObject.Properties.Name -contains 'issues' -and $null -ne $pageState.issues) { $pageContext.issues = @($pageState.issues) }
            if ($pageState.PSObject.Properties.Name -contains 'data_keys' -and $null -ne $pageState.data_keys) { $pageContext.data_keys = @($pageState.data_keys) }
            if ($pageState.PSObject.Properties.Name -contains 'page_elements' -and $null -ne $pageState.page_elements) { $pageContext.page_elements = $pageState.page_elements }
            if ($pageState.PSObject.Properties.Name -contains 'validation' -and $null -ne $pageState.validation) { $pageContext.validation = $pageState.validation }
            $pageContext.data_count = @($pageContext.data_keys).Count
            if ($pageContext.page_elements -is [System.Collections.IDictionary]) {
                $pageContext.element_count = @($pageContext.page_elements.Keys).Count
            }
            if ($pageState.PSObject.Properties.Name -contains 'semantic_status' -and $null -ne $pageState.semantic_status) { $pageContext.semantic_status = [string]$pageState.semantic_status }
            if ($pageState.PSObject.Properties.Name -contains 'semantic_reason' -and $null -ne $pageState.semantic_reason) { $pageContext.semantic_reason = [string]$pageState.semantic_reason }
        }

        $fixHint = if ($pageContext.semantic_status -eq 'invalid' -and $pageContext.semantic_reason) {
            "Page semantic invalid: $($pageContext.semantic_reason)"
        }
        elseif ($pageContext.semantic_status -eq 'unknown' -and $pageContext.semantic_reason) {
            "Page semantic unknown: $($pageContext.semantic_reason)"
        }
        elseif ($pageContext.issues -and @($pageContext.issues).Count -gt 0) {
            "Page issues: $(@($pageContext.issues) -join '; ')"
        }
        elseif ($failures -and @($failures).Count -gt 0) {
            "Test failures: $(@($failures) -join '; ')"
        }
        else {
            'Validation failed, check report.'
        }
        Write-Host '[AUTOFIX] Failures found:'
        $failures | ForEach-Object { Write-Host "  $_" }

        $report = @{
            round        = $round
            passed       = $false
            failures     = $failures
            page_context = $pageContext
            fix_hint     = $fixHint
            raw          = $output
        }

        $reportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "artifacts\autofix-report-round$round.json"
        New-Item -ItemType Directory -Force -Path (Split-Path $reportPath) | Out-Null
        $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8

        Write-Host "[AUTOFIX] Fix hint: $fixHint"
        Write-Host "[AUTOFIX] Report written: $reportPath"
        Write-Host '[AUTOFIX] Apply a fix, then continue.'

        if ($RequireConfirm) {
            Write-Host "[AUTOFIX] Type continue to proceed or stop to exit:"
            $input = Read-Host
            if ($input -ne 'continue') {
                return @{
                    status = 'stopped'
                    rounds = $round
                }
            }
        }
        else {
            return @{
                status   = 'needs_fix'
                round    = $round
                failures = $failures
                report   = $reportPath
            }
        }
    }

    return @{
        status = 'max_rounds_reached'
        rounds = $MaxRounds
    }
}



