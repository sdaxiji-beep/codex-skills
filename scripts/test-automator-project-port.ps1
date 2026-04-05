param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-automator-port.ps1"
. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectA = Join-Path $repoRoot 'sandbox\project-a'
$projectB = Join-Path $repoRoot 'sandbox\project-b'

$portA1 = Get-ProjectScopedAutomatorPort -ProjectPath $projectA
$portA2 = Get-ProjectScopedAutomatorPort -ProjectPath $projectA
$portB = Get-ProjectScopedAutomatorPort -ProjectPath $projectB
$candidates = Get-ProjectScopedAutomatorPortCandidates -ProjectPath $projectA

Assert-Equal $portA1 $portA2 'same project path must map to the same automator port'
Assert-True ($portA1 -ge 9420) 'project-scoped port must stay at or above the automator base port'
Assert-True ($portA1 -lt 9460) 'project-scoped port should stay in the default deterministic port window'
Assert-True ($candidates[0] -eq $portA1) 'candidate list must prioritize the project-scoped port'
Assert-True (@($candidates | Select-Object -Unique).Count -eq @($candidates).Count) 'candidate list should not contain duplicates'

New-TestResult -Name 'automator-project-port' -Data @{
    pass = $true
    exit_code = 0
    project_a_port = $portA1
    project_b_port = $portB
    candidate_count = @($candidates).Count
}
