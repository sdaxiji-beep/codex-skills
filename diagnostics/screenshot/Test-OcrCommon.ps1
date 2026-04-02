function Test-WindowsOcrAvailable {
  try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime]
    return (@([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages).Count -gt 0)
  }
  catch {
    return $false
  }
}

function New-OcrTestImage {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Lines,
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  Add-Type -AssemblyName System.Drawing -ErrorAction Stop

  $width = 1400
  $height = [Math]::Max(500, (120 * $Lines.Count))
  $bitmap = New-Object System.Drawing.Bitmap $width, $height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear([System.Drawing.Color]::White)
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  try {
    $font = New-Object System.Drawing.Font('Microsoft YaHei UI', 30)
  }
  catch {
    $font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericSansSerif, 30)
  }

  $brush = [System.Drawing.Brushes]::Black
  $y = 24
  foreach ($line in $Lines) {
    $graphics.DrawString($line, $font, $brush, 24, $y)
    $y += 86
  }

  $dir = Split-Path $Path -Parent
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $bitmap.Dispose()

  return $Path
}
