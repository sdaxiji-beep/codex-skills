param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-generate-component.ps1"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-generate-component-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $result = Invoke-WechatGenerateComponent `
      -Prompt "build a product card component with title, price, and CTA button" `
      -ComponentPath "components/product-card/index" `
      -TargetWorkspace $tempRoot

    Assert-Equal $result.status "success" "generate-component should succeed"
    Assert-Equal $result.component_path "components/product-card/index" "component path should normalize correctly"
    Assert-Equal $result.component_name "product-card" "component name should derive from component path"
    Assert-True (Test-Path $result.spec_path) "component spec file should exist"
    Assert-True ($result.spec_path -match 'COMPONENT_SPEC_PRODUCT-CARD\.md$') "component spec path should be stable for the component name"
    Assert-True ($result.bundle_path -match 'component-generation-bundle-components-product-card-index\.json$') "component bundle path should be deterministic for the component path"

    $specText = Get-Content -Path $result.spec_path -Raw
    Assert-True ($specText -match 'Path: components/product-card/index') "component spec should record the target component path"
    Assert-True ($specText -match [regex]::Escape($result.bundle_path)) "component spec should record the bundle output path"
    Assert-True ($specText -match 'wechat-apply-component-bundle\.ps1') "component spec should include the apply command"
    Assert-True ($specText -match 'component=true') "component spec should include the component config requirement"

    New-TestResult -Name "wechat-generate-component" -Data @{
      pass = $true
      exit_code = 0
      spec_path = $result.spec_path
      bundle_path = $result.bundle_path
    }
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
