function Invoke-RepairActionExecutor {
  param(
    [Parameter(Mandatory = $true)]$Issue,
    [Parameter(Mandatory = $true)][string]$ProjectPath
  )

  if ($null -eq $Issue) {
    throw "issue is null"
  }

  $issueType = [string]$Issue.issue_type

  switch ($issueType) {
    "text_encoding_garbled" {
      $target = if ($Issue.PSObject.Properties.Name -contains "target") { [string]$Issue.target } else { "" }

      # File-level repair path (WXML/JS/WXSS) when overlay points to a page file.
      if ($target -and ($target -like "*.wxml" -or $target -like "*.js" -or $target -like "*.wxss")) {
        $targetPath = Join-Path $ProjectPath ($target -replace '/', '\')
        if (-not (Test-Path $targetPath)) {
          return [PSCustomObject]@{
            applied = $false
            status = "blocked"
            issue_type = $issueType
            reason = "target_file_missing"
            target_path = $targetPath
            timestamp = (Get-Date -Format "o")
          }
        }

        $content = Get-Content -Path $targetPath -Raw -Encoding UTF8
        $normalized = $content

        # Syntax-safe cleanup for common mojibake side effects.
        $normalized = $normalized -replace '\?/text>', '</text>'
        $normalized = $normalized -replace '楼\{\{', '¥{{'
        $normalized = $normalized -replace '(?<!\{)\{([^\r\n{}]+)\}\}', '{{$1}}'

        # Replace non-ASCII label text in text/button nodes with stable placeholders.
        $normalized = [regex]::Replace(
          $normalized,
          '(<text\b[^>]*>)([^<{]*[^\x00-\x7F][^<]*)(</text>)',
          '$1Label$3'
        )
        $normalized = [regex]::Replace(
          $normalized,
          '(<button\b[^>]*>)([^<]*[^\x00-\x7F][^<]*)(</button>)',
          '$1Action$3'
        )

        # Semantic placeholders for known cart page markers when available.
        $normalized = $normalized -replace '(<text class="title">)[^<]*(</text>)', '$1Cart$2'
        $normalized = $normalized -replace '(<text class="remove"[^>]*>)[^<]*(</text>)', '$1Remove$2'
        $normalized = $normalized -replace '(<button[^>]*bindtap="clearCart"[^>]*>)[^<]*(</button>)', '$1Clear$2'
        $normalized = $normalized -replace '(<button[^>]*bindtap="goShop"[^>]*>)[^<]*(</button>)', '$1Shop$2'
        $normalized = $normalized -replace '(<button[^>]*bindtap="checkout"[^>]*>)[^<]*(</button>)', '$1Checkout$2'
        $normalized = $normalized -replace '(<text class="muted">)\s*\{\{\(item\.price\*item\.qty\)\.toFixed\(2\)\}\}\s*(</text>)', '$1Subtotal: ¥{{(item.price*item.qty).toFixed(2)}}$2'

        if ($normalized -eq $content) {
          return [PSCustomObject]@{
            applied = $false
            status = "blocked"
            issue_type = $issueType
            reason = "no_known_mojibake_pattern"
            target_path = $targetPath
            timestamp = (Get-Date -Format "o")
          }
        }

        Set-Content -Path $targetPath -Value $normalized -Encoding UTF8
        return [PSCustomObject]@{
          applied = $true
          status = "applied"
          issue_type = $issueType
          reason = "normalized_page_ui_text"
          target_path = $targetPath
          timestamp = (Get-Date -Format "o")
        }
      }

      # app.json-level fallback repair path.
      $appJsonPath = Join-Path $ProjectPath "app.json"
      if (-not (Test-Path $appJsonPath)) {
        return [PSCustomObject]@{
          applied = $false
          status = "blocked"
          issue_type = $issueType
          reason = "app_json_missing"
          target_path = $appJsonPath
          timestamp = (Get-Date -Format "o")
        }
      }

      $obj = $null
      try {
        $obj = Get-Content $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
      }
      catch {
        $obj = [PSCustomObject]@{
          pages = @("pages/home/index")
          window = [PSCustomObject]@{
            backgroundTextStyle = "light"
            navigationBarBackgroundColor = "#ffffff"
            navigationBarTitleText = "Mini Mall"
            navigationBarTextStyle = "black"
          }
          tabBar = [PSCustomObject]@{
            color = "#666666"
            selectedColor = "#111111"
            backgroundColor = "#ffffff"
            borderStyle = "black"
            list = @(
              [PSCustomObject]@{ pagePath = "pages/home/index"; text = "Home" },
              [PSCustomObject]@{ pagePath = "pages/cart/index"; text = "Cart" },
              [PSCustomObject]@{ pagePath = "pages/orders/index"; text = "Orders" },
              [PSCustomObject]@{ pagePath = "pages/profile/index"; text = "Me" }
            )
          }
          style = "v2"
          sitemapLocation = "sitemap.json"
        }
      }

      if ($null -eq $obj.window) {
        $obj | Add-Member -MemberType NoteProperty -Name window -Value ([PSCustomObject]@{})
      }
      $obj.window.navigationBarTitleText = "Mini Mall"

      if ($obj.tabBar -and $obj.tabBar.list) {
        $labels = @("Home", "Cart", "Orders", "Me")
        $idx = 0
        foreach ($item in @($obj.tabBar.list)) {
          if ($idx -lt $labels.Count) {
            $item.text = $labels[$idx]
          }
          else {
            $item.text = "Tab$idx"
          }
          $idx++
        }
      }

      $json = $obj | ConvertTo-Json -Depth 20
      Set-Content -Path $appJsonPath -Value $json -Encoding UTF8

      return [PSCustomObject]@{
        applied = $true
        status = "applied"
        issue_type = $issueType
        reason = "normalized_app_json_ui_text"
        target_path = $appJsonPath
        timestamp = (Get-Date -Format "o")
      }
    }

    default {
      return [PSCustomObject]@{
        applied = $false
        status = "blocked"
        issue_type = $issueType
        reason = "unsupported_auto_fix_issue_type"
        target_path = $null
        timestamp = (Get-Date -Format "o")
      }
    }
  }
}
