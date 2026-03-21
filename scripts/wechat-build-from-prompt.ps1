function Get-BuildTemplateMap {
    $mapPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\template-map.json'
    if (-not (Test-Path $mapPath)) {
        return @{
            default = 'notebook'
            templates = @(
                @{ name = 'notebook'; keywords = @('note', 'notebook') },
                @{ name = 'todo'; keywords = @('todo', 'task') },
                @{ name = 'shoplist'; keywords = @('shop', 'list') }
            )
        }
    }

    return (Get-Content $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Resolve-BuildTemplateFromPrompt {
    param([Parameter(Mandatory)][string]$Prompt)

    $cnNotebookKeywords = @(
        ([string][char]0x8BB0 + [char]0x4E8B), # Chinese: notebook
        ([string][char]0x7B14 + [char]0x8BB0)  # Chinese: note
    )
    $cnTodoKeywords = @(
        ([string][char]0x5F85 + [char]0x529E), # Chinese: todo
        ([string][char]0x6E05 + [char]0x5355)  # Chinese: list
    )
    $cnShopKeywords = @(
        ([string][char]0x5546 + [char]0x54C1), # Chinese: goods
        ([string][char]0x5217 + [char]0x8868)  # Chinese: list
    )

    if ($cnNotebookKeywords | Where-Object { $Prompt.Contains($_) }) {
        return 'notebook'
    }
    if ($cnTodoKeywords | Where-Object { $Prompt.Contains($_) }) {
        return 'todo'
    }
    if ($cnShopKeywords | Where-Object { $Prompt.Contains($_) }) {
        return 'shoplist'
    }

    $map = Get-BuildTemplateMap
    foreach ($tpl in @($map.templates)) {
        foreach ($kw in @($tpl.keywords)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$kw) -and $Prompt -match [Regex]::Escape([string]$kw)) {
                return [string]$tpl.name
            }
        }
    }

    return [string]$map.default
}

function Invoke-WechatBuildFromPrompt {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$OutputDir = '',
        [bool]$AutoPreview = $false
    )

    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'generated'
    }

    Write-Host '=== Requirement ==='
    Write-Host "Prompt: $Prompt"

    $template = Resolve-BuildTemplateFromPrompt -Prompt $Prompt
    Write-Host "Template: $template"

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $suffix = ([guid]::NewGuid().ToString('N')).Substring(0, 6)
    $projectDir = Join-Path $OutputDir "$template-$timestamp-$suffix"
    $templateDir = Join-Path (Split-Path $PSScriptRoot -Parent) "templates\$template"

    if (-not (Test-Path $templateDir)) {
        Write-Host "Build failed: template not found: $templateDir"
        return @{
            status     = 'failed'
            reason     = 'template_not_found'
            template   = $template
            project_dir = $projectDir
        }
    }

    New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
    Copy-Item "$templateDir\*" $projectDir -Recurse -Force
    Write-Host "Project generated: $projectDir"

    $spec = @{
        task = @{
            id    = "gen-$timestamp"
            title = $Prompt
            type  = 'generate'
        }
        target = @{
            project_dir = $projectDir
            template    = $template
        }
        generated_at = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    $spec | ConvertTo-Json -Depth 8 |
        Set-Content "$projectDir\build-spec.json" -Encoding UTF8

    $previewStatus = 'skipped'
    if ($AutoPreview) {
        . "$PSScriptRoot\wechat-get-port.ps1"
        . "$PSScriptRoot\wechat-deploy.ps1"
        $port = Get-WechatDevtoolsPort
        $rawResult = Invoke-WechatCliCommand -Arguments @(
            'preview',
            '--project', $projectDir,
            '--port', [string]$port
        )
        $previewStatus = if ($rawResult.success) { 'success' } else { 'failed' }
        Write-Host "Preview: $previewStatus"
    }

    Write-Host '=== Done ==='
    Write-Host "Project path: $projectDir"
    Write-Host 'Next: import this folder in WeChat DevTools or run preview manually.'

    return @{
        status      = 'success'
        template    = $template
        project_dir = $projectDir
        spec        = $spec
        preview     = $previewStatus
        preview_status = $previewStatus
    }
}
