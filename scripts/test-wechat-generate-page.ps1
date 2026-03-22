param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-generate-page-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $componentRoot = Join-Path $tempRoot 'components\product-card'
    New-Item -ItemType Directory -Path $componentRoot -Force | Out-Null
    Set-Content -Path (Join-Path $componentRoot 'index.js') -Value 'Component({ properties: {}, data: {}, methods: {} })' -Encoding ASCII

    $result = Invoke-WechatGeneratePage `
      -Prompt "build a todo page with pull to refresh and inline delete" `
      -PagePath "pages/todo/index" `
      -TargetWorkspace $tempRoot

    Assert-Equal $result.status "success" "generate-page should succeed"
    Assert-Equal $result.page_path "pages/todo/index" "page path should normalize correctly"
    Assert-Equal $result.page_name "todo" "page name should derive from page path"
    Assert-True (Test-Path $result.spec_path) "spec file should exist"
    Assert-True ($result.bundle_path -match 'page-generation-bundle-pages-todo-index\.json$') "bundle path should be deterministic for the page path"

    $specText = Get-Content -Path $result.spec_path -Raw
    Assert-True ($specText -match 'Path: pages/todo/index') "spec should record the target page path"
    Assert-True ($specText -match [regex]::Escape($result.bundle_path)) "spec should record the bundle output path"
    Assert-True ($specText -match 'wechat-apply-bundle\.ps1') "spec should include the apply command"
    Assert-True ($specText -notmatch '\$normalizedPagePath|\$bundlePath') "spec should not leak template variables"
    Assert-True ($specText -match '```powershell') "spec should include a valid fenced PowerShell command block"
    Assert-True ($specText -match 'Exit code 0: apply succeeded\.') "spec should render retry contract lines cleanly"
    Assert-True ($specText -match '<product-card> -> /components/product-card/index') "spec should inject available custom components"

    New-TestResult -Name "wechat-generate-page" -Data @{
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
