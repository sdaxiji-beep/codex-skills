param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-component-v1.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactDir = Join-Path $repoRoot 'artifacts\wechat-devtools\generation-gate'
$latestArtifact = Join-Path $artifactDir 'component-ast-shadow-latest.json'

$beforeStamp = $null
if (Test-Path $latestArtifact) {
    $beforeStamp = (Get-Item $latestArtifact).LastWriteTimeUtc
}

$payload = @'
{
  "component_name": "cta-button",
  "files": [
    {
      "path": "components/cta-button/index.wxml",
      "content": "<view class=\"wrap\"><button>{{text}}</button></view>"
    },
    {
      "path": "components/cta-button/index.js",
      "content": "Component({ properties: { text: { type: String, value: 'Click' } }, data: {}, methods: {} })"
    },
    {
      "path": "components/cta-button/index.wxss",
      "content": ".wrap { padding: 20rpx; }"
    },
    {
      "path": "components/cta-button/index.json",
      "content": "{ \"component\": true, \"usingComponents\": {} }"
    }
  ]
}
'@

$result = Invoke-GenerationGateComponentV1 -JsonPayload $payload
Assert-Equal $result.Status 'pass' 'Component gate verdict should remain pass for a valid bundle'
Assert-True (Test-Path $latestArtifact) 'Component shadow artifact should be written'

$afterItem = Get-Item $latestArtifact
if ($null -ne $beforeStamp) {
    Assert-True ($afterItem.LastWriteTimeUtc -ge $beforeStamp) 'Component shadow artifact timestamp should refresh'
}

$artifact = Get-Content $latestArtifact -Raw | ConvertFrom-Json
Assert-Equal $artifact.gate_kind 'component' 'Artifact should record gate kind'
Assert-Equal $artifact.gate_status 'pass' 'Artifact should record component gate verdict'
Assert-True ($artifact.PSObject.Properties.Name -contains 'shadow_executed') 'Artifact should include shadow execution metadata'
Assert-True ($artifact.PSObject.Properties.Name -contains 'diagnostics') 'Artifact should include diagnostics array'

New-TestResult -Name 'generation-gate-component-ast-shadow' -Data @{
    pass = $true
    exit_code = 0
    shadow_executed = $artifact.shadow_executed
    shadow_parser = $artifact.shadow_parser
}
