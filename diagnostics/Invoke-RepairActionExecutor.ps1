function Invoke-RepairActionExecutor {
  param(
    [Parameter(Mandatory = $true)]$Issue,
    [Parameter(Mandatory = $true)][string]$ProjectPath
  )

  if ($null -eq $Issue) {
    throw "issue is null"
  }

  function Write-Utf8NoBomFile {
    param(
      [Parameter(Mandatory = $true)][string]$Path,
      [Parameter(Mandatory = $true)][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
  }

  function Get-AppJsonObject {
    param([Parameter(Mandatory = $true)][string]$Root)

    $appJsonPath = Join-Path $Root "app.json"
    if (-not (Test-Path $appJsonPath)) {
      return $null
    }

    try {
      return (Get-Content $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
      return $null
    }
  }

  function Save-AppJsonObject {
    param(
      [Parameter(Mandatory = $true)][string]$Root,
      [Parameter(Mandatory = $true)]$AppObject
    )

    $appJsonPath = Join-Path $Root "app.json"
    $json = $AppObject | ConvertTo-Json -Depth 20
    Write-Utf8NoBomFile -Path $appJsonPath -Content $json
    return $appJsonPath
  }

  function Get-TabLabelFromPagePath {
    param([Parameter(Mandatory = $true)][string]$PagePath)

    $leaf = ($PagePath -split '/')[-2]
    if ([string]::IsNullOrWhiteSpace($leaf)) {
      return "Page"
    }

    $normalized = ($leaf -replace '[-_]+', ' ')
    return (Get-Culture).TextInfo.ToTitleCase($normalized)
  }

  function Get-PageJsonObject {
    param(
      [Parameter(Mandatory = $true)][string]$Root,
      [Parameter(Mandatory = $true)][string]$PagePath
    )

    $jsonPath = Join-Path $Root (($PagePath -replace '/', '\') + '.json')
    if (-not (Test-Path $jsonPath)) {
      return $null
    }

    try {
      return [pscustomobject]@{
        path = $jsonPath
        data = (Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop)
      }
    }
    catch {
      return $null
    }
  }

  function Save-PageJsonObject {
    param(
      [Parameter(Mandatory = $true)][string]$JsonPath,
      [Parameter(Mandatory = $true)]$JsonObject
    )

    $json = $JsonObject | ConvertTo-Json -Depth 20
    Write-Utf8NoBomFile -Path $JsonPath -Content $json
    return $JsonPath
  }

  function Get-RepairableComponentTagFromTarget {
    param([string]$Target)

    if ([string]::IsNullOrWhiteSpace($Target)) {
      return $null
    }

    $normalized = $Target.Trim().ToLowerInvariant()
    $normalized = $normalized.Trim('<', '>', '.', '#')
    if ($normalized -match '^[a-z0-9]+(?:-[a-z0-9]+)+$') {
      return $normalized
    }

    return $null
  }

  function Get-RepairableDataKeyFromTarget {
    param([string]$Target)

    if ([string]::IsNullOrWhiteSpace($Target)) {
      return $null
    }

    $normalized = $Target.Trim()
    if ($normalized -match '^[A-Za-z_][A-Za-z0-9_]*$') {
      return $normalized
    }

    return $null
  }

  function Get-CanonicalDataKeyTarget {
    param([string]$Target)

    if ([string]::IsNullOrWhiteSpace($Target)) {
      return $Target
    }

    if ($Target -match '^data\.(?<key>[A-Za-z_][A-Za-z0-9_]*)$') {
      return $matches['key']
    }

    if ($Target -match '^\.(?<key>[A-Za-z_][A-Za-z0-9_]*)$') {
      return $matches['key']
    }

    return $Target
  }

  function Get-RepairableComponentTagFromIssueText {
    param($Issue)

    $candidates = @()
    if ($Issue.PSObject.Properties.Name -contains 'actual') {
      $candidates += [string]$Issue.actual
    }
    if ($Issue.PSObject.Properties.Name -contains 'repair_hint') {
      $candidates += [string]$Issue.repair_hint
    }

    foreach ($candidate in $candidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        continue
      }

      if ($candidate -match "component ['""]?([a-z0-9]+(?:-[a-z0-9]+)+)['""]? not rendered") {
        return $matches[1].ToLowerInvariant()
      }

      if ($candidate -match "usingComponents entry '([a-z0-9]+(?:-[a-z0-9]+)+)'") {
        return $matches[1].ToLowerInvariant()
      }
    }

    return $null
  }

  function Get-RepairableElementTagFromIssueText {
    param($Issue)

    $candidates = @()
    if ($Issue.PSObject.Properties.Name -contains 'actual') {
      $candidates += [string]$Issue.actual
    }
    if ($Issue.PSObject.Properties.Name -contains 'repair_hint') {
      $candidates += [string]$Issue.repair_hint
    }

    foreach ($candidate in $candidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        continue
      }

      if ($candidate -match "element ['""]?([a-z0-9]+(?:-[a-z0-9]+)+)['""]? missing") {
        return $matches[1].ToLowerInvariant()
      }

      if ($candidate -match "missing required element ['""]?([a-z0-9]+(?:-[a-z0-9]+)+)['""]?") {
        return $matches[1].ToLowerInvariant()
      }

      if ($candidate -match "usingComponents entry '([a-z0-9]+(?:-[a-z0-9]+)+)'") {
        return $matches[1].ToLowerInvariant()
      }
    }

    return $null
  }

  function Get-RepairableDataKeyFromIssueText {
    param($Issue)

    $candidates = @()
    if ($Issue.PSObject.Properties.Name -contains 'actual') {
      $candidates += [string]$Issue.actual
    }
    if ($Issue.PSObject.Properties.Name -contains 'repair_hint') {
      $candidates += [string]$Issue.repair_hint
    }

    foreach ($candidate in $candidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        continue
      }

      if ($candidate -match "data key ['""]?([A-Za-z_][A-Za-z0-9_]*)['""]? not bound") {
        return $matches[1]
      }

      if ($candidate -match "missing data key ['""]?([A-Za-z_][A-Za-z0-9_]*)['""]?") {
        return $matches[1]
      }
    }

    return $null
  }

  function Register-PageComponentDependency {
    param(
      [Parameter(Mandatory = $true)][string]$Root,
      [Parameter(Mandatory = $true)][string]$PagePath,
      [Parameter(Mandatory = $true)][string]$ComponentTag
    )

    $componentJsPath = Join-Path $Root ("components\{0}\index.js" -f $ComponentTag)
    if (-not (Test-Path $componentJsPath)) {
      return New-BlockedRepairResult -IssueType 'missing_required_element' -Reason "component_missing_on_disk" -TargetPath $componentJsPath
    }

    $pageJson = Get-PageJsonObject -Root $Root -PagePath $PagePath
    $pageJsonPath = Join-Path $Root (($PagePath -replace '/', '\') + '.json')
    if ($null -eq $pageJson) {
      return New-BlockedRepairResult -IssueType 'missing_required_element' -Reason "page_json_missing_or_invalid" -TargetPath $pageJsonPath
    }

    $pageConfig = $pageJson.data
    if ($null -eq $pageConfig.usingComponents) {
      $pageConfig | Add-Member -MemberType NoteProperty -Name usingComponents -Value ([pscustomobject]@{})
    }

    $expectedImportPath = "/components/$ComponentTag/index"
    $existing = $pageConfig.usingComponents.PSObject.Properties[$ComponentTag]
    $wasChanged = $false

    if ($null -eq $existing) {
      $pageConfig.usingComponents | Add-Member -MemberType NoteProperty -Name $ComponentTag -Value $expectedImportPath
      $wasChanged = $true
    }
    elseif ([string]$existing.Value -ne $expectedImportPath) {
      $existing.Value = $expectedImportPath
      $wasChanged = $true
    }

    if (-not $wasChanged) {
      return New-BlockedRepairResult -IssueType 'missing_required_element' -Reason "component_dependency_already_registered" -TargetPath $pageJson.path
    }

    $savedPath = Save-PageJsonObject -JsonPath $pageJson.path -JsonObject $pageConfig
    return New-AppliedRepairResult -IssueType 'missing_required_element' -Reason "registered_missing_component_dependency" -TargetPath $savedPath
  }

  function Get-UsingComponentsIssueTagFromIssue {
    param($Issue)

    $candidates = @()
    if ($Issue.PSObject.Properties.Name -contains 'actual') {
      $candidates += [string]$Issue.actual
    }
    if ($Issue.PSObject.Properties.Name -contains 'repair_hint') {
      $candidates += [string]$Issue.repair_hint
    }

    foreach ($candidate in $candidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        continue
      }

      if ($candidate -match "usingComponents entry '([a-z0-9]+(?:-[a-z0-9]+)+)'") {
        return $matches[1].ToLowerInvariant()
      }
    }

    return $null
  }

  function Get-RepairableButtonTagFromIssueText {
    param($Issue)

    $candidates = @()
    if ($Issue.PSObject.Properties.Name -contains 'actual') {
      $candidates += [string]$Issue.actual
    }
    if ($Issue.PSObject.Properties.Name -contains 'repair_hint') {
      $candidates += [string]$Issue.repair_hint
    }

    foreach ($candidate in $candidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        continue
      }

      if ($candidate -match "button ['""]?([a-z0-9]+(?:-[a-z0-9]+)+)['""]? missing") {
        return $matches[1].ToLowerInvariant()
      }

      if ($candidate -match "missing required button ['""]?([a-z0-9]+(?:-[a-z0-9]+)+)['""]?") {
        return $matches[1].ToLowerInvariant()
      }

      if ($candidate -match "usingComponents entry '([a-z0-9]+(?:-[a-z0-9]+)+)'") {
        return $matches[1].ToLowerInvariant()
      }
    }

    return $null
  }

  function Get-RepairableTextClassFromIssueText {
    param($Issue)

    $candidates = @()
    if ($Issue.PSObject.Properties.Name -contains 'actual') {
      $candidates += [string]$Issue.actual
    }
    if ($Issue.PSObject.Properties.Name -contains 'repair_hint') {
      $candidates += [string]$Issue.repair_hint
    }

    foreach ($candidate in $candidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        continue
      }

      if ($candidate -match "required text ['""]?([A-Za-z0-9_-]+)['""]? missing") {
        return $matches[1]
      }

      if ($candidate -match "missing required text ['""]?([A-Za-z0-9_-]+)['""]?") {
        return $matches[1]
      }

      if ($candidate -match "text class ['""]?([A-Za-z0-9_-]+)['""]? missing") {
        return $matches[1]
      }
    }

    return $null
  }

  function Get-RepairableEmptyStateClassFromIssueText {
    param($Issue)

    $candidates = @()
    if ($Issue.PSObject.Properties.Name -contains 'actual') {
      $candidates += [string]$Issue.actual
    }
    if ($Issue.PSObject.Properties.Name -contains 'repair_hint') {
      $candidates += [string]$Issue.repair_hint
    }

    foreach ($candidate in $candidates) {
      if ([string]::IsNullOrWhiteSpace($candidate)) {
        continue
      }

      if ($candidate -match "empty state text ['""]?([A-Za-z0-9_-]+)['""]? missing") {
        return $matches[1]
      }

      if ($candidate -match "missing empty state text ['""]?([A-Za-z0-9_-]+)['""]?") {
        return $matches[1]
      }

      if ($candidate -match "empty-state class ['""]?([A-Za-z0-9_-]+)['""]? missing") {
        return $matches[1]
      }
    }

    return $null
  }

  function Get-PageJsonContractViolation {
    param($Issue)

    $actual = if ($Issue.PSObject.Properties.Name -contains 'actual') { [string]$Issue.actual } else { '' }
    if ([string]::IsNullOrWhiteSpace($actual)) {
      return $null
    }

    if ($actual -match "usingComponents in '([^']+)' must be an object") {
      return [pscustomobject]@{
        type = 'usingComponents_object'
        target = $matches[1]
      }
    }

    if ($actual -match "Key '([^']+)' is not allowed in page config '([^']+)'") {
      return [pscustomobject]@{
        type = 'page_config_key'
        key = $matches[1]
        target = $matches[2]
      }
    }

    return $null
  }

  function Normalize-WxmlCompileBlockers {
    param([Parameter(Mandatory = $true)][string]$Content)

    $normalized = $Content

    $normalized = $normalized -replace '\?/text>', '</text>'
    $normalized = [regex]::Replace($normalized, '(?<!<)/([a-zA-Z][\w-]*)\s*>', '</$1>')
    $normalized = [regex]::Replace($normalized, '\{\{([^{}\r\n]*)`([^{}\r\n]*)\}\}', '{{$1$2}}')
    $normalized = [regex]::Replace($normalized, '(?<!\{)\{([^\r\n{}]+)\}\}', '{{$1}}')
    $normalized = [regex]::Replace($normalized, '\{\{\s*(.+?)\.toFixed\(\d+\)\s*\}\}', '{{$1}}')

    return $normalized
  }

  function Add-MissingPageDataKey {
    param(
      [Parameter(Mandatory = $true)][string]$Root,
      [Parameter(Mandatory = $true)][string]$PagePath,
      [Parameter(Mandatory = $true)][string]$DataKey
    )

    $jsPath = Join-Path $Root (($PagePath -replace '/', '\') + '.js')
    if (-not (Test-Path $jsPath)) {
      return New-BlockedRepairResult -IssueType 'data_not_bound' -Reason 'page_js_missing' -TargetPath $jsPath
    }

    if ($DataKey -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
      return New-BlockedRepairResult -IssueType 'data_not_bound' -Reason 'unsupported_data_key' -TargetPath $DataKey
    }

    $content = Get-Content -Path $jsPath -Raw -Encoding UTF8
    if ($content -match ("(?m)\b{0}\s*:" -f [regex]::Escape($DataKey))) {
      return New-BlockedRepairResult -IssueType 'data_not_bound' -Reason 'data_key_already_present' -TargetPath $jsPath
    }

    $normalized = [regex]::Replace(
      $content,
      'data\s*:\s*\{',
      ("data: {{`r`n    {0}: null," -f $DataKey),
      1
    )

    if ($normalized -eq $content) {
      return New-BlockedRepairResult -IssueType 'data_not_bound' -Reason 'data_object_not_found' -TargetPath $jsPath
    }

    Write-Utf8NoBomFile -Path $jsPath -Content $normalized
    return New-AppliedRepairResult -IssueType 'data_not_bound' -Reason 'added_missing_page_data_key' -TargetPath $jsPath
  }

  function Update-WxmlTextNodeByClass {
    param(
      [Parameter(Mandatory = $true)][string]$Root,
      [Parameter(Mandatory = $true)][string]$Target,
      [Parameter(Mandatory = $true)][string]$ExpectedText
    )

    if ($Target -notmatch '^(?<file>pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\.wxml)::text\.(?<class>[A-Za-z0-9_-]+)$') {
      return New-BlockedRepairResult -IssueType 'required_text_missing' -Reason 'unsupported_required_text_target' -TargetPath $Target
    }

    $relativePath = $matches['file']
    $className = $matches['class']
    $filePath = Join-Path $Root ($relativePath -replace '/', '\')
    if (-not (Test-Path $filePath)) {
      return New-BlockedRepairResult -IssueType 'required_text_missing' -Reason 'required_text_target_file_missing' -TargetPath $filePath
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedText)) {
      return New-BlockedRepairResult -IssueType 'required_text_missing' -Reason 'missing_required_text_value' -TargetPath $filePath
    }

    $content = Get-Content -Path $filePath -Raw -Encoding UTF8
    $escapedClass = [regex]::Escape($className)
    $pattern = "(?s)(<text\b[^>]*class=""$escapedClass""[^>]*>)(.*?)(</text>)"
    $match = [regex]::Match($content, $pattern)
    if (-not $match.Success) {
      return New-BlockedRepairResult -IssueType 'required_text_missing' -Reason 'required_text_node_missing' -TargetPath $filePath
    }

    $replacementText = [System.Security.SecurityElement]::Escape($ExpectedText)
    $newContent = $content.Substring(0, $match.Groups[2].Index) + $replacementText + $content.Substring($match.Groups[2].Index + $match.Groups[2].Length)
    if ($newContent -eq $content) {
      return New-BlockedRepairResult -IssueType 'required_text_missing' -Reason 'required_text_already_present' -TargetPath $filePath
    }

    Write-Utf8NoBomFile -Path $filePath -Content $newContent
    return New-AppliedRepairResult -IssueType 'required_text_missing' -Reason 'updated_required_text_node' -TargetPath $filePath
  }

  function Get-CanonicalRequiredTextTarget {
    param(
      [Parameter(Mandatory = $true)][string]$PagePath,
      [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
      return $Target
    }

    if ($Target -match '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\.wxml::text\.[A-Za-z0-9_-]+$') {
      return $Target
    }

    if ($Target -match '^text\.(?<class>[A-Za-z0-9_-]+)$') {
      return "$PagePath.wxml::text.$($matches['class'])"
    }

    if ($Target -match '^\.(?<class>[A-Za-z0-9_-]+)$') {
      return "$PagePath.wxml::text.$($matches['class'])"
    }

    return $Target
  }

  function Update-WxmlEmptyStateTextNodeByClass {
    param(
      [Parameter(Mandatory = $true)][string]$Root,
      [Parameter(Mandatory = $true)][string]$Target,
      [Parameter(Mandatory = $true)][string]$ExpectedText
    )

    if ($Target -notmatch '^(?<file>pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\.wxml)::empty-state\.(?<class>[A-Za-z0-9_-]+)$') {
      return New-BlockedRepairResult -IssueType 'empty_list_render' -Reason 'unsupported_empty_list_render_target' -TargetPath $Target
    }

    $relativePath = $matches['file']
    $className = $matches['class']
    $filePath = Join-Path $Root ($relativePath -replace '/', '\')
    if (-not (Test-Path $filePath)) {
      return New-BlockedRepairResult -IssueType 'empty_list_render' -Reason 'empty_state_target_file_missing' -TargetPath $filePath
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedText)) {
      return New-BlockedRepairResult -IssueType 'empty_list_render' -Reason 'missing_empty_state_text_value' -TargetPath $filePath
    }

    $content = Get-Content -Path $filePath -Raw -Encoding UTF8
    $escapedClass = [regex]::Escape($className)
    $pattern = "(?s)(<view\b[^>]*class=""[^""]*\bempty-state\b[^""]*""[^>]*>.*?<text\b[^>]*class=""$escapedClass""[^>]*>)(.*?)(</text>.*?</view>)"
    $match = [regex]::Match($content, $pattern)
    if (-not $match.Success) {
      return New-BlockedRepairResult -IssueType 'empty_list_render' -Reason 'empty_state_text_node_missing' -TargetPath $filePath
    }

    $replacementText = [System.Security.SecurityElement]::Escape($ExpectedText)
    $newContent = $content.Substring(0, $match.Groups[2].Index) + $replacementText + $content.Substring($match.Groups[2].Index + $match.Groups[2].Length)
    if ($newContent -eq $content) {
      return New-BlockedRepairResult -IssueType 'empty_list_render' -Reason 'empty_state_text_already_present' -TargetPath $filePath
    }

    Write-Utf8NoBomFile -Path $filePath -Content $newContent
    return New-AppliedRepairResult -IssueType 'empty_list_render' -Reason 'updated_empty_state_text_node' -TargetPath $filePath
  }

  function Get-CanonicalEmptyStateTarget {
    param(
      [Parameter(Mandatory = $true)][string]$PagePath,
      [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
      return $Target
    }

    if ($Target -match '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\.wxml::empty-state\.[A-Za-z0-9_-]+$') {
      return $Target
    }

    if ($Target -match '^empty-state\.(?<class>[A-Za-z0-9_-]+)$') {
      return "$PagePath.wxml::empty-state.$($matches['class'])"
    }

    if ($Target -match '^\.(?<class>[A-Za-z0-9_-]+)$') {
      return "$PagePath.wxml::empty-state.$($matches['class'])"
    }

    return $Target
  }

  function Invoke-GateContractRepair {
    param(
      [Parameter(Mandatory = $true)][string]$IssueType,
      [Parameter(Mandatory = $true)]$IssueObject,
      [Parameter(Mandatory = $true)][string]$Root
    )

    $pagePath = [string]$IssueObject.page_path
    if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
      return New-BlockedRepairResult -IssueType $IssueType -Reason "invalid_page_path_for_$IssueType" -TargetPath $pagePath
    }

    $componentTag = Get-UsingComponentsIssueTagFromIssue -Issue $IssueObject
    if ($null -ne $componentTag) {
      $result = Register-PageComponentDependency -Root $Root -PagePath $pagePath -ComponentTag $componentTag
      if ($result.status -eq 'applied') {
        $result.issue_type = $IssueType
        $result.reason = 'repaired_using_components_path'
      }
      return $result
    }

    $jsonViolation = Get-PageJsonContractViolation -Issue $IssueObject
    if ($null -ne $jsonViolation) {
      $jsonTarget = if ($jsonViolation.PSObject.Properties.Name -contains 'target') { [string]$jsonViolation.target } else { $target }
      $jsonPath = Join-Path $Root ($jsonTarget -replace '/', '\')
      if (-not (Test-Path $jsonPath)) {
        return New-BlockedRepairResult -IssueType $IssueType -Reason "page_json_contract_target_missing" -TargetPath $jsonPath
      }

      try {
        $pageConfig = Get-Content -Path $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
      }
      catch {
        return New-BlockedRepairResult -IssueType $IssueType -Reason "page_json_contract_parse_failed" -TargetPath $jsonPath
      }

      if ($jsonViolation.type -eq 'usingComponents_object') {
        $existing = $pageConfig.PSObject.Properties['usingComponents']
        if ($null -eq $existing) {
          $pageConfig | Add-Member -MemberType NoteProperty -Name usingComponents -Value ([pscustomobject]@{}) -Force
        }
        else {
          $existing.Value = [pscustomobject]@{}
        }
        Write-Utf8NoBomFile -Path $jsonPath -Content ($pageConfig | ConvertTo-Json -Depth 20)
        return New-AppliedRepairResult -IssueType $IssueType -Reason 'normalized_page_json_usingcomponents_object' -TargetPath $jsonPath
      }

      if ($jsonViolation.type -eq 'page_config_key') {
        $prop = $pageConfig.PSObject.Properties[$jsonViolation.key]
        if ($null -eq $prop) {
          return New-BlockedRepairResult -IssueType $IssueType -Reason "page_json_key_not_present" -TargetPath $jsonPath
        }
        $pageConfig.PSObject.Properties.Remove($jsonViolation.key)
        Write-Utf8NoBomFile -Path $jsonPath -Content ($pageConfig | ConvertTo-Json -Depth 20)
        return New-AppliedRepairResult -IssueType $IssueType -Reason 'removed_invalid_page_config_key' -TargetPath $jsonPath
      }
    }

    $target = if ($IssueObject.PSObject.Properties.Name -contains 'target') { [string]$IssueObject.target } else { '' }
    $actual = if ($IssueObject.PSObject.Properties.Name -contains 'actual') { [string]$IssueObject.actual } else { '' }
    if ($target -like '*.wxml') {
      $targetPath = Join-Path $Root ($target -replace '/', '\')
      if (-not (Test-Path $targetPath)) {
        return New-BlockedRepairResult -IssueType $IssueType -Reason "generation_gate_target_missing" -TargetPath $targetPath
      }

      $content = Get-Content -Path $targetPath -Raw -Encoding UTF8
      $normalized = Normalize-WxmlCompileBlockers -Content $content
      if ($normalized -ne $content) {
        Write-Utf8NoBomFile -Path $targetPath -Content $normalized
        return New-AppliedRepairResult -IssueType $IssueType -Reason 'normalized_wxml_compile_blockers' -TargetPath $targetPath
      }

      if ($actual -match 'unexpected token' -or $actual -match 'malformed mustache' -or $actual -match 'closing tag') {
        return New-BlockedRepairResult -IssueType $IssueType -Reason "no_known_wxml_compile_normalization" -TargetPath $targetPath
      }
    }

    return New-BlockedRepairResult -IssueType $IssueType -Reason "unsupported_generation_gate_repair" -TargetPath $null
  }

  function New-BlockedRepairResult {
    param(
      [Parameter(Mandatory = $true)][string]$IssueType,
      [Parameter(Mandatory = $true)][string]$Reason,
      [string]$TargetPath
    )

    return [PSCustomObject]@{
      applied = $false
      status = "blocked"
      issue_type = $IssueType
      reason = $Reason
      target_path = $TargetPath
      timestamp = (Get-Date -Format "o")
    }
  }

  function New-AppliedRepairResult {
    param(
      [Parameter(Mandatory = $true)][string]$IssueType,
      [Parameter(Mandatory = $true)][string]$Reason,
      [string]$TargetPath
    )

    return [PSCustomObject]@{
      applied = $true
      status = "applied"
      issue_type = $IssueType
      reason = $Reason
      target_path = $TargetPath
      timestamp = (Get-Date -Format "o")
    }
  }

  $issueType = [string]$Issue.issue_type

  switch ($issueType) {
    "wrong_page_path" {
      $expectedPage = [string]$Issue.expected
      if ([string]::IsNullOrWhiteSpace($expectedPage)) {
        $expectedPage = [string]$Issue.page_path
      }

      if ([string]::IsNullOrWhiteSpace($expectedPage) -or $expectedPage -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_expected_page_path" -TargetPath $expectedPage
      }

      $pageFile = Join-Path $ProjectPath (($expectedPage -replace '/', '\') + '.wxml')
      if (-not (Test-Path $pageFile)) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "expected_page_missing_on_disk" -TargetPath $pageFile
      }

      $app = Get-AppJsonObject -Root $ProjectPath
      if ($null -eq $app) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "app_json_missing_or_invalid" -TargetPath (Join-Path $ProjectPath 'app.json')
      }

      if ($null -eq $app.pages) {
        $app | Add-Member -MemberType NoteProperty -Name pages -Value @()
      }

      $pages = @($app.pages | ForEach-Object { [string]$_ })
      $pages = @($expectedPage) + @($pages | Where-Object { $_ -ne $expectedPage })
      $app.pages = $pages

      $savedPath = Save-AppJsonObject -Root $ProjectPath -AppObject $app
      return New-AppliedRepairResult -IssueType $issueType -Reason "registered_and_prioritized_expected_page" -TargetPath $savedPath
    }

    "missing_page_entry" {
      $targetPage = [string]$Issue.target
      if ([string]::IsNullOrWhiteSpace($targetPage)) {
        $targetPage = [string]$Issue.page_path
      }

      if ([string]::IsNullOrWhiteSpace($targetPage) -or $targetPage -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_missing_page_entry_target" -TargetPath $targetPage
      }

      $pageFile = Join-Path $ProjectPath (($targetPage -replace '/', '\') + '.wxml')
      if (-not (Test-Path $pageFile)) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "missing_page_entry_file_missing" -TargetPath $pageFile
      }

      $app = Get-AppJsonObject -Root $ProjectPath
      if ($null -eq $app) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "app_json_missing_or_invalid" -TargetPath (Join-Path $ProjectPath 'app.json')
      }

      if ($null -eq $app.pages) {
        $app | Add-Member -MemberType NoteProperty -Name pages -Value @()
      }

      $pages = @($app.pages | ForEach-Object { [string]$_ })
      if ($pages -notcontains $targetPage) {
        $pages += $targetPage
      }
      $app.pages = $pages

      $savedPath = Save-AppJsonObject -Root $ProjectPath -AppObject $app
      return New-AppliedRepairResult -IssueType $issueType -Reason "registered_missing_page_entry" -TargetPath $savedPath
    }

    "tabbar_item_missing" {
      $targetPage = [string]$Issue.target
      if ([string]::IsNullOrWhiteSpace($targetPage)) {
        $targetPage = [string]$Issue.page_path
      }

      if ([string]::IsNullOrWhiteSpace($targetPage) -or $targetPage -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_tabbar_target" -TargetPath $targetPage
      }

      $app = Get-AppJsonObject -Root $ProjectPath
      if ($null -eq $app) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "app_json_missing_or_invalid" -TargetPath (Join-Path $ProjectPath 'app.json')
      }

      if ($null -eq $app.tabBar) {
        $app | Add-Member -MemberType NoteProperty -Name tabBar -Value ([PSCustomObject]@{
          color = "#666666"
          selectedColor = "#111111"
          backgroundColor = "#ffffff"
          borderStyle = "black"
          list = @()
        })
      }

      if ($null -eq $app.tabBar.list) {
        $app.tabBar | Add-Member -MemberType NoteProperty -Name list -Value @()
      }

      $tabItems = @($app.tabBar.list)
      $exists = $false
      foreach ($item in $tabItems) {
        if ([string]$item.pagePath -eq $targetPage) {
          $exists = $true
          break
        }
      }

      if (-not $exists) {
        $tabItems += [PSCustomObject]@{
          pagePath = $targetPage
          text = Get-TabLabelFromPagePath -PagePath $targetPage
        }
      }

      $app.tabBar.list = $tabItems
      $savedPath = Save-AppJsonObject -Root $ProjectPath -AppObject $app
      return New-AppliedRepairResult -IssueType $issueType -Reason "registered_tabbar_item" -TargetPath $savedPath
    }

    "missing_navigation_bar" {
      $targetPage = [string]$Issue.page_path
      if ([string]::IsNullOrWhiteSpace($targetPage)) {
        $targetPage = [string]$Issue.target
      }

      if ([string]::IsNullOrWhiteSpace($targetPage) -or $targetPage -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_missing_navigation_bar_target" -TargetPath $targetPage
      }

      $pageFile = Join-Path $ProjectPath (($targetPage -replace '/', '\') + '.wxml')
      if (-not (Test-Path $pageFile)) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "missing_navigation_bar_page_missing" -TargetPath $pageFile
      }

      $pageJson = Get-PageJsonObject -Root $ProjectPath -PagePath $targetPage
      $pageJsonPath = Join-Path $ProjectPath (($targetPage -replace '/', '\') + '.json')
      if ($null -eq $pageJson) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "page_json_missing_or_invalid" -TargetPath $pageJsonPath
      }

      $pageConfig = $pageJson.data
      $title = Get-TabLabelFromPagePath -PagePath $targetPage
      $existing = $pageConfig.PSObject.Properties['navigationBarTitleText']
      if ($null -eq $existing) {
        $pageConfig | Add-Member -MemberType NoteProperty -Name navigationBarTitleText -Value $title
      }
      elseif (-not [string]::IsNullOrWhiteSpace([string]$existing.Value)) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "navigation_bar_title_already_present" -TargetPath $pageJson.path
      }
      else {
        $existing.Value = $title
      }

      $savedPath = Save-PageJsonObject -JsonPath $pageJson.path -JsonObject $pageConfig
      return New-AppliedRepairResult -IssueType $issueType -Reason "added_navigation_bar_title" -TargetPath $savedPath
    }

    "missing_required_button" {
      $target = if ($Issue.PSObject.Properties.Name -contains "target") { [string]$Issue.target } else { "" }
      $pagePath = [string]$Issue.page_path

      if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_page_path_for_missing_button" -TargetPath $pagePath
      }

      $componentTag = Get-RepairableComponentTagFromTarget -Target $target
      if ($null -eq $componentTag) {
        $componentTag = Get-RepairableButtonTagFromIssueText -Issue $Issue
      }
      if ($null -ne $componentTag) {
        $result = Register-PageComponentDependency -Root $ProjectPath -PagePath $pagePath -ComponentTag $componentTag
        if ($result.status -eq 'applied') {
          $result.issue_type = $issueType
          $result.reason = 'registered_missing_button_component_dependency'
        }
        return $result
      }

      return New-BlockedRepairResult -IssueType $issueType -Reason "unsupported_missing_button_target" -TargetPath $target
    }

    "missing_required_element" {
      $target = if ($Issue.PSObject.Properties.Name -contains "target") { [string]$Issue.target } else { "" }
      $pagePath = [string]$Issue.page_path

      if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_page_path_for_missing_element" -TargetPath $pagePath
      }

      $componentTag = Get-RepairableComponentTagFromTarget -Target $target
      if ($null -eq $componentTag) {
        $componentTag = Get-RepairableElementTagFromIssueText -Issue $Issue
      }
      if ($null -ne $componentTag) {
        $result = Register-PageComponentDependency -Root $ProjectPath -PagePath $pagePath -ComponentTag $componentTag
        if ($result.status -eq 'applied') {
          $result.issue_type = $issueType
          $result.reason = 'registered_missing_element_component_dependency'
        }
        return $result
      }

      return New-BlockedRepairResult -IssueType $issueType -Reason "unsupported_missing_element_target" -TargetPath $target
    }

    "component_not_rendered" {
      $target = if ($Issue.PSObject.Properties.Name -contains "target") { [string]$Issue.target } else { "" }
      $pagePath = [string]$Issue.page_path

      if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_page_path_for_component_not_rendered" -TargetPath $pagePath
      }

      $componentTag = Get-RepairableComponentTagFromTarget -Target $target
      if ($null -eq $componentTag) {
        $componentTag = Get-RepairableComponentTagFromIssueText -Issue $Issue
      }
      if ($null -eq $componentTag) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "unsupported_component_not_rendered_target" -TargetPath $target
      }

      $result = Register-PageComponentDependency -Root $ProjectPath -PagePath $pagePath -ComponentTag $componentTag
      if ($result.status -eq 'applied') {
        $result.issue_type = $issueType
      }
      return $result
    }

    "generation_gate_rejected" {
      return Invoke-GateContractRepair -IssueType $issueType -IssueObject $Issue -Root $ProjectPath
    }

    "bundle_validation_failed" {
      return Invoke-GateContractRepair -IssueType $issueType -IssueObject $Issue -Root $ProjectPath
    }

    "data_not_bound" {
      $pagePath = [string]$Issue.page_path
      $target = if ($Issue.PSObject.Properties.Name -contains 'target') { [string]$Issue.target } else { '' }

      if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_page_path_for_data_not_bound" -TargetPath $pagePath
      }

      $target = Get-CanonicalDataKeyTarget -Target $target
      $dataKey = Get-RepairableDataKeyFromTarget -Target $target
      if ($null -eq $dataKey) {
        $dataKey = Get-RepairableDataKeyFromIssueText -Issue $Issue
      }

      if ($null -eq $dataKey) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "unsupported_data_not_bound_target" -TargetPath $target
      }

      return Add-MissingPageDataKey -Root $ProjectPath -PagePath $pagePath -DataKey $dataKey
    }

    "required_text_missing" {
      $pagePath = [string]$Issue.page_path
      $target = if ($Issue.PSObject.Properties.Name -contains 'target') { [string]$Issue.target } else { '' }
      $expected = if ($Issue.PSObject.Properties.Name -contains 'expected') { [string]$Issue.expected } else { '' }

      if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_page_path_for_required_text_missing" -TargetPath $pagePath
      }

      if ([string]::IsNullOrWhiteSpace($target)) {
        $textClass = Get-RepairableTextClassFromIssueText -Issue $Issue
        if ($null -ne $textClass) {
          $target = "$pagePath.wxml::text.$textClass"
        }
      }

      $target = Get-CanonicalRequiredTextTarget -PagePath $pagePath -Target $target

      return Update-WxmlTextNodeByClass -Root $ProjectPath -Target $target -ExpectedText $expected
    }

    "empty_list_render" {
      $pagePath = [string]$Issue.page_path
      $target = if ($Issue.PSObject.Properties.Name -contains 'target') { [string]$Issue.target } else { '' }
      $expected = if ($Issue.PSObject.Properties.Name -contains 'expected') { [string]$Issue.expected } else { '' }

      if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_page_path_for_empty_list_render" -TargetPath $pagePath
      }

      if ([string]::IsNullOrWhiteSpace($target)) {
        $textClass = Get-RepairableEmptyStateClassFromIssueText -Issue $Issue
        if ($null -ne $textClass) {
          $target = "$pagePath.wxml::empty-state.$textClass"
        }
      }

      $target = Get-CanonicalEmptyStateTarget -PagePath $pagePath -Target $target

      return Update-WxmlEmptyStateTextNodeByClass -Root $ProjectPath -Target $target -ExpectedText $expected
    }

    "error_page_visible" {
      $pagePath = [string]$Issue.page_path
      $actual = if ($Issue.PSObject.Properties.Name -contains 'actual') { [string]$Issue.actual } else { '' }

      if ([string]::IsNullOrWhiteSpace($pagePath) -or $pagePath -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
        return New-BlockedRepairResult -IssueType $issueType -Reason "invalid_page_path_for_error_page_visible" -TargetPath $pagePath
      }

      if ($actual -match '__route__ is not defined') {
        $wxmlPath = Join-Path $ProjectPath (($pagePath -replace '/', '\') + '.wxml')
        if (-not (Test-Path $wxmlPath)) {
          return New-BlockedRepairResult -IssueType $issueType -Reason "error_page_wxml_missing" -TargetPath $wxmlPath
        }

        $content = Get-Content -Path $wxmlPath -Raw -Encoding UTF8
        $normalized = Normalize-WxmlCompileBlockers -Content $content
        if ($normalized -ne $content) {
          Write-Utf8NoBomFile -Path $wxmlPath -Content $normalized
          return New-AppliedRepairResult -IssueType $issueType -Reason "normalized_route_runtime_blocker" -TargetPath $wxmlPath
        }

        return New-BlockedRepairResult -IssueType $issueType -Reason "no_known_route_runtime_normalization" -TargetPath $wxmlPath
      }

      return New-BlockedRepairResult -IssueType $issueType -Reason "unsupported_error_page_visible_repair" -TargetPath $null
    }

    "text_encoding_garbled" {
      $target = if ($Issue.PSObject.Properties.Name -contains "target") { [string]$Issue.target } else { "" }

      if ($target -and ($target -like "*.wxml" -or $target -like "*.js" -or $target -like "*.wxss")) {
        $targetPath = Join-Path $ProjectPath ($target -replace '/', '\')
        if (-not (Test-Path $targetPath)) {
          return New-BlockedRepairResult -IssueType $issueType -Reason "target_file_missing" -TargetPath $targetPath
        }

        $content = Get-Content -Path $targetPath -Raw -Encoding UTF8
        $normalized = $content

        $normalized = $normalized -replace '\?/text>', '</text>'
        $normalized = $normalized -replace '妤糪{\{', '楼{{'
        $normalized = $normalized -replace '(?<!\{)\{([^\r\n{}]+)\}\}', '{{$1}}'

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

        $normalized = $normalized -replace '(<text class="title">)[^<]*(</text>)', '$1Cart$2'
        $normalized = $normalized -replace '(<text class="remove"[^>]*>)[^<]*(</text>)', '$1Remove$2'
        $normalized = $normalized -replace '(<button[^>]*bindtap="clearCart"[^>]*>)[^<]*(</button>)', '$1Clear$2'
        $normalized = $normalized -replace '(<button[^>]*bindtap="goShop"[^>]*>)[^<]*(</button>)', '$1Shop$2'
        $normalized = $normalized -replace '(<button[^>]*bindtap="checkout"[^>]*>)[^<]*(</button>)', '$1Checkout$2'
        $normalized = $normalized -replace '(<text class="muted">)\s*\{\{\(item\.price\*item\.qty\)\.toFixed\(2\)\}\}\s*(</text>)', '$1Subtotal: 楼{{(item.price*item.qty).toFixed(2)}}$2'

        if ($normalized -eq $content) {
          return New-BlockedRepairResult -IssueType $issueType -Reason "no_known_mojibake_pattern" -TargetPath $targetPath
        }

        Set-Content -Path $targetPath -Value $normalized -Encoding UTF8
        return New-AppliedRepairResult -IssueType $issueType -Reason "normalized_page_ui_text" -TargetPath $targetPath
      }

      $appJsonPath = Join-Path $ProjectPath "app.json"
      if (-not (Test-Path $appJsonPath)) {
        return New-BlockedRepairResult -IssueType $issueType -Reason "app_json_missing" -TargetPath $appJsonPath
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

      $savedPath = Save-AppJsonObject -Root $ProjectPath -AppObject $obj
      return New-AppliedRepairResult -IssueType $issueType -Reason "normalized_app_json_ui_text" -TargetPath $savedPath
    }

    default {
      return New-BlockedRepairResult -IssueType $issueType -Reason "unsupported_auto_fix_issue_type" -TargetPath $null
    }
  }
}
