param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$taskText = 'build a campaign page that says the event has not started yet, shows a notify me CTA, and keeps a simple mobile-first activity layout'
$recipe = Resolve-WechatMarketingEmptyStateRecipe -TaskText $taskText
$result = Invoke-WechatMarketingEmptyStateTask -Recipe $recipe -TaskText $taskText -Open $false -Preview $false -RunRepairLoop $false

Assert-Equal $result.status 'success' 'activity-not-started generated-product task should succeed'
Assert-Equal $result.route_family 'activity-not-started' 'activity-not-started task should keep the correct route family'
Assert-Equal $result.project_identity.app_title 'Campaign Center' 'activity-not-started task should override app title'
Assert-Equal $result.project_identity.project_name 'campaign-center-app' 'activity-not-started task should override project name'

$projectDir = $result.project_dir
$wxmlPath = Join-Path $projectDir 'pages\index\index.wxml'
$appJsonPath = Join-Path $projectDir 'app.json'

Assert-True (Test-Path $wxmlPath) 'activity-not-started task should create index.wxml'
Assert-True (Test-Path $appJsonPath) 'activity-not-started task should keep app.json present'

$wxml = Get-Content $wxmlPath -Raw
$appJson = Get-Content $appJsonPath -Raw | ConvertFrom-Json

Assert-True ($wxml.Contains('The event has not started yet')) 'activity-not-started page should contain the event status title'
Assert-True ($wxml.Contains('Notify Me')) 'activity-not-started page should contain Notify Me CTA'
Assert-True ($wxml.Contains('Activity notes')) 'activity-not-started page should contain Activity notes section'
Assert-Equal $appJson.window.navigationBarTitleText 'Campaign Center' 'activity-not-started task should update app navigation title'

New-TestResult -Name 'wechat-task-product-activity-not-started' -Data @{
    pass = $true
    exit_code = 0
    project_dir = $projectDir
    route_family = $result.route_family
    app_title = $result.project_identity.app_title
    project_name = $result.project_identity.project_name
}
