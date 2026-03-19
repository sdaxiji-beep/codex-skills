# PROJECT_STATE.md
Last updated: 2026-03-19

## Current blocker
Package this workspace as a clean standalone skill repo without touching `G:\codex专属`, with preview-first sharing and local-only real release setup.

## Completed
- copied WeChat skill directories from `G:\codex专属` into `G:\codex_skills`
- copied supporting source directories: `scripts`, `templates`, `config`, `mcp`
- copied required test fixtures: `sandbox`, `specs`
- excluded runtime directories and sensitive material from the copy:
  - `generated`
  - `artifacts`
  - `keys`
  - `node_modules` under `mcp`
- rewrote workspace docs for `codex_skills`
- validated all four skill folders with `quick_validate.py`
- initialized standalone git repository in `G:\codex_skills`
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

## Next
- optional: remove non-skill root files that are not needed for sharing
- optional: publish this workspace as a dedicated skill repo
