param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
$artifactPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools\generation-gate\ast-shadow-latest.json'

try {
    $env:WECHAT_AST_TEST_FORCE_ERROR = '1'

    $payload = @'
{
  "page_name": "about",
  "files": [
    {
      "path": "pages/about/index.wxml",
      "content": "<view><text>About</text></view>"
    },
    {
      "path": "pages/about/index.js",
      "content": "Page({ data: {}, onLoad() {} })"
    },
    {
      "path": "pages/about/index.wxss",
      "content": ".container { padding: 20rpx; }"
    },
    {
      "path": "pages/about/index.json",
      "content": "{ \"usingComponents\": {} }"
    }
  ]
}
'@

    # Case A: rollback mode (hybrid off) keeps gate pass, mismatch should be true.
    $env:WECHAT_AST_HYBRID_MODE = '0'
    $rollbackResult = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $rollbackResult.Status 'pass' 'Rollback mode should keep valid payload pass'
    Assert-True (Test-Path $artifactPath) 'AST shadow artifact should exist'
    $rollbackArtifact = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Assert-Equal $rollbackArtifact.hybrid_mode $false 'Artifact should mark hybrid off in rollback mode'
    Assert-True ($rollbackArtifact.shadow_error_count -ge 1) 'Forced AST errors should be captured in artifact'
    Assert-Equal $rollbackArtifact.shadow_mismatch $true 'Mismatch should be true when AST sees errors but gate stays pass'
    Assert-Equal $rollbackArtifact.promoted_error_count 0 'Rollback mode should not promote AST errors'

    # Case B: default mode (hybrid on) should promote, mismatch should be false.
    Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue
    $defaultResult = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $defaultResult.Status 'retryable_fail' 'Default mode should promote AST errors to retryable_fail'
    $defaultArtifact = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Assert-Equal $defaultArtifact.hybrid_mode $true 'Artifact should mark hybrid on in default mode'
    Assert-True ($defaultArtifact.promoted_error_count -ge 1) 'Default mode should promote AST errors'
    Assert-Equal $defaultArtifact.shadow_mismatch $false 'Mismatch should be false after AST promotion'

    # Diagnostic quality assertions
    Assert-True (@($defaultArtifact.diagnostics).Count -gt 0) 'Diagnostics should not be empty when forced errors are enabled'
    $diag = $defaultArtifact.diagnostics[0]
    Assert-True ($diag.PSObject.Properties.Name -contains 'code') 'Diagnostic should include code'
    Assert-True ($diag.PSObject.Properties.Name -contains 'file') 'Diagnostic should include file'
    Assert-True ($diag.PSObject.Properties.Name -contains 'message') 'Diagnostic should include message'
    Assert-True ($diag.PSObject.Properties.Name -contains 'severity') 'Diagnostic should include severity'

    New-TestResult -Name 'generation-gate-ast-mismatch-governance' -Data @{
        pass = $true
        exit_code = 0
        rollback_mismatch = $rollbackArtifact.shadow_mismatch
        default_mismatch = $defaultArtifact.shadow_mismatch
        promoted_error_count = $defaultArtifact.promoted_error_count
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}
