param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$productTranslation = Invoke-WechatTaskTranslator -TaskText 'build a menu showcase mini program homepage with price cards and featured picks'
Assert-Equal $productTranslation.status 'success' 'product translator should succeed for generic product prompt'
Assert-Equal $productTranslation.task_spec.task_intent 'generated-product' 'product translator should set generated-product task intent'
Assert-Equal $productTranslation.task_spec.task_family 'product-listing' 'product translator should map to product-listing family'
Assert-Equal $productTranslation.task_spec.route_mode 'product-listing' 'product translator should map to product-listing route'
Assert-Equal @($productTranslation.task_spec.target_pages).Count 1 'product translator should emit one target page'
Assert-Equal @($productTranslation.task_spec.required_components).Count 1 'product translator should emit one required component'

$couponTranslation = Invoke-WechatTaskTranslator -TaskText 'build a coupon center empty-state page with a claim button and rules copy'
Assert-Equal $couponTranslation.status 'success' 'coupon translator should succeed for marketing prompt'
Assert-Equal $couponTranslation.task_spec.task_intent 'generated-product' 'coupon translator should set generated-product task intent'
Assert-Equal $couponTranslation.task_spec.task_family 'marketing-empty-state' 'coupon translator should map to marketing family'
Assert-Equal $couponTranslation.task_spec.route_mode 'coupon-empty-state' 'coupon translator should map to coupon-empty-state route'

$detailTranslation = Invoke-WechatTaskTranslator -TaskText 'build a product detail page with product image, title, description, price, and an add to cart CTA'
Assert-Equal $detailTranslation.status 'success' 'product detail translator should succeed'
Assert-Equal $detailTranslation.task_spec.task_family 'product-detail' 'product detail translator should map to product-detail family'
Assert-Equal $detailTranslation.task_spec.route_mode 'product-detail' 'product detail translator should map to product-detail route'

New-TestResult -Name 'wechat-task-translator' -Data @{
  pass = $true
  exit_code = 0
  product_route = $productTranslation.task_spec.route_mode
  coupon_route = $couponTranslation.task_spec.route_mode
  detail_route = $detailTranslation.task_spec.route_mode
}
