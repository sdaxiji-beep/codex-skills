function Get-WechatPageGenerationTaskSlug {
    param(
        [Parameter(Mandatory)][string]$PagePath
    )

    $trimmed = $PagePath.Trim().Trim('/')
    $safe = ($trimmed -replace '[^a-zA-Z0-9/_-]', '-') -replace '/+', '/'
    return ($safe -replace '[\\/]+', '-').ToLowerInvariant()
}

function Get-WechatAvailablePageComponentList {
    param(
        [Parameter(Mandatory)][string]$TargetWorkspace
    )

    $componentsRoot = Join-Path $TargetWorkspace 'components'
    if (-not (Test-Path $componentsRoot)) {
        return @()
    }

    return Get-ChildItem -Path $componentsRoot -Directory | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            tag = $_.Name
            import_path = "/components/$($_.Name)/index"
        }
    }
}

function Invoke-WechatGeneratePage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Page requirement, for example: 'a todo page with pull to refresh and inline delete'.")]
        [string]$Prompt,

        [Parameter(Mandatory = $true, HelpMessage = "Target page path, for example: 'pages/todo/index'.")]
        [string]$PagePath,

        [Parameter(Mandatory = $false)]
        [string]$TargetWorkspace = (Get-Location).Path
    )

    $normalizedPagePath = $PagePath.Trim().Trim('/') -replace '\\', '/'
    if ($normalizedPagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        throw "PagePath must match 'pages/<page>/<entry>'. Actual: $PagePath"
    }

    $taskRoot = Join-Path $TargetWorkspace '.agents\tasks'
    New-Item -ItemType Directory -Force -Path $taskRoot | Out-Null

    $taskSlug = Get-WechatPageGenerationTaskSlug -PagePath $normalizedPagePath
    $pageName = (($normalizedPagePath -split '/')[1]).ToLowerInvariant()
    $specPath = Join-Path $taskRoot ("page-generation-spec-{0}.md" -f $taskSlug)
    $bundlePath = Join-Path $taskRoot ("page-generation-bundle-{0}.json" -f $taskSlug)
    $availableComponents = @(Get-WechatAvailablePageComponentList -TargetWorkspace $TargetWorkspace)

    $componentSection = @('## Available Custom Components')
    if ($availableComponents.Count -eq 0) {
        $componentSection += '- None. Do not register or use custom components in this page bundle.'
    }
    else {
        $componentSection += '- You may use the following existing components.'
        $componentSection += '- If you use one, register the exact import path in usingComponents and use the exact tag in WXML.'
        foreach ($component in $availableComponents) {
            $componentSection += ("- <{0}> -> {1}" -f $component.tag, $component.import_path)
        }
    }

    $specContent = (
        @(
        '# WeChat Page Generation Spec',
        '',
        '## Target Page',
        ("Path: {0}" -f $normalizedPagePath),
        ("PageName: {0}" -f $pageName),
        ("Workspace: {0}" -f $TargetWorkspace),
        '',
        '## Requirement',
        $Prompt,
        ''
        ) +
        $componentSection +
        @(
        '',
        '## Output Contract',
        ("- Generate page-level files only for {0}." -f $normalizedPagePath),
        ("- Return a single JSON bundle written to: {0}" -f $bundlePath),
        '- Include page_name and files[].',
        '- Allowed files are:',
        ("  - {0}.wxml" -f $normalizedPagePath),
        ("  - {0}.js" -f $normalizedPagePath),
        ("  - {0}.wxss" -f $normalizedPagePath),
        ("  - {0}.json" -f $normalizedPagePath),
        '',
        '## Apply Command',
        '```powershell',
        '$RepoRoot = (Get-Location).Path',
        ("powershell -ExecutionPolicy Bypass -File (Join-Path `$RepoRoot ""scripts\wechat-apply-bundle.ps1"") -JsonFilePath ""{0}"" -TargetWorkspace ""{1}""" -f $bundlePath, $TargetWorkspace),
        '```',
        '',
        '## Retry Contract',
        '- Exit code 0: apply succeeded.',
        '- Exit code 1: read stderr, fix every listed validation error, rewrite the JSON bundle, and run the apply command again.',
        '- Exit code 2: sandbox boundary violation. Abort and inform the user instead of retrying.'
    )) -join [Environment]::NewLine

    Set-Content -Path $specPath -Value $specContent -Encoding UTF8

    return [pscustomobject]@{
        status           = 'success'
        prompt           = $Prompt
        page_path        = $normalizedPagePath
        page_name        = $pageName
        target_workspace = $TargetWorkspace
        task_root        = $taskRoot
        spec_path        = $specPath
        bundle_path      = $bundlePath
    }
}
