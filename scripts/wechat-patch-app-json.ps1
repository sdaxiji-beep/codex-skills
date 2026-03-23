function Get-WechatAppJsonPatchTaskSlug {
    param(
        [Parameter(Mandatory)][string[]]$PagePaths
    )

    $normalized = $PagePaths | ForEach-Object {
        (($_.Trim().Trim('/') -replace '\\', '/') -replace '[^a-zA-Z0-9/_-]', '-') -replace '/+', '/'
    }
    $joined = ($normalized -join '--')
    return (($joined -replace '[\\/]+', '-').ToLowerInvariant())
}

function Invoke-WechatPatchAppJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Natural-language intent for app.json routing update, for example: 'register the about page in the route list'.")]
        [string]$Prompt,

        [Parameter(Mandatory = $true, HelpMessage = "One or more existing page paths, for example: 'pages/about/index'.")]
        [string[]]$PagePaths,

        [Parameter(Mandatory = $false)]
        [string]$TargetWorkspace = (Get-Location).Path
    )

    $normalizedPagePaths = @($PagePaths | ForEach-Object { $_.Trim().Trim('/') -replace '\\', '/' })
    if ($normalizedPagePaths.Count -eq 0) {
        throw 'PagePaths must include at least one page path.'
    }

    foreach ($pagePath in $normalizedPagePaths) {
        if ($pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
            throw "Page path must match 'pages/<page>/<entry>'. Actual: $pagePath"
        }
    }

    $taskRoot = Join-Path $TargetWorkspace '.agents\tasks'
    New-Item -ItemType Directory -Force -Path $taskRoot | Out-Null

    $taskSlug = Get-WechatAppJsonPatchTaskSlug -PagePaths $normalizedPagePaths
    $specPath = Join-Path $taskRoot ("app-json-patch-spec-{0}.md" -f $taskSlug)
    $patchPath = Join-Path $taskRoot ("app-json-patch-{0}.json" -f $taskSlug)

    $pagesSection = @('## Target Pages')
    foreach ($pagePath in $normalizedPagePaths) {
        $physicalPath = Join-Path $TargetWorkspace ("{0}.wxml" -f $pagePath)
        $exists = Test-Path $physicalPath
        $pagesSection += ("- {0} (exists: {1})" -f $pagePath, $(if ($exists) { 'yes' } else { 'no' }))
    }

    $specContent = (
        @(
        '# WeChat app.json Patch Spec',
        '',
        '## Intent',
        $Prompt,
        '',
        '## Workspace',
        $TargetWorkspace,
        ''
        ) +
        $pagesSection +
        @(
        '',
        '## Patch Contract',
        '- Return ONLY a single JSON object.',
        '- Allowed top-level field: append_pages',
        '- append_pages must be an array of page paths with no file extension.',
        '- Do not output files[], full app.json content, or any extra keys.',
        '',
        '## Output Target',
        ("Write the JSON patch to: {0}" -f $patchPath),
        '',
        '## Apply Command',
        '```powershell',
        '$RepoRoot = (Get-Location).Path',
        ("powershell -ExecutionPolicy Bypass -File (Join-Path `$RepoRoot ""scripts\wechat-apply-app-json-patch.ps1"") -JsonFilePath ""{0}"" -TargetWorkspace ""{1}""" -f $patchPath, $TargetWorkspace),
        '```',
        '',
        '## Retry Contract',
        '- Exit code 0: patch applied successfully.',
        '- Exit code 1: fix the exact validation errors, rewrite the same patch file, and run the apply command again.',
        '- Exit code 2: boundary violation. Abort instead of retrying.'
    )) -join [Environment]::NewLine

    Set-Content -Path $specPath -Value $specContent -Encoding UTF8

    return [pscustomobject]@{
        status            = 'success'
        prompt            = $Prompt
        page_paths        = $normalizedPagePaths
        target_workspace  = $TargetWorkspace
        task_root         = $taskRoot
        spec_path         = $specPath
        patch_path        = $patchPath
    }
}
