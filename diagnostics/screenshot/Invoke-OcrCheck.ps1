. "$PSScriptRoot\..\New-PageIssue.ps1"

function Invoke-OcrCheck {
  param(
    [string]$ScreenshotPath,
    [string]$PagePath,
    [string]$ProjectPath
  )

  if (-not (Test-Path $ScreenshotPath)) {
    throw "Screenshot file not found: $ScreenshotPath"
  }

  Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop

  $null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]
  $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
  $null = [Windows.Storage.FileAccessMode, Windows.Storage, ContentType = WindowsRuntime]
  $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
  $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
  $null = [Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
  $null = [Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime]
  $null = [Windows.Media.Ocr.OcrResult, Windows.Media.Ocr, ContentType = WindowsRuntime]

  function Invoke-WinRtAsyncResult {
    param(
      [Parameter(Mandatory = $true)]$Operation,
      [Parameter(Mandatory = $true)][Type]$ResultType
    )

    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
      Where-Object {
        $_.Name -eq 'AsTask' -and
        $_.IsGenericMethodDefinition -and
        $_.GetGenericArguments().Count -eq 1 -and
        $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
      } |
      Select-Object -First 1

    if ($null -eq $method) {
      throw "Unable to resolve a WinRT AsTask<TResult> overload"
    }

    $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    return $task.GetAwaiter().GetResult()
  }

  function New-PassedOcrIssue {
    param([string]$Actual)

    return [PSCustomObject]@{
      issue_id     = "passed|$PagePath|screenshot-ocr"
      status       = "passed"
      issue_type   = $null
      target       = $null
      expected     = "no visible compile/runtime error text"
      actual       = $Actual
      severity     = "info"
      source       = "screenshot"
      page_path    = $PagePath
      project_path = $ProjectPath
      repair_hint  = ""
      retryable    = $false
      timestamp    = (Get-Date -Format "o")
    }
  }

  function Get-OcrEngine {
    $preferred = @('zh-Hans-CN', 'zh-Hans', 'zh-Hant-HK')
    $available = @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages)

    foreach ($tag in $preferred) {
      $language = $available | Where-Object { $_.LanguageTag -eq $tag } | Select-Object -First 1
      if ($null -ne $language) {
        $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
        if ($null -ne $engine) {
          return $engine
        }
      }
    }

    foreach ($language in $available) {
      $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
      if ($null -ne $engine) {
        return $engine
      }
    }

    return $null
  }

  function Get-NormalizedTargetFromOcrText {
    param([string]$Text)

    $compact = ($Text -replace '\s+', '')
    if ($compact -match '(\.?/?pages/[A-Za-z0-9_./-]+\.wxm[lI1])') {
      return (($matches[1] -replace '^\./', '') -replace '\.wxm[lI1]$', '.wxml')
    }

    return $null
  }

  function Get-OcrExcerpt {
    param([string]$Text)

    $trimmed = ($Text -replace '\s+', ' ').Trim()
    if ($trimmed.Length -le 220) {
      return $trimmed
    }

    return ($trimmed.Substring(0, 220) + '...')
  }

  $stream = $null
  $bitmap = $null
  $ocrBitmap = $null
  try {
    $engine = Get-OcrEngine
    if ($null -eq $engine) {
      throw "Windows OCR engine is unavailable"
    }

    $file = Invoke-WinRtAsyncResult `
      -Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ScreenshotPath)) `
      -ResultType ([Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime])

    $stream = Invoke-WinRtAsyncResult `
      -Operation ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) `
      -ResultType ([Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime])

    $decoder = Invoke-WinRtAsyncResult `
      -Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) `
      -ResultType ([Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime])

    $bitmap = Invoke-WinRtAsyncResult `
      -Operation ($decoder.GetSoftwareBitmapAsync()) `
      -ResultType ([Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime])

    $ocrBitmap = if ($bitmap.BitmapPixelFormat -ne [Windows.Graphics.Imaging.BitmapPixelFormat]::Gray8) {
      [Windows.Graphics.Imaging.SoftwareBitmap]::Convert(
        $bitmap,
        [Windows.Graphics.Imaging.BitmapPixelFormat]::Gray8
      )
    } else {
      $bitmap
    }

    $ocrResult = Invoke-WinRtAsyncResult `
      -Operation ($engine.RecognizeAsync($ocrBitmap)) `
      -ResultType ([Windows.Media.Ocr.OcrResult, Windows.Media.Ocr, ContentType = WindowsRuntime])

    $text = [string]$ocrResult.Text
    $normalized = ($text -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
      return (New-PassedOcrIssue -Actual "ocr found no meaningful text")
    }

    $normalizedLower = $normalized.ToLowerInvariant()
    $target = Get-NormalizedTargetFromOcrText -Text $normalized
    if ([string]::IsNullOrWhiteSpace($target)) {
      $target = $null
    }
    $excerpt = Get-OcrExcerpt -Text $normalized

    $compileMarker = (
      ($normalizedLower -match 'unexpected token') -or
      ($normalizedLower -match 'bad value') -or
      (($normalizedLower -match 'compile error' -or $normalizedLower -match 'wxml') -and
        ($normalizedLower -match '\.wxm' -or $normalizedLower -match 'files://pages/' -or $normalizedLower -match 'pages/'))
    )

    if ($compileMarker) {
      return New-PageIssue `
        -IssueType   "generation_gate_rejected" `
        -Source      "screenshot" `
        -PagePath    $PagePath `
        -ProjectPath $ProjectPath `
        -Target      $target `
        -Expected    "no visible compile error text" `
        -Actual      ("ocr_text: " + $excerpt) `
        -RepairHint  "visible compile text detected in the screenshot; repair the referenced WXML or gate violation and rerun detection"
    }

    $runtimeMarker = (
      ($normalizedLower -match '__route__ is not defined') -or
      ($normalizedLower -match 'referenceerror') -or
      ($normalizedLower -match 'appservicesdkscripterror')
    )

    if ($runtimeMarker) {
      return New-PageIssue `
        -IssueType   "error_page_visible" `
        -Source      "screenshot" `
        -PagePath    $PagePath `
        -ProjectPath $ProjectPath `
        -Expected    "no visible runtime error text" `
        -Actual      ("ocr_text: " + $excerpt) `
        -RepairHint  "visible runtime error text detected in the screenshot; inspect the page runtime blocker and rerun detection"
    }

    return (New-PassedOcrIssue -Actual "ocr did not match known blocker text")
  }
  finally {
    if ($null -ne $ocrBitmap -and $ocrBitmap -ne $bitmap) {
      $ocrBitmap.Dispose()
    }

    if ($null -ne $bitmap) {
      $bitmap.Dispose()
    }

    if ($null -ne $stream) {
      $stream.Dispose()
    }
  }
}
