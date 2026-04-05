# Runtime Retention Policy

Last updated: 2026-03-25

## Purpose

This repo produces runtime-only outputs during diagnostics, generation, and integration checks.

These files are useful locally, but they should not grow without bound and they must not pollute the public release surface.

## Runtime-only paths

The following paths are runtime data and are not part of the release surface:

- `artifacts/`
- `generated/`
- `diagnostics/screenshot/captures/`

## Retention policy

### Artifacts

- keep the most recent `400` files
- prune older files during maintenance
- artifacts are for local debugging and comparison only

### Screenshot captures

- keep the most recent `80` capture files
- older screenshots should be pruned first

### Generated projects

- keep the most recent `120` generated project directories
- older generated project folders should be pruned first

## Safety rules

- default cleanup mode must be `dry-run`
- deletion must only target the configured runtime paths
- cleanup must never touch:
  - tracked source files
  - templates
  - scripts
  - docs
  - config examples

## Command

Dry-run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\cleanup-runtime-data.ps1"
```

Apply cleanup:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\cleanup-runtime-data.ps1" -Apply
```

## Release posture

Release and public-share checks should assume runtime outputs are disposable local state.

The release surface should stay clean even if runtime cleanup has not been run recently.

