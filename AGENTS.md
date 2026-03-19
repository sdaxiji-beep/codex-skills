# AGENTS.md

## Startup
1. `Get-Content "G:\codex_skills\PROJECT_STATE.md" -Raw`
2. Start from `## Current blocker`
3. Avoid repeating work already listed under `## Completed`
4. Update `PROJECT_STATE.md` after each completed task

## Constraints
- Do not modify `G:\codex专属`
- Do not modify `D:\卤味` business code
- Treat this workspace as a packaging and skill-validation copy
- Stop before any real deploy or controlled write to external projects

## Workspace
- Root: `G:\codex_skills`
- Skills: `G:\codex_skills\.agents\skills`
- Scripts: `G:\codex_skills\scripts`
- Templates: `G:\codex_skills\templates`
- MCP: `G:\codex_skills\mcp`

## Validation
- Layer 0: `powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -GuardCheckOnly`
- Fast: `powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -SkipSmoke -Tag fast`
- Skill validation: `quick_validate.py` on each skill directory
