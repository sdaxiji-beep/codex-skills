. "$PSScriptRoot\wechat-build-from-prompt.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"
. "$PSScriptRoot\Write-AtomicJsonCache.ps1"

function Get-P3OperationalFixturesFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $roots = @(
        (Join-Path $RepoRoot 'scripts\wechat-build-from-prompt.ps1'),
        (Join-Path $RepoRoot 'scripts\wechat-generated-project.ps1'),
        (Join-Path $RepoRoot 'scripts\wechat-mcp-tool-boundary.ps1'),
        (Join-Path $RepoRoot 'scripts\wechat-readonly-flow.ps1'),
        (Join-Path $RepoRoot 'scripts\test-common.ps1'),
        (Join-Path $RepoRoot 'templates\template-map.json'),
        (Join-Path $RepoRoot 'templates\notebook'),
        (Join-Path $RepoRoot 'templates\todo'),
        (Join-Path $RepoRoot 'templates\shoplist')
    )

    $entries = New-Object System.Collections.Generic.List[string]
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) {
            continue
        }

        $item = Get-Item $root -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            continue
        }

        if (-not $item.PSIsContainer) {
            $entries.Add(('{0}|{1}' -f $item.FullName.ToLowerInvariant(), $item.LastWriteTimeUtc.Ticks))
            continue
        }

        Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\(artifacts|sandbox|node_modules)\\'
            } |
            ForEach-Object {
                $entries.Add(('{0}|{1}' -f $_.FullName.ToLowerInvariant(), $_.LastWriteTimeUtc.Ticks))
            }
    }

    $hashInput = ($entries | Sort-Object) -join "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SharedP3OperationalFixtures {
    param(
        [string]$RepoRoot,
        [switch]$ForceRefresh
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
    }

    $fixturesRoot = Join-Path $RepoRoot 'artifacts\wechat-devtools\p3-operational-fixtures'
    $cachePath = Join-Path $fixturesRoot 'shared-fixtures-cache.json'
    $boundaryWorkspace = Join-Path $fixturesRoot 'mcp-boundary'
    $boundaryPayloadPath = Join-Path $boundaryWorkspace 'page-bundle.json'
    $externalTasksDir = Join-Path $boundaryWorkspace '.agents\tasks'
    $externalPayloadPath = Join-Path $externalTasksDir 'bundle_page_home.json'
    $generatedRoot = Join-Path $RepoRoot 'generated\p3-shared-fixtures'

    function Normalize-SharedNotebookProject {
        param(
            [Parameter(Mandatory = $true)]
            [string]$ProjectPath
        )

        if (-not (Test-Path $ProjectPath)) {
            return $null
        }

        $metadata = Get-GeneratedProjectMetadata -ProjectPath $ProjectPath
        if (
            [string]::Equals($metadata.appid, 'touristappid', [System.StringComparison]::OrdinalIgnoreCase) -and
            [string]::Equals($metadata.projectname, 'notebook-app', [System.StringComparison]::OrdinalIgnoreCase)
        ) {
            return @{
                status = 'success'
                project_dir = $ProjectPath
                appid = $metadata.appid
                projectname = $metadata.projectname
                template = $metadata.template
                preview = 'skipped'
                preview_status = 'skipped'
            }
        }

        $normalized = Invoke-GeneratedProjectSetAppId `
            -ProjectPath $ProjectPath `
            -AppId 'touristappid' `
            -ProjectName 'notebook-app' `
            -RequireConfirm $false

        return $normalized
    }

    function Resolve-SharedTemplateProject {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Prompt,
            [Parameter(Mandatory = $true)]
            [string]$GeneratedRoot,
            [string]$NormalizeMode = ''
        )

        $result = Invoke-WechatBuildFromPrompt -Prompt $Prompt -OutputDir $GeneratedRoot -AutoPreview $false
        if ($null -eq $result -or [string]::IsNullOrWhiteSpace([string]$result.project_dir)) {
            throw "failed to prepare shared template fixture for prompt: $Prompt"
        }

        if ([string]::Equals($NormalizeMode, 'notebook', [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = Normalize-SharedNotebookProject -ProjectPath ([string]$result.project_dir)
        }

        if ($null -eq $result) {
            throw "failed to normalize shared template fixture for prompt: $Prompt"
        }

        return $result
    }

    function New-EligibleNotebookProject {
        param(
            [Parameter(Mandatory = $true)]
            [pscustomobject]$NotebookProject,
            [Parameter(Mandatory = $true)]
            [string]$GeneratedRoot
        )

        $eligibleRoot = Join-Path $GeneratedRoot 'notebook-eligible'
        if (Test-Path $eligibleRoot) {
            Remove-Item -Path $eligibleRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        New-Item -ItemType Directory -Path $eligibleRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $NotebookProject.project_dir '*') -Destination $eligibleRoot -Recurse -Force

        $eligible = Invoke-GeneratedProjectSetAppId `
            -ProjectPath $eligibleRoot `
            -AppId 'wx1234567890abcdef' `
            -ProjectName 'generated-notebook' `
            -RequireConfirm $false

        if ($null -eq $eligible -or $eligible.status -ne 'success') {
            throw "failed to prepare eligible shared notebook fixture"
        }

        return [pscustomobject]@{
            status = $eligible.status
            project_dir = $eligible.project_dir
            appid = $eligible.appid
            projectname = $eligible.projectname
            template = $eligible.template
            preview = 'skipped'
            preview_status = 'skipped'
        }
    }

    $boundaryPayload = @'
{
  "page_name": "about",
  "files": [
    { "path": "pages/about/index.wxml", "content": "<view><text>About</text></view>" },
    { "path": "pages/about/index.js", "content": "Page({ data: {}, onLoad() {} })" },
    { "path": "pages/about/index.wxss", "content": ".container { padding: 20rpx; }" },
    { "path": "pages/about/index.json", "content": "{ \"usingComponents\": {} }" }
  ]
}
'@
    $externalPayload = @'
{
  "page_name": "home",
  "files": [
    { "path": "pages/home/index.wxml", "content": "<view class=\"container\"><text>Home</text></view>" },
    { "path": "pages/home/index.js", "content": "Page({ data: {}, onLoad() {} })" },
    { "path": "pages/home/index.wxss", "content": ".container { padding: 24rpx; }" },
    { "path": "pages/home/index.json", "content": "{ \"usingComponents\": {} }" }
  ]
}
'@

    $fingerprint = Get-P3OperationalFixturesFingerprint -RepoRoot $RepoRoot

    if (-not $ForceRefresh -and (Test-Path $cachePath)) {
        try {
            $cached = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            if ($cached.fingerprint -eq $fingerprint) {
                $cachedBoundaryWorkspace = [string]$cached.boundary_workspace
                $cachedBoundaryPayloadPath = [string]$cached.boundary_payload_path
                $cachedExternalWorkspace = [string]$cached.external_workspace
                $cachedExternalPayloadPath = [string]$cached.external_payload_path
                $cachedGeneratedProject = $cached.generated_project
                $cachedDescribeContract = $cached.describe_contract
                $cachedExecutionProfile = $cached.execution_profile
                $cachedGeneratedTodoProject = $cached.generated_todo_project
                $cachedGeneratedShoplistProject = $cached.generated_shoplist_project
                $cachedGeneratedNotebookEligibleProject = $cached.generated_notebook_eligible_project
                $cachedBoundaryContracts = $cached.boundary_contracts

                if (
                    (Test-Path $cachedBoundaryWorkspace) -and
                    (Test-Path $cachedBoundaryPayloadPath) -and
                    (Test-Path $cachedExternalWorkspace) -and
                    (Test-Path $cachedExternalPayloadPath) -and
                    $null -ne $cachedGeneratedProject -and
                    (Test-Path $cachedGeneratedProject.project_dir) -and
                    $null -ne $cachedDescribeContract -and
                    $null -ne $cachedExecutionProfile -and
                    $null -ne $cachedBoundaryContracts
                ) {
                    $cachedNotebookAppId = [string]$cachedGeneratedProject.appid
                    $cachedNotebookProjectName = [string]$cachedGeneratedProject.projectname

                    if (
                        [string]::Equals($cachedNotebookAppId, 'touristappid', [System.StringComparison]::OrdinalIgnoreCase) -and
                        [string]::Equals($cachedNotebookProjectName, 'notebook-app', [System.StringComparison]::OrdinalIgnoreCase)
                    ) {
                        if (
                            $null -eq $cachedGeneratedNotebookEligibleProject -or
                            -not (Test-Path $cachedGeneratedNotebookEligibleProject.project_dir)
                        ) {
                            $cachedGeneratedNotebookEligibleProject = New-EligibleNotebookProject `
                                -NotebookProject ([pscustomobject]$cachedGeneratedProject) `
                                -GeneratedRoot $generatedRoot
                        }

                        return [pscustomobject]@{
                            fingerprint = $fingerprint
                            fromCache = $true
                            cachePath = $cachePath
                            boundaryWorkspace = $cachedBoundaryWorkspace
                            boundaryPayloadPath = $cachedBoundaryPayloadPath
                            externalWorkspace = $cachedExternalWorkspace
                            externalPayloadPath = $cachedExternalPayloadPath
                            generatedNotebookProject = [pscustomobject]$cachedGeneratedProject
                            generatedNotebookEligibleProject = if ($null -ne $cachedGeneratedNotebookEligibleProject -and (Test-Path $cachedGeneratedNotebookEligibleProject.project_dir)) { [pscustomobject]$cachedGeneratedNotebookEligibleProject } else { $null }
                            generatedTodoProject = if ($null -ne $cachedGeneratedTodoProject -and (Test-Path $cachedGeneratedTodoProject.project_dir)) { [pscustomobject]$cachedGeneratedTodoProject } else { $null }
                            generatedShoplistProject = if ($null -ne $cachedGeneratedShoplistProject -and (Test-Path $cachedGeneratedShoplistProject.project_dir)) { [pscustomobject]$cachedGeneratedShoplistProject } else { $null }
                            describeContract = $cachedDescribeContract
                            executionProfile = $cachedExecutionProfile
                            boundaryContracts = $cachedBoundaryContracts
                        }
                    }
                }
            }
        }
        catch {
        }
    }

    New-Item -ItemType Directory -Path $fixturesRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $boundaryWorkspace -Force | Out-Null
    New-Item -ItemType Directory -Path $externalTasksDir -Force | Out-Null
    New-Item -ItemType Directory -Path $generatedRoot -Force | Out-Null

    [System.IO.File]::WriteAllText($boundaryPayloadPath, $boundaryPayload, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText($externalPayloadPath, $externalPayload, (New-Object System.Text.UTF8Encoding($false)))

    $boundaryScript = Join-Path $RepoRoot 'scripts\wechat-mcp-tool-boundary.ps1'
    $describeContract = & $boundaryScript -Operation describe_contract | ConvertFrom-Json
    $executionProfile = & $boundaryScript -Operation describe_execution_profile | ConvertFrom-Json
    $boundaryPageValidate = & $boundaryScript -Operation validate_page_bundle -JsonPayload $boundaryPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $boundaryComponentPayload = @'
{
  "component_name": "cta-button",
  "files": [
    { "path": "components/cta-button/index.wxml", "content": "<view><button>{{text}}</button></view>" },
    { "path": "components/cta-button/index.js", "content": "Component({ properties: { text: { type: String, value: 'Click' } }, data: {}, methods: {} })" },
    { "path": "components/cta-button/index.wxss", "content": ".wrap { padding: 20rpx; }" },
    { "path": "components/cta-button/index.json", "content": "{ \"component\": true, \"usingComponents\": {} }" }
  ]
}
'@
    $boundaryPatchPayload = @'
{
  "append_pages": ["pages/about/index"]
}
'@
    $invalidBoundaryPayload = @'
{
  "page_name": "about",
  "files": [
    { "path": "pages/about/index.wxml", "content": "<div>bad</div>" },
    { "path": "pages/about/index.js", "content": "Page({ data: {}, onLoad() {} })" },
    { "path": "pages/about/index.wxss", "content": ".container { padding: 20rpx; }" },
    { "path": "pages/about/index.json", "content": "{ \"usingComponents\": {} }" }
  ]
}
'@
    $boundaryComponentValidate = & $boundaryScript -Operation validate_component_bundle -JsonPayload $boundaryComponentPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $boundaryPageApply = & $boundaryScript -Operation apply_page_bundle -JsonPayload $boundaryPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $boundaryComponentApply = & $boundaryScript -Operation apply_component_bundle -JsonPayload $boundaryComponentPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $appJsonPath = Join-Path $boundaryWorkspace 'app.json'
    [System.IO.File]::WriteAllText($appJsonPath, (@{
        pages = @()
        window = @{ navigationBarTitleText = 'Test' }
    } | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
    $boundaryPatchValidate = & $boundaryScript -Operation validate_app_json_patch -JsonPayload $boundaryPatchPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $boundaryPatchApply = & $boundaryScript -Operation apply_app_json_patch -JsonPayload $boundaryPatchPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $boundaryFileInputValidate = & $boundaryScript -Operation validate_page_bundle -JsonFilePath $boundaryPayloadPath -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $boundaryFileInputApply = & $boundaryScript -Operation apply_page_bundle -JsonFilePath $boundaryPayloadPath -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $externalClientValidate = & $boundaryScript -Operation validate_page_bundle -JsonFilePath $externalPayloadPath -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $externalClientApply = & $boundaryScript -Operation apply_page_bundle -JsonFilePath $externalPayloadPath -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $failureValidate = & $boundaryScript -Operation validate_page_bundle -JsonPayload $invalidBoundaryPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json
    $failureApply = & $boundaryScript -Operation apply_page_bundle -JsonPayload $invalidBoundaryPayload -TargetWorkspace $boundaryWorkspace | ConvertFrom-Json

    $generatedProject = Resolve-SharedTemplateProject -Prompt 'build a notebook mini program' -GeneratedRoot $generatedRoot -NormalizeMode 'notebook'
    $generatedNotebookEligibleProject = New-EligibleNotebookProject -NotebookProject $generatedProject -GeneratedRoot $generatedRoot
    $generatedTodoProject = Resolve-SharedTemplateProject -Prompt 'build a todo list mini program' -GeneratedRoot $generatedRoot
    $generatedShoplistProject = Resolve-SharedTemplateProject -Prompt 'build a shop list mini program' -GeneratedRoot $generatedRoot

    $payload = [pscustomobject]@{
        fingerprint = $fingerprint
        generated_at = (Get-Date).ToString('o')
        boundary_workspace = $boundaryWorkspace
        boundary_payload_path = $boundaryPayloadPath
        external_workspace = $boundaryWorkspace
        external_payload_path = $externalPayloadPath
        generated_project = $generatedProject
        generated_notebook_eligible_project = $generatedNotebookEligibleProject
        generated_todo_project = $generatedTodoProject
        generated_shoplist_project = $generatedShoplistProject
        describe_contract = $describeContract
        execution_profile = $executionProfile
        boundary_contracts = [pscustomobject]@{
            page_validate = $boundaryPageValidate
            component_validate = $boundaryComponentValidate
            page_apply = $boundaryPageApply
            component_apply = $boundaryComponentApply
            patch_validate = $boundaryPatchValidate
            patch_apply = $boundaryPatchApply
            file_input_validate = $boundaryFileInputValidate
            file_input_apply = $boundaryFileInputApply
            external_validate = $externalClientValidate
            external_apply = $externalClientApply
            failure_validate = $failureValidate
            failure_apply = $failureApply
        }
    }
    Write-AtomicJsonCache -Path $cachePath -InputObject $payload -Depth 12

    return [pscustomobject]@{
        fingerprint = $fingerprint
        fromCache = $false
        cachePath = $cachePath
        boundaryWorkspace = $boundaryWorkspace
        boundaryPayloadPath = $boundaryPayloadPath
        externalWorkspace = $boundaryWorkspace
        externalPayloadPath = $externalPayloadPath
        generatedNotebookProject = $generatedProject
        generatedNotebookEligibleProject = $generatedNotebookEligibleProject
        generatedTodoProject = $generatedTodoProject
        generatedShoplistProject = $generatedShoplistProject
        describeContract = $describeContract
        executionProfile = $executionProfile
        boundaryContracts = $payload.boundary_contracts
    }
}
