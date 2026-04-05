param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$first = Get-SharedP3OperationalFixtures -RepoRoot $repoRoot -ForceRefresh
$second = Get-SharedP3OperationalFixtures -RepoRoot $repoRoot

Assert-True (-not $first.fromCache) 'first shared P3 fixture fetch should build the cache'
Assert-True ($second.fromCache) 'second shared P3 fixture fetch should reuse the cache'
Assert-Equal $first.cachePath $second.cachePath 'shared P3 fixture cache path should remain stable'
Assert-Equal $first.generatedNotebookProject.project_dir $second.generatedNotebookProject.project_dir 'shared notebook project dir should be reused'
Assert-Equal $first.generatedNotebookProject.appid 'touristappid' 'shared notebook project should normalize to touristappid'
Assert-Equal $first.generatedNotebookProject.projectname 'notebook-app' 'shared notebook project should normalize project name'
Assert-Equal $second.generatedNotebookProject.appid 'touristappid' 'cached shared notebook project should stay normalized'
Assert-Equal $second.generatedNotebookProject.projectname 'notebook-app' 'cached shared notebook project should stay normalized'
Assert-True ($null -ne $first.generatedTodoProject) 'shared todo project should be prepared'
Assert-True ($null -ne $first.generatedShoplistProject) 'shared shoplist project should be prepared'
Assert-True ($null -ne $first.generatedNotebookEligibleProject) 'shared eligible notebook project should be prepared'
Assert-Equal $first.generatedTodoProject.template 'todo' 'shared todo project should keep todo template metadata'
Assert-Equal $first.generatedShoplistProject.template 'shoplist' 'shared shoplist project should keep shoplist template metadata'
Assert-Equal $first.generatedTodoProject.project_dir $second.generatedTodoProject.project_dir 'shared todo project dir should be reused'
Assert-Equal $first.generatedShoplistProject.project_dir $second.generatedShoplistProject.project_dir 'shared shoplist project dir should be reused'
Assert-Equal $first.generatedNotebookEligibleProject.appid 'wx1234567890abcdef' 'eligible notebook project should use a non-tourist appid'
Assert-Equal $first.generatedNotebookEligibleProject.projectname 'generated-notebook' 'eligible notebook project should use the release project name'
Assert-Equal $first.generatedNotebookEligibleProject.project_dir $second.generatedNotebookEligibleProject.project_dir 'shared eligible notebook project dir should be reused'
Assert-True (Test-Path $first.boundaryWorkspace) 'shared boundary workspace should exist'
Assert-True (Test-Path $first.boundaryPayloadPath) 'shared boundary payload should exist'
Assert-True (Test-Path $first.externalPayloadPath) 'shared external payload should exist'
Assert-True ($first.describeContract.status -eq 'success') 'shared describe_contract should succeed'
Assert-True ($first.executionProfile.status -eq 'success') 'shared describe_execution_profile should succeed'

New-TestResult -Name 'p3-operational-fixtures' -Data @{
    pass = $true
    exit_code = 0
    from_cache = $second.fromCache
    cache_path = $second.cachePath
    project_dir = $second.generatedNotebookProject.project_dir
    eligible_project_dir = $second.generatedNotebookEligibleProject.project_dir
}
