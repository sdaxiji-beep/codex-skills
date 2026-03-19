[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-build-from-prompt.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"

function Invoke-WechatCreate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$OutputDir = '',
        [bool]$Open = $true,
        [bool]$Preview = $true,
        [bool]$RunFastGate = $false,
        [bool]$RequireConfirm = $false
    )

    $build = Invoke-WechatBuildFromPrompt -Prompt $Prompt -OutputDir $OutputDir -AutoPreview $false
    if ($build.status -ne 'success') {
        return @{
            status      = 'failed'
            stage       = 'build'
            prompt      = $Prompt
            reason      = if ($build.reason) { $build.reason } else { 'build_failed' }
            template    = $build.template
            project_dir = $build.project_dir
        }
    }

    $projectDir = $build.project_dir
    $openResult = @{ status = 'skipped' }
    if ($Open) {
        $openResult = Invoke-GeneratedProjectOpen -ProjectPath $projectDir
    }

    $fastGate = @{
        status  = 'skipped'
        success = $null
    }
    if ($RunFastGate) {
        $testScript = Join-Path $PSScriptRoot 'test-wechat-skill.ps1'
        $output = & powershell -ExecutionPolicy Bypass -File $testScript -SkipSmoke -Tag fast 2>&1 | Out-String
        $isSuccess = $output -match '"success"\s*:\s*true'
        $fastGate = @{
            status     = if ($isSuccess) { 'passed' } else { 'failed' }
            success    = $isSuccess
            raw_output = $output
        }
    }

    $previewResult = @{ status = 'skipped' }
    if ($Preview) {
        $previewResult = Invoke-GeneratedProjectPreview -ProjectPath $projectDir -RequireConfirm $RequireConfirm
    }

    return @{
        status         = 'success'
        prompt         = $Prompt
        template       = $build.template
        project_dir    = $projectDir
        open_status    = if ($openResult.status) { $openResult.status } else { 'unknown' }
        fast_gate      = $fastGate
        preview_status = if ($previewResult.status) { $previewResult.status } else { 'unknown' }
        preview_result = $previewResult
    }
}

