param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$translation = Invoke-WechatTaskTranslator -TaskText 'build a coupon center empty-state page with a claim button and rules copy'
Assert-Equal $translation.status 'success' 'translator should succeed before bundle compilation validation'
Assert-NotEmpty $translation.page_bundle 'translator should attach a compiled page bundle'
Assert-NotEmpty $translation.component_bundle 'translator should attach a compiled component bundle'
Assert-NotEmpty $translation.app_patch 'translator should attach a compiled app patch'

$compiled = Invoke-TaskSpecToBundle -TaskSpec $translation.task_spec
Assert-Equal $compiled.status 'success' 'compiler should return success'
Assert-Equal $compiled.page_bundle.page_name 'index' 'compiler should emit an index page bundle'
Assert-Equal $compiled.component_bundle.component_name 'cta-button' 'compiler should emit the CTA component bundle'
Assert-Equal @($compiled.app_patch.append_pages).Count 1 'compiler should emit one app page registration'
Assert-Equal $compiled.app_patch.append_pages[0] 'pages/index/index' 'compiler should register the generated index page'

$boundaryScript = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
$workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("task-bundle-compiler-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workspace -Force | Out-Null

try {
    $componentValidate = & $boundaryScript -Operation validate_component_bundle -JsonPayload ($compiled.component_bundle | ConvertTo-Json -Depth 20) -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $componentValidate.status 'success' 'component bundle should validate through boundary'
    Assert-Equal $componentValidate.gate_status 'pass' 'component bundle should pass boundary validation'

    $componentApply = & $boundaryScript -Operation apply_component_bundle -JsonPayload ($compiled.component_bundle | ConvertTo-Json -Depth 20) -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $componentApply.status 'success' 'component bundle should apply through boundary'

    $pageValidate = & $boundaryScript -Operation validate_page_bundle -JsonPayload ($compiled.page_bundle | ConvertTo-Json -Depth 20) -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $pageValidate.status 'success' 'page bundle should validate through boundary'
    Assert-Equal $pageValidate.gate_status 'pass' 'page bundle should pass boundary validation'

    $pageApply = & $boundaryScript -Operation apply_page_bundle -JsonPayload ($compiled.page_bundle | ConvertTo-Json -Depth 20) -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $pageApply.status 'success' 'page bundle should apply through boundary'

    $appJsonPath = Join-Path $workspace 'app.json'
    $appJson = @{
        pages = @()
        window = @{ navigationBarTitleText = 'Compiler Test' }
    } | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($appJsonPath, $appJson, (New-Object System.Text.UTF8Encoding($false)))

    $patchValidate = & $boundaryScript -Operation validate_app_json_patch -JsonPayload ($compiled.app_patch | ConvertTo-Json -Depth 20) -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $patchValidate.status 'success' 'app patch should validate through boundary'
    Assert-Equal $patchValidate.gate_status 'pass' 'app patch should pass boundary validation after page apply'

    $patchApply = & $boundaryScript -Operation apply_app_json_patch -JsonPayload ($compiled.app_patch | ConvertTo-Json -Depth 20) -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $patchApply.status 'success' 'app patch should apply through boundary'

    $writtenAppJson = Get-Content $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-In 'pages/index/index' @($writtenAppJson.pages) 'app patch should register the compiled index page'

    New-TestResult -Name 'task-bundle-compiler' -Data @{
        pass = $true
        exit_code = 0
        task_family = $compiled.task_family
        route_mode = $compiled.route_mode
        page_name = $compiled.page_bundle.page_name
        component_name = $compiled.component_bundle.component_name
    }
}
finally {
    if (Test-Path $workspace) {
        Remove-Item -Path $workspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}
