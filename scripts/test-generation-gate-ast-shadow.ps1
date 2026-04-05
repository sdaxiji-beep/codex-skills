param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactDir = Join-Path $repoRoot 'artifacts\wechat-devtools\generation-gate'
$latestArtifact = Join-Path $artifactDir 'ast-shadow-latest.json'

$beforeStamp = $null
if (Test-Path $latestArtifact) {
    $beforeStamp = (Get-Item $latestArtifact).LastWriteTimeUtc
}

$payload = @'
{
  "page_name": "about",
  "files": [
    {
      "path": "pages/about/index.wxml",
      "content": "<view class=\"container\"><text>About</text></view>"
    },
    {
      "path": "pages/about/index.js",
      "content": "Page({ data: {}, onLoad() {} })"
    },
    {
      "path": "pages/about/index.wxss",
      "content": ".container { padding: 24rpx; }"
    },
    {
      "path": "pages/about/index.json",
      "content": "{ \"usingComponents\": {} }"
    }
  ]
}
'@

$result = Invoke-GenerationGateV1 -JsonPayload $payload -TargetWorkspace $repoRoot
Assert-Equal $result.Status 'pass' 'Gate verdict should remain pass for a valid bundle'
Assert-True (Test-Path $latestArtifact) 'Shadow artifact should be written'

$afterItem = Get-Item $latestArtifact
if ($null -ne $beforeStamp) {
    Assert-True ($afterItem.LastWriteTimeUtc -ge $beforeStamp) 'Shadow artifact timestamp should refresh'
}

$artifact = Get-Content $latestArtifact -Raw | ConvertFrom-Json
Assert-True ($artifact.PSObject.Properties.Name -contains 'shadow_executed') 'Artifact should include shadow execution metadata'
Assert-True ($artifact.PSObject.Properties.Name -contains 'diagnostics') 'Artifact should include diagnostics array'
Assert-Equal $artifact.gate_status 'pass' 'Artifact should record the gate verdict'

New-TestResult -Name 'generation-gate-ast-shadow' -Data @{
    pass = $true
    exit_code = 0
    shadow_executed = $artifact.shadow_executed
    shadow_parser = $artifact.shadow_parser
}
