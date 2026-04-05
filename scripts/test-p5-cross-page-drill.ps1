param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$prompt = 'build a food order flow with a listing page and a checkout page linked together.'
$sandboxRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'sandbox\phase13-cross-page'
New-Item -ItemType Directory -Force -Path $sandboxRoot | Out-Null

$translation = Invoke-WechatTaskTranslator -TaskText $prompt
Assert-Equal $translation.status 'success' 'cross-page translator should succeed'
Assert-Equal ([string]$translation.task_spec.route_mode) 'food-order-flow' 'cross-page route mode should match'
Assert-Equal @($translation.task_spec.target_pages).Count 2 'cross-page task should compile two target pages'
Assert-Equal ([string]$translation.page_bundle.source) 'registry' 'cross-page page bundle should come from registry'

$execution = Invoke-WechatTaskExecution `
    -TaskSpec $translation.task_spec `
    -PageBundle $translation.page_bundle `
    -ComponentBundle $translation.component_bundle `
    -ComponentBundles $translation.component_bundles `
    -AppPatch $translation.app_patch `
    -OutputDir $sandboxRoot `
    -Open $false `
    -Preview $false

Assert-Equal ([string]$execution.status) 'success' 'cross-page execution should succeed'
Assert-Equal ([string]$execution.acceptance.status) 'pass' 'cross-page acceptance should pass'

$projectDir = [string]$execution.project_dir
Assert-True (Test-Path (Join-Path $projectDir 'pages\index\index.wxml')) 'cross-page drill should generate the listing page'
Assert-True (Test-Path (Join-Path $projectDir 'pages\checkout\index.wxml')) 'cross-page drill should generate the checkout page'

$appJson = Get-Content (Join-Path $projectDir 'app.json') -Raw -Encoding UTF8
$indexWxml = Get-Content (Join-Path $projectDir 'pages\index\index.wxml') -Raw -Encoding UTF8

Assert-True ($appJson.Contains('pages/index/index')) 'cross-page app.json should contain index route'
Assert-True ($appJson.Contains('pages/checkout/index')) 'cross-page app.json should contain checkout route'
Assert-True ($indexWxml.Contains('/pages/checkout/index')) 'cross-page index page should contain checkout navigator'

New-TestResult -Name 'p5-cross-page-drill' -Data @{
    pass = $true
    route_mode = [string]$translation.task_spec.route_mode
    project_dir = $projectDir
    registry_page_hit = ([string]$translation.page_bundle.source -eq 'registry')
    registry_component_count = @($translation.component_bundles | Where-Object { [string]$_.source -eq 'registry' }).Count
}
