param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$spec = New-WechatTaskSpec `
  -TaskIntent 'generated-product' `
  -TaskFamily 'product-listing' `
  -RouteMode 'product-listing' `
  -Goal 'Build a product listing landing page' `
  -TargetPages @(
    (New-WechatTaskTarget -Path 'pages/index/index' -BundleKind 'page')
  ) `
  -RequiredComponents @(
    (New-WechatTaskTarget -Path 'components/product-card/index' -BundleKind 'component')
  ) `
  -AppPatch @{
    navigationBarTitleText = 'Product Center'
    projectname = 'product-center-app'
  } `
  -AcceptanceChecks @(
    (New-WechatTaskAcceptanceCheck -Type 'page_text' -Target 'pages/index/index.wxml' -Expected 'Featured Products')
  ) `
  -RepairStrategy (
    New-WechatTaskRepairStrategy -Family 'product-listing' -MaxRounds 3 -SupportedCodes @(
      'missing_product_list_container',
      'missing_price_display'
    )
  )

Assert-Equal $spec.task_intent 'generated-product' 'task intent should be preserved'
Assert-Equal $spec.task_family 'product-listing' 'task family should be preserved'
Assert-Equal $spec.route_mode 'product-listing' 'route mode should be preserved'
Assert-Equal @($spec.target_pages).Count 1 'task spec should contain one page target'
Assert-Equal @($spec.required_components).Count 1 'task spec should contain one component target'
Assert-Equal @($spec.acceptance_checks).Count 1 'task spec should contain one acceptance check'
Assert-Equal $spec.app_patch.navigationBarTitleText 'Product Center' 'app patch should preserve navigation title'
Assert-Equal $spec.repair_strategy.family 'product-listing' 'task spec should preserve repair strategy family'
Assert-Equal $spec.repair_strategy.max_rounds 3 'task spec should preserve repair strategy max rounds'

New-TestResult -Name 'wechat-task-spec' -Data @{
  pass = $true
  exit_code = 0
  task_intent = $spec.task_intent
  task_family = $spec.task_family
  route_mode = $spec.route_mode
  acceptance_checks = @($spec.acceptance_checks).Count
}
