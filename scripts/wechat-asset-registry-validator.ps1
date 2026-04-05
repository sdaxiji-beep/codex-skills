[CmdletBinding()]
param(
    [string]$RegistryPath
)

function Add-RegistryViolation {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Violations,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$Message
    )

    $Violations.Add([pscustomobject]@{
        path = $Path
        code = $Code
        message = $Message
    }) | Out-Null
}

function Test-RegistryStringPattern {
    param(
        [string]$Value,
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return ($Value -match $Pattern)
}

function Get-RegistryFamilyAcceptanceRuleMap {
    return @{
        'marketing-empty-state' = @('component_ref', 'cta_button')
        'product-listing' = @('component_ref', 'price_display')
        'product-detail' = @('component_ref', 'add_to_cart_cta')
        'food-order' = @('component_ref', 'price_display', 'quantity_controls', 'cart_summary')
    }
}

function Get-RegistryPageFamilyAcceptanceRuleMap {
    return @{
        'marketing-empty-state' = @('page_text', 'component_ref', 'cta_button', 'rules_section', 'countdown_placeholder', 'benefits_list')
        'product-listing' = @('page_text', 'component_ref', 'product_list')
        'product-detail' = @('page_text', 'component_ref', 'price_display', 'add_to_cart_cta', 'detail_image')
        'food-order' = @('page_text', 'component_ref', 'food_list', 'price_display', 'cart_summary', 'route_link')
    }
}

$violations = [System.Collections.Generic.List[object]]::new()
$scriptRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $PSScriptRoot
}
$repoRoot = Split-Path $scriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    $RegistryPath = Join-Path $repoRoot 'assets\registry.json'
}
$schemaPath = Join-Path $repoRoot 'schemas\wechat-asset-registry.schema.json'

if (-not (Test-Path $RegistryPath)) {
    Add-RegistryViolation -Violations $violations -Path 'registry' -Code 'registry_missing' -Message "Registry file not found: $RegistryPath"
}
if (-not (Test-Path $schemaPath)) {
    Add-RegistryViolation -Violations $violations -Path 'schema' -Code 'schema_missing' -Message "Schema file not found: $schemaPath"
}

if ($violations.Count -gt 0) {
    [pscustomobject]@{
        status = 'fail'
        schema_path = $schemaPath
        registry_path = $RegistryPath
        violations = @($violations)
    } | ConvertTo-Json -Depth 10
    exit 1
}

$registry = Get-Content $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ([string]$registry.schema_version -ne 'asset_registry_v1') {
    Add-RegistryViolation -Violations $violations -Path 'schema_version' -Code 'invalid_schema_version' -Message 'schema_version must equal asset_registry_v1'
}

$components = @($registry.components)
if ($components.Count -eq 0) {
    Add-RegistryViolation -Violations $violations -Path 'components' -Code 'missing_components' -Message 'Registry must define at least one component entry'
}

$familyRuleMap = Get-RegistryFamilyAcceptanceRuleMap
$pageFamilyRuleMap = Get-RegistryPageFamilyAcceptanceRuleMap
$seenNames = @{}
for ($i = 0; $i -lt $components.Count; $i++) {
    $component = $components[$i]
    $base = "components[$i]"

    if (-not (Test-RegistryStringPattern -Value ([string]$component.name) -Pattern '^[a-z0-9-]+$')) {
        Add-RegistryViolation -Violations $violations -Path "$base.name" -Code 'invalid_name' -Message 'Component name must be lowercase kebab-case'
    }
    elseif ($seenNames.ContainsKey([string]$component.name)) {
        Add-RegistryViolation -Violations $violations -Path "$base.name" -Code 'duplicate_name' -Message "Duplicate component name: $($component.name)"
    }
    else {
        $seenNames[[string]$component.name] = $true
    }

    if (-not (Test-RegistryStringPattern -Value ([string]$component.version) -Pattern '^\d+\.\d+\.\d+$')) {
        Add-RegistryViolation -Violations $violations -Path "$base.version" -Code 'invalid_version' -Message 'Component version must use semver (x.y.z)'
    }

    if ([string]::IsNullOrWhiteSpace([string]$component.family)) {
        Add-RegistryViolation -Violations $violations -Path "$base.family" -Code 'missing_family' -Message 'Component family must be non-empty'
    }

    foreach ($dependency in @($component.dependencies)) {
        if (-not (Test-RegistryStringPattern -Value ([string]$dependency) -Pattern '^[a-z0-9-]+$')) {
            Add-RegistryViolation -Violations $violations -Path "$base.dependencies" -Code 'invalid_dependency' -Message "Invalid dependency name: $dependency"
        }
    }

    $acceptanceRules = @($component.acceptance_rules)
    if ($acceptanceRules.Count -eq 0) {
        Add-RegistryViolation -Violations $violations -Path "$base.acceptance_rules" -Code 'missing_acceptance_rules' -Message 'Component acceptance_rules must be present and non-empty'
    }

    if (-not $familyRuleMap.ContainsKey([string]$component.family)) {
        Add-RegistryViolation -Violations $violations -Path "$base.family" -Code 'unsupported_family' -Message "Family is not registered in validator acceptance mapping: $($component.family)"
    }
    else {
        $allowedRules = @($familyRuleMap[[string]$component.family])
        foreach ($rule in $acceptanceRules) {
            if ($allowedRules -notcontains [string]$rule) {
                Add-RegistryViolation -Violations $violations -Path "$base.acceptance_rules" -Code 'unmapped_acceptance_rule' -Message "Acceptance rule '$rule' is not mapped for family '$($component.family)'"
            }
        }
    }

    $entryFiles = $component.entry_files
    if ($null -eq $entryFiles) {
        Add-RegistryViolation -Violations $violations -Path "$base.entry_files" -Code 'missing_entry_files' -Message 'entry_files block is required'
        continue
    }

    $requiredFiles = [ordered]@{
        wxml = '^assets/components/[a-z0-9-]+/index\.wxml$'
        js   = '^assets/components/[a-z0-9-]+/index\.js$'
        wxss = '^assets/components/[a-z0-9-]+/index\.wxss$'
        json = '^assets/components/[a-z0-9-]+/index\.json$'
    }

    foreach ($key in @($requiredFiles.Keys)) {
        $relativePath = [string]$entryFiles.$key
        if (-not (Test-RegistryStringPattern -Value $relativePath -Pattern $requiredFiles[$key])) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'invalid_entry_path' -Message "Invalid $key entry path: $relativePath"
            continue
        }

        $expectedPrefix = "assets/components/$([string]$component.name)/"
        if (-not $relativePath.StartsWith($expectedPrefix)) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'name_path_mismatch' -Message "Entry path '$relativePath' does not match component name '$($component.name)'"
        }

        $absolutePath = Join-Path $repoRoot ($relativePath -replace '/', '\')
        if (-not (Test-Path $absolutePath)) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'missing_entry_file' -Message "Entry file not found: $relativePath"
            continue
        }

        $content = Get-Content $absolutePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'empty_entry_file' -Message "Entry file is empty: $relativePath"
        }
    }
}

foreach ($component in $components) {
    foreach ($dependency in @($component.dependencies)) {
        if ([string]::IsNullOrWhiteSpace([string]$dependency)) {
            continue
        }

        if (-not $seenNames.ContainsKey([string]$dependency)) {
            $index = [array]::IndexOf($components, $component)
            Add-RegistryViolation -Violations $violations -Path "components[$index].dependencies" -Code 'unresolved_dependency' -Message "Dependency '$dependency' is not registered in assets/registry.json"
        }
    }
}

$pageTemplates = @($registry.page_templates)
$seenPageTemplateNames = @{}
$seenPageTemplateNameMap = @{}
for ($i = 0; $i -lt $pageTemplates.Count; $i++) {
    $template = $pageTemplates[$i]
    $base = "page_templates[$i]"

    if (-not (Test-RegistryStringPattern -Value ([string]$template.name) -Pattern '^[a-z0-9-]+$')) {
        Add-RegistryViolation -Violations $violations -Path "$base.name" -Code 'invalid_page_template_name' -Message 'Page template name must be lowercase kebab-case'
    }
    elseif ($seenPageTemplateNames.ContainsKey([string]$template.name)) {
        Add-RegistryViolation -Violations $violations -Path "$base.name" -Code 'duplicate_page_template_name' -Message "Duplicate page template name: $($template.name)"
    }
    else {
        $seenPageTemplateNames[[string]$template.name] = $true
        $seenPageTemplateNameMap[[string]$template.name] = $true
    }

    if (-not (Test-RegistryStringPattern -Value ([string]$template.version) -Pattern '^\d+\.\d+\.\d+$')) {
        Add-RegistryViolation -Violations $violations -Path "$base.version" -Code 'invalid_page_template_version' -Message 'Page template version must use semver (x.y.z)'
    }

    if ([string]::IsNullOrWhiteSpace([string]$template.family)) {
        Add-RegistryViolation -Violations $violations -Path "$base.family" -Code 'missing_page_template_family' -Message 'Page template family must be non-empty'
    }

    foreach ($dependency in @($template.dependencies)) {
        if (-not (Test-RegistryStringPattern -Value ([string]$dependency) -Pattern '^[a-z0-9-]+$')) {
            Add-RegistryViolation -Violations $violations -Path "$base.dependencies" -Code 'invalid_page_dependency' -Message "Invalid page dependency name: $dependency"
        }
    }

    foreach ($relatedPage in @($template.related_pages | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
        if (-not (Test-RegistryStringPattern -Value ([string]$relatedPage) -Pattern '^[a-z0-9-]+$')) {
            Add-RegistryViolation -Violations $violations -Path "$base.related_pages" -Code 'invalid_related_page' -Message "Invalid related page name: $relatedPage"
        }
    }

    $acceptanceRules = @($template.acceptance_rules)
    if ($acceptanceRules.Count -eq 0) {
        Add-RegistryViolation -Violations $violations -Path "$base.acceptance_rules" -Code 'missing_page_acceptance_rules' -Message 'Page template acceptance_rules must be present and non-empty'
    }

    if (-not $pageFamilyRuleMap.ContainsKey([string]$template.family)) {
        Add-RegistryViolation -Violations $violations -Path "$base.family" -Code 'unsupported_page_family' -Message "Page family is not registered in validator acceptance mapping: $($template.family)"
    }
    else {
        $allowedRules = @($pageFamilyRuleMap[[string]$template.family])
        foreach ($rule in $acceptanceRules) {
            if ($allowedRules -notcontains [string]$rule) {
                Add-RegistryViolation -Violations $violations -Path "$base.acceptance_rules" -Code 'unmapped_page_acceptance_rule' -Message "Acceptance rule '$rule' is not mapped for page family '$($template.family)'"
            }
        }
    }

    $entryFiles = $template.entry_files
    if ($null -eq $entryFiles) {
        Add-RegistryViolation -Violations $violations -Path "$base.entry_files" -Code 'missing_page_entry_files' -Message 'page template entry_files block is required'
        continue
    }

    $requiredFiles = [ordered]@{
        wxml = '^assets/pages/[a-z0-9-]+/index\.wxml$'
        js   = '^assets/pages/[a-z0-9-]+/index\.js$'
        wxss = '^assets/pages/[a-z0-9-]+/index\.wxss$'
        json = '^assets/pages/[a-z0-9-]+/index\.json$'
    }

    foreach ($key in @($requiredFiles.Keys)) {
        $relativePath = [string]$entryFiles.$key
        if (-not (Test-RegistryStringPattern -Value $relativePath -Pattern $requiredFiles[$key])) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'invalid_page_entry_path' -Message "Invalid page $key entry path: $relativePath"
            continue
        }

        $expectedPrefix = "assets/pages/$([string]$template.name)/"
        if (-not $relativePath.StartsWith($expectedPrefix)) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'page_name_path_mismatch' -Message "Page entry path '$relativePath' does not match template name '$($template.name)'"
        }

        $absolutePath = Join-Path $repoRoot ($relativePath -replace '/', '\')
        if (-not (Test-Path $absolutePath)) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'missing_page_entry_file' -Message "Page entry file not found: $relativePath"
            continue
        }

        $content = Get-Content $absolutePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            Add-RegistryViolation -Violations $violations -Path "$base.entry_files.$key" -Code 'empty_page_entry_file' -Message "Page entry file is empty: $relativePath"
        }
    }
}

foreach ($template in $pageTemplates) {
    foreach ($dependency in @($template.dependencies)) {
        if ([string]::IsNullOrWhiteSpace([string]$dependency)) {
            continue
        }

        if (-not $seenNames.ContainsKey([string]$dependency)) {
            $index = [array]::IndexOf($pageTemplates, $template)
            Add-RegistryViolation -Violations $violations -Path "page_templates[$index].dependencies" -Code 'unresolved_page_dependency' -Message "Page dependency '$dependency' is not registered in assets/registry.json"
        }
    }

    foreach ($relatedPage in @($template.related_pages | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
        if (-not $seenPageTemplateNameMap.ContainsKey([string]$relatedPage)) {
            $index = [array]::IndexOf($pageTemplates, $template)
            Add-RegistryViolation -Violations $violations -Path "page_templates[$index].related_pages" -Code 'unresolved_related_page' -Message "Related page '$relatedPage' is not registered in assets/registry.json"
        }
    }
}

$status = if ($violations.Count -eq 0) { 'pass' } else { 'fail' }
$result = [pscustomobject]@{
    status = $status
    schema_path = $schemaPath
    registry_path = $RegistryPath
    component_count = $components.Count
    page_template_count = $pageTemplates.Count
    violations = @($violations)
}

$result | ConvertTo-Json -Depth 10

if ($status -ne 'pass') {
    exit 1
}
