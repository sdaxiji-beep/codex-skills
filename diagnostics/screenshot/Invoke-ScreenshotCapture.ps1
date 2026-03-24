function Invoke-ScreenshotCapture {
  param(
    [string]$OutputDir = "$PSScriptRoot\captures",
    [string]$FilePrefix = "page-snapshot"
  )

  if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
  $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
  $outPath = Join-Path $OutputDir "$FilePrefix-$timestamp-$suffix.png"

  Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinCapture {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@ -ErrorAction SilentlyContinue

  Add-Type @"
using System;
using System.Diagnostics;
public class ProcWindow {
  public static IntPtr GetMainWindowByProcess(string procName) {
    foreach (var p in Process.GetProcessesByName(procName)) {
      if (p.MainWindowHandle != IntPtr.Zero) return p.MainWindowHandle;
    }
    return IntPtr.Zero;
  }
}
"@ -ErrorAction SilentlyContinue

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $bmp = $null
  $g = $null

  $hwnd = [ProcWindow]::GetMainWindowByProcess("wechatdevtools")
  if ($hwnd -eq [IntPtr]::Zero) {
    $hwnd = [ProcWindow]::GetMainWindowByProcess("wechatwebdevtools")
  }

  try {
    if ($hwnd -ne [IntPtr]::Zero) {
      [WinCapture]::SetForegroundWindow($hwnd) | Out-Null
      Start-Sleep -Milliseconds 500
      $rect = New-Object WinCapture+RECT
      [WinCapture]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
      $width = [Math]::Max(1, ($rect.Right - $rect.Left))
      $height = [Math]::Max(1, ($rect.Bottom - $rect.Top))
      $bmp = New-Object System.Drawing.Bitmap($width, $height)
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
    } else {
      Write-Warning "[capture] DevTools window not found, fallback to full-screen capture"
      $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
      $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    }

    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    if ($null -ne $g) { $g.Dispose() }
    if ($null -ne $bmp) { $bmp.Dispose() }
  }

  if (Test-Path $outPath) { return $outPath }
  throw "capture failed, output file not created: $outPath"
}
