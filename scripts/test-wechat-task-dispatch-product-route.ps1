param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$taskText = 'build a coupon center mini program with an empty-state page, a claim coupon CTA, simple coupon rules text, and a clean mobile-first layout'

$resolved = Invoke-WechatTask -TaskText $taskText -ResolveOnly
Assert-Equal $resolved.intent 'generated-product' 'coupon empty-state task should resolve to generated-product intent'
Assert-Equal $resolved.mode 'coupon-empty-state' 'coupon empty-state task should resolve to coupon-empty-state mode'

$recommended = Invoke-WechatTask -TaskText $taskText -RecommendOnly
Assert-True ($null -ne $recommended) 'coupon empty-state task should return a recommendation'
Assert-Equal $recommended.label 'generated-coupon-empty-state' 'coupon empty-state task should recommend generated-coupon-empty-state'
Assert-Equal $recommended.safe $true 'coupon empty-state task should remain safe'

$handoff = Invoke-WechatTask -TaskText $taskText -HandoffOnly
Assert-Equal $handoff.guard_status 'safe_to_run' 'coupon empty-state handoff should be safe to run'
Assert-Equal $handoff.route_intent 'generated-product' 'coupon empty-state handoff should preserve generated-product intent'

$activityTask = 'build a campaign page that says the event has not started yet, shows a notify me CTA, and keeps a simple mobile-first activity layout'
$activityResolved = Invoke-WechatTask -TaskText $activityTask -ResolveOnly
Assert-Equal $activityResolved.intent 'generated-product' 'activity not started task should resolve to generated-product intent'
Assert-Equal $activityResolved.mode 'activity-not-started' 'activity not started task should resolve to activity-not-started mode'

$benefitsTask = 'build a benefits center page with an empty-state message, an unlock benefits CTA, and a member perks explanation section'
$benefitsResolved = Invoke-WechatTask -TaskText $benefitsTask -ResolveOnly
Assert-Equal $benefitsResolved.intent 'generated-product' 'benefits empty-state task should resolve to generated-product intent'
Assert-Equal $benefitsResolved.mode 'benefits-empty-state' 'benefits empty-state task should resolve to benefits-empty-state mode'

$productListTask = 'build a product listing mini program page with featured goods cards, prices, and a clean mobile-first catalog layout'
$productListResolved = Invoke-WechatTask -TaskText $productListTask -ResolveOnly
Assert-Equal $productListResolved.intent 'generated-product' 'product listing task should resolve to generated-product intent'
Assert-Equal $productListResolved.mode 'product-listing' 'product listing task should resolve to product-listing mode'

$productDetailTask = 'build a product detail page with product image, title, description, price, and an add to cart CTA'
$productDetailResolved = Invoke-WechatTask -TaskText $productDetailTask -ResolveOnly
Assert-Equal $productDetailResolved.intent 'generated-product' 'product detail task should resolve to generated-product intent'
Assert-Equal $productDetailResolved.mode 'product-detail' 'product detail task should resolve to product-detail mode'

New-TestResult -Name 'wechat-task-dispatch-product-route' -Data @{
    pass = $true
    exit_code = 0
    resolved_intent = $resolved.intent
    resolved_mode = $resolved.mode
    recommended_label = $recommended.label
    handoff_guard_status = $handoff.guard_status
    activity_mode = $activityResolved.mode
    benefits_mode = $benefitsResolved.mode
    product_listing_mode = $productListResolved.mode
    product_detail_mode = $productDetailResolved.mode
}
