param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-patch-app-json.ps1"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-patch-app-json-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'pages\about') -Force | Out-Null
Set-Content -Path (Join-Path $tempRoot 'pages\about\index.wxml') -Value '<view />' -Encoding ASCII

try {
    $result = Invoke-WechatPatchAppJson `
      -Prompt "register the about page in app.json routes" `
      -PagePaths @('pages/about/index') `
      -TargetWorkspace $tempRoot

    Assert-Equal $result.status 'success' 'patch-app-json should succeed'
    Assert-True (Test-Path $result.spec_path) 'patch spec should exist'
    Assert-True ($result.patch_path -match 'app-json-patch-pages-about-index\.json$') 'patch path should be deterministic'

    $specText = Get-Content -Path $result.spec_path -Raw
    Assert-True ($specText -match 'Allowed top-level field: append_pages') 'spec should enforce append_pages-only contract'
    Assert-True ($specText -match [regex]::Escape($result.patch_path)) 'spec should record patch output path'
    Assert-True ($specText -match 'wechat-apply-app-json-patch\.ps1') 'spec should include patch apply command'
    Assert-True ($specText -match 'pages/about/index \(exists: yes\)') 'spec should report physical page existence'

    New-TestResult -Name 'wechat-patch-app-json' -Data @{
      pass = $true
      exit_code = 0
      spec_path = $result.spec_path
      patch_path = $result.patch_path
    }
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
