[CmdletBinding()]
param(
    [string]$Prompt = '',
    $Open = $false,
    $AsJson = $false,
    [string]$Output = 'object'
)

. "$PSScriptRoot\wechat.ps1"

function ConvertTo-McpPipelineBoolean {
    param(
        [Parameter(Mandatory)]$Value
    )

    if ($Value -is [bool]) {
        return $Value
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $false
    }

    switch ($text.Trim().ToLowerInvariant()) {
        'true' { return $true }
        '1' { return $true }
        'yes' { return $true }
        'on' { return $true }
        default { return $false }
    }
}

function Invoke-McpTaskPipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        $Open = $false
    )

    $normalizedPrompt = [string]$Prompt
    if ([string]::IsNullOrWhiteSpace($normalizedPrompt)) {
        return [pscustomobject]@{
            status = 'failed'
            reason = 'empty_prompt'
            project_path = ''
            acceptance_result = $null
            open_status = 'skipped'
            preview_status = 'skipped'
        }
    }

    $openFlag = ConvertTo-McpPipelineBoolean -Value $Open

    $translation = Invoke-WechatTaskTranslator -TaskText $normalizedPrompt
    if ([string]$translation.status -ne 'success') {
        return [pscustomobject]@{
            status = 'failed'
            reason = 'translator_failed'
            task_intent = ''
            task_family = ''
            route_mode = ''
            project_path = ''
            acceptance_result = $null
            open_status = 'skipped'
            preview_status = 'skipped'
        }
    }

    $compiled = Invoke-TaskSpecToBundle -TaskSpec $translation.task_spec
    if ([string]$compiled.status -ne 'success') {
        return [pscustomobject]@{
            status = 'failed'
            reason = 'compiler_failed'
            task_intent = [string]$translation.task_spec.task_intent
            task_family = [string]$translation.task_spec.task_family
            route_mode = [string]$translation.task_spec.route_mode
            project_path = ''
            acceptance_result = $null
            open_status = 'skipped'
            preview_status = 'skipped'
        }
    }

    $execution = Invoke-WechatTaskExecution `
        -TaskSpec $translation.task_spec `
        -PageBundle $compiled.page_bundle `
        -ComponentBundle $compiled.component_bundle `
        -AppPatch $compiled.app_patch `
        -Open $openFlag `
        -Preview $false

    $acceptanceResult = if ($execution.PSObject.Properties.Name -contains 'acceptance') {
        $execution.acceptance
    }
    elseif ($execution.PSObject.Properties.Name -contains 'acceptance_repair_loop' -and
        $null -ne $execution.acceptance_repair_loop -and
        $execution.acceptance_repair_loop.PSObject.Properties.Name -contains 'acceptance') {
        $execution.acceptance_repair_loop.acceptance
    }
    else {
        $null
    }

    return [pscustomobject]@{
        status = [string]$execution.status
        prompt = $normalizedPrompt
        task_intent = [string]$translation.task_spec.task_intent
        task_family = [string]$translation.task_spec.task_family
        route_mode = [string]$translation.task_spec.route_mode
        project_path = if ($execution.PSObject.Properties.Name -contains 'project_dir') { [string]$execution.project_dir } else { '' }
        bundle_sources = if ($compiled.PSObject.Properties.Name -contains 'bundle_sources') { $compiled.bundle_sources } else { $null }
        registry_hits = [pscustomobject]@{
            component = (($compiled.PSObject.Properties.Name -contains 'bundle_sources') -and [string]$compiled.bundle_sources.component -eq 'registry')
            page = (($compiled.PSObject.Properties.Name -contains 'bundle_sources') -and [string]$compiled.bundle_sources.page -eq 'registry')
        }
        acceptance_result = $acceptanceResult
        open_status = if ($execution.PSObject.Properties.Name -contains 'open_result') { [string]$execution.open_result.status } else { 'skipped' }
        preview_status = if ($execution.PSObject.Properties.Name -contains 'preview_result') { [string]$execution.preview_result.status } else { 'skipped' }
        reason = if ($execution.PSObject.Properties.Name -contains 'reason') { [string]$execution.reason } else { '' }
    }
}

if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
    $result = Invoke-McpTaskPipeline -Prompt $Prompt -Open $Open
    $outputJson = (ConvertTo-McpPipelineBoolean -Value $AsJson) -or ([string]$Output).Trim().ToLowerInvariant() -eq 'json'
    if ($outputJson) {
        $result | ConvertTo-Json -Depth 20 -Compress
    }
    else {
        $result
    }
}
