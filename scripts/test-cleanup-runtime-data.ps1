param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cleanup-runtime-" + [guid]::NewGuid().ToString("N"))
$artifacts = Join-Path $root 'artifacts'
$captures = Join-Path $root 'diagnostics\screenshot\captures'
$generated = Join-Path $root 'generated'

New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
New-Item -ItemType Directory -Path $captures -Force | Out-Null
New-Item -ItemType Directory -Path $generated -Force | Out-Null

foreach ($i in 1..5) {
    $file = Join-Path $artifacts ("artifact-$i.json")
    Set-Content -Path $file -Value $i -Encoding UTF8
    (Get-Item $file).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(-1 * $i)
}

foreach ($i in 1..4) {
    $file = Join-Path $captures ("capture-$i.png")
    Set-Content -Path $file -Value $i -Encoding UTF8
    (Get-Item $file).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(-1 * $i)
}

foreach ($i in 1..3) {
    $dir = Join-Path $generated ("project-$i")
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    (Get-Item $dir).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(-1 * $i)
}

$scriptPath = Join-Path $PSScriptRoot 'cleanup-runtime-data.ps1'

$dryRun = & $scriptPath -RepoRoot $root -KeepArtifacts 2 -KeepCaptures 1 -KeepGeneratedProjects 1
Assert-True $dryRun.pass 'cleanup dry-run should pass'
Assert-Equal $dryRun.mode 'dry_run' 'cleanup should default to dry-run'
Assert-Equal $dryRun.total_candidates 8 'dry-run should identify expected candidate count'

Assert-Equal @(Get-ChildItem $artifacts -File).Count 5 'dry-run must not delete artifacts'
Assert-Equal @(Get-ChildItem $captures -File).Count 4 'dry-run must not delete captures'
Assert-Equal @(Get-ChildItem $generated -Directory).Count 3 'dry-run must not delete generated projects'

$apply = & $scriptPath -RepoRoot $root -KeepArtifacts 2 -KeepCaptures 1 -KeepGeneratedProjects 1 -Apply
Assert-True $apply.pass 'cleanup apply should pass'
Assert-Equal $apply.mode 'apply' 'cleanup apply mode should be apply'

Assert-Equal @(Get-ChildItem $artifacts -File).Count 2 'apply should prune artifacts to keep count'
Assert-Equal @(Get-ChildItem $captures -File).Count 1 'apply should prune captures to keep count'
Assert-Equal @(Get-ChildItem $generated -Directory).Count 1 'apply should prune generated directories to keep count'

Remove-Item -LiteralPath $root -Recurse -Force

New-TestResult -Name 'cleanup-runtime-data' -Data @{
    pass = $true
    exit_code = 0
    total_candidates = $dryRun.total_candidates
}

