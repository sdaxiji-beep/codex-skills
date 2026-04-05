# Changelog

Last updated: 2026-04-05

## Release Candidate v2.1.0-rc.1

- version alignment for the next public release candidate
- local package simulation verified after adding `.npmignore`
- local simplified real drill remains green after release-cleanup changes
- current release-prep marker:
  - `v2.1.0-rc.1`

## Asset Registry Milestone v1.0

### Phase 3.1-3.5

- established `assets\registry.json` as the compiler-owned asset registry
- migrated stable core components into physical assets:
  - `cta-button`
  - `product-card`
  - `buy-button`
- added `schemas\wechat-asset-registry.schema.json`
- added `scripts\wechat-asset-registry-validator.ps1`
- added registry structure, file existence, non-empty content, name/path consistency, dependency, and acceptance-rule mapping validation

### Phase 4.1-4.3

- migrated stable page templates into physical assets:
  - `product-listing`
  - `product-detail`
  - `coupon-empty-state`
- upgraded the compiler to use registry-first page-template loading with hardcoded fallback preserved
- verified page-template parity against legacy hardcoded output

### Phase 5

- added registry-driven real DevTools end-to-end drill
- verified the prompt:
  - `build a product listing mini program with a CTA button`
- confirmed the real pipeline succeeds through:
  - translator
  - compiler
  - executor
  - acceptance
  - DevTools open

### Milestone metrics

- `5` stable registry-backed components
- `5` stable registry-backed page templates
- `100%` registry hit verified in the latest real E2E drill for the migrated product-listing path
- fallback generation paths remain in place for transition safety

## Food Order + Cross-Page Milestone

### Phase 12

- added a registry-backed `food-order` family
- added stable components:
  - `food-item`
  - `cart-summary`
- added stable page template:
  - `food-order`
- extended translator, compiler, executor, acceptance, and repair for multi-component food ordering flows

### Phase 13

- added stable page template:
  - `food-checkout`
- validated `food-order-flow` as a multi-page registry-first flow
- verified:
  - app route registration for both pages
  - navigator link from listing page to checkout page
  - cross-page generated drill success in sandbox

### Release Candidate 1 status

- stable internal architecture now includes:
  - registry-first components
  - registry-first page templates
  - acceptance-driven repair
  - multi-page route-aware generation
- current maintenance marker:
  - `v2.1.0-rc.1`
