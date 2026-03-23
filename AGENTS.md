# AGENTS.md

## Startup
1. `Get-Content (Join-Path (Get-Location) "PROJECT_STATE.md") -Raw`
2. Start from `## Current blocker`
3. Avoid repeating work already listed under `## Completed`
4. Update `PROJECT_STATE.md` after each completed task

## Constraints
- Do not modify the sibling source workspace
- Do not modify external production project code
- Treat this workspace as a packaging and skill-validation copy
- Stop before any real deploy or controlled write to external projects

## Workspace
- Root: current cloned repo root
- Skills: `.agents\skills`
- Scripts: `scripts`
- Templates: `templates`
- MCP: `mcp`

## Validation
- Layer 0: `powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -GuardCheckOnly`
- Fast: `powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -SkipSmoke -Tag fast`
- Skill validation: `quick_validate.py` on each skill directory

