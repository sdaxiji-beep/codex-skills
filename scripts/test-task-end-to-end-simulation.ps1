param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$sandboxRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'sandbox'
$simulationRoot = Join-Path $sandboxRoot ("p5-task-exec-" + [guid]::NewGuid().ToString('N'))
 $detailSimulationRoot = Join-Path $sandboxRoot ("p5-task-detail-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $simulationRoot -Force | Out-Null
New-Item -ItemType Directory -Path $detailSimulationRoot -Force | Out-Null

try {
    $taskText = 'build a store showcase homepage with prices and featured picks'
    $resolved = Invoke-WechatTask -TaskText $taskText -ResolveOnly

    Assert-Equal $resolved.intent 'generated-product' 'end-to-end simulation should resolve as generated-product'
    Assert-Equal $resolved.mode 'product-listing' 'end-to-end simulation should use translated product-listing route'
    Assert-Equal $resolved.translation_source 'translator' 'end-to-end simulation should exercise translator fallback'
    Assert-NotEmpty $resolved.task_spec 'end-to-end simulation should expose a task spec'
    Assert-NotEmpty $resolved.page_bundle 'end-to-end simulation should expose compiled page bundle'
    Assert-NotEmpty $resolved.component_bundle 'end-to-end simulation should expose compiled component bundle'
    Assert-NotEmpty $resolved.app_patch 'end-to-end simulation should expose compiled app patch'

    $pageBundle = $resolved.page_bundle | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $componentBundle = $resolved.component_bundle | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $appPatch = $resolved.app_patch | ConvertTo-Json -Depth 20 | ConvertFrom-Json

    $componentWxml = @($componentBundle.files | Where-Object { $_.path -like '*.wxml' })[0]
    $componentWxml.content = [string]$componentWxml.content -replace ".*price.*(\r?\n)?", ''

    $execution = Invoke-WechatTaskExecution `
        -TaskSpec $resolved.task_spec `
        -PageBundle $pageBundle `
        -ComponentBundle $componentBundle `
        -AppPatch $appPatch `
        -OutputDir $simulationRoot `
        -Preview $false

    Assert-Equal $execution.status 'success' 'end-to-end simulation should execute successfully in sandbox'
    Assert-True ($execution.project_dir.StartsWith($sandboxRoot, [System.StringComparison]::OrdinalIgnoreCase)) 'end-to-end simulation must stay under sandbox'
    Assert-Equal $execution.project_identity.app_title 'Product Center' 'end-to-end simulation should set translated product title'
    Assert-Equal $execution.project_identity.project_name 'product-center-app' 'end-to-end simulation should set translated project name'
    Assert-Equal $execution.acceptance.status 'pass' 'end-to-end simulation should include a passing acceptance result'
    Assert-NotEmpty $execution.acceptance_repair_loop 'end-to-end simulation should run the acceptance repair loop'
    Assert-Equal $execution.acceptance_repair_loop.status 'pass' 'end-to-end simulation repair loop should recover the broken product bundle'
    Assert-True (@($execution.acceptance_repair_loop.history).Count -ge 1) 'end-to-end simulation should record a repair history'

    $wxmlPath = Join-Path $execution.project_dir 'pages\index\index.wxml'
    $wxml = Get-Content $wxmlPath -Raw -Encoding UTF8
    Assert-True ($wxml.Contains('Featured Products')) 'end-to-end simulation should write the product listing hero title'
    Assert-True ($wxml.Contains('Spicy Braised Combo')) 'end-to-end simulation should render sample product content'
    $componentWxmlPath = Join-Path $execution.project_dir 'components\product-card\index.wxml'
    $componentWxmlText = Get-Content $componentWxmlPath -Raw -Encoding UTF8
    Assert-True ($componentWxmlText.Contains('price')) 'end-to-end simulation should restore a price field through repair'

    $detailTaskText = 'build a product detail page with product image, title, description, price, and an add to cart CTA'
    $detailResolved = Invoke-WechatTask -TaskText $detailTaskText -ResolveOnly
    Assert-Equal $detailResolved.intent 'generated-product' 'product detail simulation should resolve as generated-product'
    Assert-Equal $detailResolved.mode 'product-detail' 'product detail simulation should use translated product-detail route'
    Assert-Equal $detailResolved.translation_source 'translator' 'product detail simulation should exercise translator fallback'

    $detailPageBundle = $detailResolved.page_bundle | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $detailComponentBundle = $detailResolved.component_bundle | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $detailAppPatch = $detailResolved.app_patch | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $detailWxml = @($detailPageBundle.files | Where-Object { $_.path -like '*.wxml' })[0]
    $detailWxml.content = [string]$detailWxml.content -replace "<image class='product-image'[^>]*/>\r?\n?", ''

    $detailExecution = Invoke-WechatTaskExecution `
        -TaskSpec $detailResolved.task_spec `
        -PageBundle $detailPageBundle `
        -ComponentBundle $detailComponentBundle `
        -AppPatch $detailAppPatch `
        -OutputDir $detailSimulationRoot `
        -Preview $false

    Assert-Equal $detailExecution.status 'success' 'product detail simulation should execute successfully in sandbox'
    Assert-Equal $detailExecution.acceptance.status 'pass' 'product detail simulation should end with passing acceptance'
    Assert-NotEmpty $detailExecution.acceptance_repair_loop 'product detail simulation should trigger acceptance repair loop'
    Assert-Equal $detailExecution.acceptance_repair_loop.status 'pass' 'product detail simulation repair loop should recover the broken detail page'
    $detailPageWxmlPath = Join-Path $detailExecution.project_dir 'pages\index\index.wxml'
    $detailPageWxml = Get-Content $detailPageWxmlPath -Raw -Encoding UTF8
    Assert-True ($detailPageWxml.Contains('<image')) 'product detail simulation should restore product image markup'

    New-TestResult -Name 'task-end-to-end-simulation' -Data @{
        pass = $true
        exit_code = 0
        status = $execution.status
        route_mode = $resolved.mode
        translation_source = $resolved.translation_source
        project_dir = $execution.project_dir
        detail_route_mode = $detailResolved.mode
        detail_status = $detailExecution.status
    }
}
finally {
    if (Test-Path $simulationRoot) {
        Remove-Item -Path $simulationRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $detailSimulationRoot) {
        Remove-Item -Path $detailSimulationRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
