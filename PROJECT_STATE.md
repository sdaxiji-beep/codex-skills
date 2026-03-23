# PROJECT_STATE.md
Last updated: 2026-03-22

## Current blocker
Prepare a clean v1.1 release branch that reflects the real local capability set (page generation, component generation, app.json patch flow) without pulling in unrelated workspace noise.

## Completed
- copied WeChat skill directories from the sibling source workspace into this repo
- copied supporting source directories: `scripts`, `templates`, `config`, `mcp`
- copied required test fixtures: `sandbox`, `specs`
- excluded runtime directories and sensitive material from the copy:
  - `generated`
  - `artifacts`
  - `keys`
  - `node_modules` under `mcp`
- rewrote workspace docs for `codex_skills`
- validated all four skill folders with `quick_validate.py`
- initialized this repo as a standalone git repository
- global self-check passed: Layer 0 `107` scripts, fast-gate `41/41`
- added local-only real release setup flow: `Invoke-WechatReleaseSetup`
- doctor now reports release readiness
- real upload/deploy paths now require local `config\local-release.config.json`
- generated project real upload returns `needs_release_setup` until local release setup is completed
- release guard skill updated to require release setup before real upload/deploy
- local release config added to `.gitignore`
- updated baseline after release-setup integration: Layer 0 `109` scripts, fast-gate `42/42`
- deep self-check passed: full regression `68/68`
- doctor runtime now resolves CLI path correctly; remaining doctor warnings are environment-level:
  - DevTools open API unreachable on current port
  - local release setup not yet created in this shared workspace
- README homepage copy refreshed to emphasize prompt-to-preview flow and clearer install paths
- README portability fixed: removed hardcoded repo drive path and replaced validator machine path with placeholders
- added standalone `scripts\generation-gate-v1.ps1` page-level bundle validator with retryable vs hard-fail status
- added focused validator coverage in `scripts\test-generation-gate-v1.ps1`
- added standalone `scripts\wechat-apply-bundle.ps1` retry-contract applier for gated bundle writes
- added focused applier coverage in `scripts\test-wechat-apply-bundle.ps1`
- validated page-generation gate path: focused tests pass and workspace guard-check remains green (`114` scripts)
- added `Invoke-WechatGeneratePage` to create page-generation specs and stable bundle targets for page-level agent work
- added `wechat-page-generator` skill with Generation Gate bundle/apply workflow
- validated page-generator integration: new skill passes `quick_validate.py`, guard-check passes (`116` scripts), fast regression passes (`43/43`)
- real page-generation pressure drill completed on `pages/home/index`: bad bundle rejected, corrected bundle applied, spec rendering bug fixed
- tightened `wechat-page-generator` skill instructions: dynamic bundle path required and exit-code-1 retry loop must stay autonomous
- README v1.1 updated to document the Generation Gate architecture, three-tier guarantee model, and real pressure-drill outcome
- added standalone component gate script (scripts\generation-gate-component-v1.ps1) and focused coverage (scripts\test-generation-gate-component-v1.ps1); focused test pass, guard-check pass (118 scripts)
- added standalone component apply path (`scripts\wechat-apply-component-bundle.ps1`) and component spec entrypoint (`scripts\wechat-generate-component.ps1`)
- validated component generation path: focused apply/generate tests pass, guard-check passes (`122` scripts), fast regression passes (`46/46`)
- added `wechat-component-generator` skill with autonomous retry instructions for component bundle generation
- page-component bridge added: `Invoke-WechatGeneratePage` now injects available workspace components into specs, and `generation-gate-v1.ps1` validates `usingComponents` paths against `/components/<name>/index`
- added app.json patch gate (`scripts\generation-gate-app-json-v1.ps1`) and patch applier (`scripts\wechat-apply-app-json-patch.ps1`) for append_pages-only global registration
- added app.json patch entrypoint (`scripts\wechat-patch-app-json.ps1`) and `wechat-global-config-modifier` skill for spec-driven global page registration
- validated app.json patch entry path: focused patch-entry/apply tests pass, `wechat-global-config-modifier` validates cleanly, guard-check passes (`128` scripts), fast regression passes (`49/49`)
- fixed notebook template `app.json` encoding hazard by switching the title field to JSON Unicode escapes; notebook template parsing and create/build flows now validate cleanly again
- unified generated JSON writes to UTF-8 without BOM for page bundles, component bundles, app.json patches, and generated project config writes; new notebook preview failures now report the real blocker (`touristappid` invalid for preview) instead of JSON parse noise
- created isolated release-prep worktree/branch (`codex/v1.1-release-prep`) from `b29ae81` so v1.1 packaging work can proceed without mutating the dirty source workspace
- copied only v1.1-relevant skill, script, template, and doc changes into the release-prep branch; excluded unrelated `specs/` noise from release prep scope
- normalized release-prep docs/skills away from UTF-8 BOM at key frontmatter files (`AGENTS.md`, `wechat-lab-builder`, new v1.1 skills, README)
- fixed UTF-8 no-BOM read hazards on the v1.1 path by reading bundle/patch/project JSON with `-Encoding UTF8` in:
  - `scripts\wechat-apply-bundle.ps1`
  - `scripts\wechat-apply-component-bundle.ps1`
  - `scripts\wechat-apply-app-json-patch.ps1`
  - `scripts\wechat-generated-project.ps1`
- fixed focused regression coverage for the app.json patch path to read UTF-8 app.json correctly in `scripts\test-wechat-apply-app-json-patch.ps1`
- release-prep validation passed: Layer 0 `129` scripts, fast-gate `50/50`
- release-prep minimal golden chain passed in a generated notebook shell:
  - component bundle applied to `components/cta-button/index.*`
  - page bundle applied to `pages/about/index.*`
  - app.json append_pages patch registered `pages/about/index`
  - preview result reported `failed` truthfully
  - generated-project deploy guard returned `denied`
- public repo path hygiene pass completed on the release-prep branch:
  - removed machine-specific path examples from MCP docs and umbrella skill docs
  - removed private/business-specific dispatcher routes for old write-to-project specs
  - pruned tracked `specs/` down to public/sample specs still used by the code path
  - confirmed no tracked `.pem`/`.key` files and no tracked machine-specific paths remain outside ignored runtime outputs

## Next
- decide which non-skill root files should remain in the public repo versus stay internal-only
- review remaining line-ending noise before push
- push the v1.1 release-prep branch only after final human review


