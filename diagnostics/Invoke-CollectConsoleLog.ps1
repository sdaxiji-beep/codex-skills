function Get-WechatConsoleLogCandidates {
  $candidates = New-Object System.Collections.Generic.List[string]
  $root = Join-Path $env:LOCALAPPDATA "微信开发者工具\User Data"
  if (-not (Test-Path $root)) {
    return @()
  }

  $profiles = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

  foreach ($profile in $profiles) {
    $weappLog = Join-Path $profile.FullName "WeappLog"
    if (-not (Test-Path $weappLog)) { continue }
    foreach ($name in @("stderr.log", "launch.log", "report.log")) {
      $path = Join-Path $weappLog $name
      if (Test-Path $path -and -not $candidates.Contains($path)) {
        $candidates.Add($path)
      }
    }
  }

  return @($candidates)
}

function Invoke-CollectConsoleLog {
  param(
    [string[]]$ExtraSources = @(),
    [string]$OutputPath = "",
    [int]$TailLines = 600
  )

  $repoRoot = Split-Path $PSScriptRoot -Parent
  if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "artifacts\wechat-devtools\console\latest.log"
  }
  $outputDir = Split-Path $OutputPath -Parent
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

  $sources = New-Object System.Collections.Generic.List[string]
  foreach ($s in @($ExtraSources)) {
    if (-not [string]::IsNullOrWhiteSpace([string]$s) -and (Test-Path $s) -and -not $sources.Contains($s)) {
      $sources.Add($s)
    }
  }
  foreach ($s in @(Get-WechatConsoleLogCandidates)) {
    if (-not $sources.Contains($s)) {
      $sources.Add($s)
    }
  }

  $chunks = New-Object System.Collections.Generic.List[string]
  foreach ($src in @($sources)) {
    try {
      $lines = Get-Content -Path $src -Tail $TailLines -ErrorAction Stop
      if ($null -ne $lines -and @($lines).Count -gt 0) {
        $chunks.Add("===== source: $src =====")
        foreach ($line in @($lines)) {
          $chunks.Add([string]$line)
        }
      }
    }
    catch {
      # Non-fatal; keep collecting from other sources.
    }
  }

  $content = if ($chunks.Count -gt 0) {
    ($chunks -join [Environment]::NewLine)
  } else {
    ""
  }

  Set-Content -Path $OutputPath -Value $content -Encoding UTF8

  return [PSCustomObject]@{
    status = if ($chunks.Count -gt 0) { "success" } else { "empty" }
    output_path = $OutputPath
    source_count = @($sources).Count
    written_line_count = @($chunks).Count
    sources = @($sources)
    timestamp = (Get-Date -Format "o")
  }
}

