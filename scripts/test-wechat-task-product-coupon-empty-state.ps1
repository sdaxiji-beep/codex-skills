param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$taskText = 'build a coupon center mini program with an empty-state page, a claim coupon CTA, simple coupon rules text, and a clean mobile-first layout'
$result = Invoke-WechatCouponEmptyStateTask -TaskText $taskText -Open $false -Preview $false -RunRepairLoop $false

Assert-Equal $result.status 'success' 'coupon empty-state generated-product task should succeed'
Assert-True ($result.component_written -eq $true) 'coupon empty-state task should write the CTA component'
Assert-True ($result.page_written -eq $true) 'coupon empty-state task should write the index page'

$projectDir = $result.project_dir
$wxmlPath = Join-Path $projectDir 'pages\index\index.wxml'
$jsonPath = Join-Path $projectDir 'pages\index\index.json'
$componentPath = Join-Path $projectDir 'components\cta-button\index.js'
$appJsonPath = Join-Path $projectDir 'app.json'
$projectConfigPath = Join-Path $projectDir 'project.config.json'

Assert-True (Test-Path $wxmlPath) 'coupon empty-state task should create index.wxml'
Assert-True (Test-Path $jsonPath) 'coupon empty-state task should create index.json'
Assert-True (Test-Path $componentPath) 'coupon empty-state task should create cta-button component'
Assert-True (Test-Path $appJsonPath) 'coupon empty-state task should keep app.json present'
Assert-True (Test-Path $projectConfigPath) 'coupon empty-state task should keep project.config.json present'

$wxml = Get-Content $wxmlPath -Raw
$json = Get-Content $jsonPath -Raw
$appJson = Get-Content $appJsonPath -Raw | ConvertFrom-Json
$projectConfig = Get-Content $projectConfigPath -Raw | ConvertFrom-Json

Assert-True ($wxml.Contains('Coupon Center')) 'coupon empty-state page should contain Coupon Center title'
Assert-True ($wxml.Contains('Claim Coupon')) 'coupon empty-state page should contain Claim Coupon CTA'
Assert-True ($wxml.Contains('Coupon rules')) 'coupon empty-state page should contain Coupon rules section'
Assert-True ($json.Contains('"cta-button"')) 'coupon empty-state page json should register cta-button'
Assert-Equal $appJson.window.navigationBarTitleText 'Coupon Center' 'coupon empty-state task should update app navigation title'
Assert-Equal $projectConfig.projectname 'coupon-center-app' 'coupon empty-state task should replace notebook project identity'

New-TestResult -Name 'wechat-task-product-coupon-empty-state' -Data @{
    pass = $true
    exit_code = 0
    project_dir = $projectDir
    route_family = $result.route_family
    page_written = $result.page_written
    component_written = $result.component_written
    app_title = $result.project_identity.app_title
    project_name = $result.project_identity.project_name
}
