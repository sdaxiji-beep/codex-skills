param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$taskText = 'build a product listing mini program page with featured goods cards, prices, and a clean mobile-first catalog layout'
$recipe = Resolve-WechatProductListingRecipe -TaskText $taskText
$result = Invoke-WechatProductListingTask -Recipe $recipe -TaskText $taskText -Open $false -Preview $false -RunRepairLoop $false

Assert-Equal $result.status 'success' 'product-listing generated-product task should succeed'
Assert-Equal $result.route_family 'product-listing' 'product-listing task should keep the correct route family'
Assert-Equal $result.project_identity.app_title 'Product Center' 'product-listing task should override app title'
Assert-Equal $result.project_identity.project_name 'product-center-app' 'product-listing task should override project name'

$projectDir = $result.project_dir
$wxmlPath = Join-Path $projectDir 'pages\index\index.wxml'
$jsonPath = Join-Path $projectDir 'pages\index\index.json'
$componentPath = Join-Path $projectDir 'components\product-card\index.js'
$appJsonPath = Join-Path $projectDir 'app.json'

Assert-True (Test-Path $wxmlPath) 'product-listing task should create index.wxml'
Assert-True (Test-Path $jsonPath) 'product-listing task should create index.json'
Assert-True (Test-Path $componentPath) 'product-listing task should create product-card component'
Assert-True (Test-Path $appJsonPath) 'product-listing task should keep app.json present'

$wxml = Get-Content $wxmlPath -Raw
$json = Get-Content $jsonPath -Raw
$appJson = Get-Content $appJsonPath -Raw | ConvertFrom-Json

Assert-True ($wxml.Contains('Featured Products')) 'product-listing page should contain Featured Products title'
Assert-True ($wxml.Contains('Popular picks')) 'product-listing page should contain Popular picks section'
Assert-True ($wxml.Contains('Spicy Braised Combo')) 'product-listing page should contain the first featured product'
Assert-True ($wxml.Contains('product-card')) 'product-listing page should use product-card component instances'
Assert-True ($json.Contains('"product-card"')) 'product-listing page json should register product-card'
Assert-Equal $appJson.window.navigationBarTitleText 'Product Center' 'product-listing task should update app navigation title'

New-TestResult -Name 'wechat-task-product-listing' -Data @{
    pass = $true
    exit_code = 0
    project_dir = $projectDir
    route_family = $result.route_family
    app_title = $result.project_identity.app_title
    project_name = $result.project_identity.project_name
}
