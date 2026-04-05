# Release Description: v2.1.0-rc.1

`v2.1.0-rc.1` is the current release candidate for the registry-first WeChat generation pipeline.

## Highlights

- Registry-first architecture
  - stable physical asset registry for core components and page templates
  - compiler now prefers registered assets before falling back to legacy inline templates
- Automated repair workflow
  - structured `TaskSpec` pipeline
  - boundary validate/apply orchestration
  - acceptance checks plus acceptance-driven repair
- Cross-page routing support
  - multi-page task flows
  - app route registration for linked pages
  - navigator-based page jump verification

## Included stable internal assets

Components:

- `cta-button`
- `product-card`
- `buy-button`
- `food-item`
- `cart-summary`

Page templates:

- `coupon-empty-state`
- `product-listing`
- `product-detail`
- `food-order`
- `food-checkout`

## Supported scenarios

- marketing empty-state flows
- product listing and product detail flows
- food ordering flows
- cross-page food order -> checkout flow

## Operational strengths

- structured natural-language pipeline through `TaskSpec`
- registry-backed component/page compilation
- safe boundary validation before apply
- semantic acceptance checks
- automatic repair for supported missing elements
- real DevTools generated-project drill coverage

## Known limits

- not intended for arbitrary unconstrained prompt-to-app generation
- does not expose all translator/compiler/repair internals as public MCP contracts
- does not allow direct writes to business project code
- `touristappid` remains preview/upload constrained

## Release candidate status

- local package simulation verified
- local end-to-end simplified drill verified
- registry-first and cross-page drills verified
- current milestone marker:
  - `v2.1.0-rc.1`
