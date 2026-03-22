function Get-WechatComponentGenerationTaskSlug {
    param(
        [Parameter(Mandatory)][string]$ComponentPath
    )

    $trimmed = $ComponentPath.Trim().Trim('/')
    $safe = ($trimmed -replace '[^a-zA-Z0-9/_-]', '-') -replace '/+', '/'
    return ($safe -replace '[\\/]+', '-').ToLowerInvariant()
}

function Get-WechatComponentNameFromPath {
    param(
        [Parameter(Mandatory)][string]$ComponentPath
    )

    return (($ComponentPath -split '/')[1]).ToLowerInvariant()
}

function Invoke-WechatGenerateComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Component requirement, for example: 'a product card with price, tag, and CTA button'.")]
        [string]$Prompt,

        [Parameter(Mandatory = $true, HelpMessage = "Target component path, for example: 'components/product-card/index'.")]
        [string]$ComponentPath,

        [Parameter(Mandatory = $false)]
        [string]$TargetWorkspace = (Get-Location).Path
    )

    $normalizedComponentPath = $ComponentPath.Trim().Trim('/') -replace '\\', '/'
    if ($normalizedComponentPath -notmatch '^components/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        throw "ComponentPath must match 'components/<component>/index'. Actual: $ComponentPath"
    }

    $entryName = ($normalizedComponentPath -split '/')[2]
    if ($entryName -ne 'index') {
        throw "ComponentPath entry file must be 'index'. Actual: $ComponentPath"
    }

    $taskRoot = Join-Path $TargetWorkspace '.agents\tasks'
    New-Item -ItemType Directory -Force -Path $taskRoot | Out-Null

    $taskSlug = Get-WechatComponentGenerationTaskSlug -ComponentPath $normalizedComponentPath
    $componentName = Get-WechatComponentNameFromPath -ComponentPath $normalizedComponentPath
    $specPath = Join-Path $taskRoot ("COMPONENT_SPEC_{0}.md" -f ($componentName -replace '[^a-zA-Z0-9_-]', '_').ToUpperInvariant())
    $bundlePath = Join-Path $taskRoot ("component-generation-bundle-{0}.json" -f $taskSlug)

    $specContent = @(
        '# WeChat Component Generation Spec',
        '',
        '## Target Component',
        ("Path: {0}" -f $normalizedComponentPath),
        ("ComponentName: {0}" -f $componentName),
        ("Workspace: {0}" -f $TargetWorkspace),
        '',
        '## Requirement',
        $Prompt,
        '',
        '## Output Contract',
        ("- Generate component-level files only for {0}." -f $normalizedComponentPath),
        ("- Return a single JSON bundle written to: {0}" -f $bundlePath),
        '- Include component_name and files[].',
        '- Allowed files are:',
        ("  - {0}.wxml" -f $normalizedComponentPath),
        ("  - {0}.js" -f $normalizedComponentPath),
        ("  - {0}.wxss" -f $normalizedComponentPath),
        ("  - {0}.json" -f $normalizedComponentPath),
        '',
        '## Component Rules',
        '- JSON config must include component=true.',
        '- JS must use Component({ ... }) and declare properties.',
        '- Do not modify pages/, app.*, project.config.json, scripts/, or templates/.',
        '',
        '## Apply Command',
        '```powershell',
        '$RepoRoot = (Get-Location).Path',
        ("powershell -ExecutionPolicy Bypass -File (Join-Path `$RepoRoot ""scripts\wechat-apply-component-bundle.ps1"") -JsonFilePath ""{0}"" -TargetWorkspace ""{1}""" -f $bundlePath, $TargetWorkspace),
        '```',
        '',
        '## Retry Contract',
        '- Exit code 0: apply succeeded.',
        '- Exit code 1: read stderr, fix every listed validation error, rewrite the JSON bundle, and run the apply command again.',
        '- Exit code 2: component sandbox boundary violation. Abort and inform the user instead of retrying.'
    ) -join [Environment]::NewLine

    Set-Content -Path $specPath -Value $specContent -Encoding UTF8

    return [pscustomobject]@{
        status           = 'success'
        prompt           = $Prompt
        component_path   = $normalizedComponentPath
        component_name   = $componentName
        target_workspace = $TargetWorkspace
        task_root        = $taskRoot
        spec_path        = $specPath
        bundle_path      = $bundlePath
    }
}
