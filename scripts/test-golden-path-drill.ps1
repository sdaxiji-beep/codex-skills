param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$create = Invoke-WechatCreate `
  -Prompt "build a notebook mini program" `
  -Open $false `
  -Preview $false `
  -RunFastGate $false

Assert-Equal $create.status "success" "golden path drill: project shell create should succeed"
$projectDir = $create.project_dir
Assert-True (Test-Path $projectDir) "golden path drill: project dir should exist"

$componentStep = Invoke-WechatGenerateComponent `
  -Prompt "Create a reusable CTA button component with a text label property" `
  -ComponentPath "components/cta-button/index" `
  -TargetWorkspace $projectDir

Assert-Equal $componentStep.status "success" "golden path drill: component spec generation should succeed"
Assert-True (Test-Path $componentStep.spec_path) "golden path drill: component spec should exist"

$componentBundle = @{
    component_name = "cta-button"
    files = @(
        @{
            path = "components/cta-button/index.wxml"
            content = "<view class='cta-wrap'><button class='cta-btn'>{{text}}</button></view>"
        },
        @{
            path = "components/cta-button/index.js"
            content = @"
Component({
  properties: {
    text: {
      type: String,
      value: "Click"
    }
  },
  data: {},
  methods: {}
})
"@
        },
        @{
            path = "components/cta-button/index.wxss"
            content = ".cta-wrap { padding: 20rpx; }`n.cta-btn { background: #07c160; color: #fff; }"
        },
        @{
            path = "components/cta-button/index.json"
            content = "{`n  `"component`": true,`n  `"usingComponents`": {}`n}"
        }
    )
}

$componentBundle | ConvertTo-Json -Depth 10 | Set-Content -Path $componentStep.bundle_path -Encoding UTF8
$componentApply = & (Join-Path $PSScriptRoot "wechat-apply-component-bundle.ps1") `
  -JsonFilePath $componentStep.bundle_path `
  -TargetWorkspace $projectDir

Assert-Equal $componentApply.status "success" "golden path drill: component apply should succeed"
Assert-True (Test-Path (Join-Path $projectDir "components\cta-button\index.js")) "golden path drill: component js should be written"

$pageStep = Invoke-WechatGeneratePage `
  -Prompt "Create an about page with logo, version text, and one CTA button component" `
  -PagePath "pages/about/index" `
  -TargetWorkspace $projectDir

Assert-Equal $pageStep.status "success" "golden path drill: page spec generation should succeed"
Assert-True (Test-Path $pageStep.spec_path) "golden path drill: page spec should exist"

$pageBundle = @{
    page_name = "about"
    files = @(
        @{
            path = "pages/about/index.wxml"
            content = "<view class='container'><text class='logo'>MyApp</text><text class='version'>v1.0.0</text><cta-button text='Get Started'></cta-button></view>"
        },
        @{
            path = "pages/about/index.js"
            content = @"
Page({
  data: {},
  onLoad() {}
})
"@
        },
        @{
            path = "pages/about/index.wxss"
            content = ".container { padding: 32rpx; }`n.logo { font-size: 40rpx; font-weight: 700; }`n.version { color: #888; margin-bottom: 24rpx; }"
        },
        @{
            path = "pages/about/index.json"
            content = "{`n  `"navigationBarTitleText`": `"About`",`n  `"usingComponents`": {`n    `"cta-button`": `"/components/cta-button/index`"`n  }`n}"
        }
    )
}

$pageBundle | ConvertTo-Json -Depth 10 | Set-Content -Path $pageStep.bundle_path -Encoding UTF8
$pageApply = & (Join-Path $PSScriptRoot "wechat-apply-bundle.ps1") `
  -JsonFilePath $pageStep.bundle_path `
  -TargetWorkspace $projectDir

Assert-Equal $pageApply.status "success" "golden path drill: page apply should succeed"
Assert-True (Test-Path (Join-Path $projectDir "pages\about\index.wxml")) "golden path drill: page wxml should be written"

$patchStep = Invoke-WechatPatchAppJson `
  -Prompt "Register about page route safely in app.json" `
  -PagePaths @("pages/about/index") `
  -TargetWorkspace $projectDir

Assert-Equal $patchStep.status "success" "golden path drill: app.json patch spec generation should succeed"
Assert-True (Test-Path $patchStep.spec_path) "golden path drill: patch spec should exist"

$patchBundle = @{
    append_pages = @("pages/about/index")
}

$patchBundle | ConvertTo-Json -Depth 5 | Set-Content -Path $patchStep.patch_path -Encoding UTF8
$patchApply = & (Join-Path $PSScriptRoot "wechat-apply-app-json-patch.ps1") `
  -JsonFilePath $patchStep.patch_path `
  -TargetWorkspace $projectDir

Assert-Equal $patchApply.status "success" "golden path drill: app.json patch apply should succeed"

$appJson = Get-Content (Join-Path $projectDir "app.json") -Raw | ConvertFrom-Json
Assert-In "pages/about/index" @($appJson.pages) "golden path drill: app.json should include about route"

$guard = Invoke-GeneratedProjectDeployGuard -ProjectPath $projectDir
Assert-In $guard.status @('denied', 'eligible') "golden path drill: deploy guard should return a valid status"

New-TestResult -Name "golden-path-drill" -Data @{
    pass          = $true
    exit_code     = 0
    project_dir   = $projectDir
    create_status = $create.status
    guard_status  = $guard.status
}
