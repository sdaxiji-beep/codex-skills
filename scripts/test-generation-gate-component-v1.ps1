param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-component-v1.ps1"

$validPayload = @{
  component_name = 'product-card'
  files = @(
    @{
      path = 'components/product-card/index.wxml'
      content = '<view class="card"><slot></slot><text>{{title}}</text></view>'
    },
    @{
      path = 'components/product-card/index.js'
      content = 'Component({ properties: {}, data: { title: "Card" }, methods: {} })'
    },
    @{
      path = 'components/product-card/index.wxss'
      content = '.card { padding: 24rpx; display: flex; }'
    },
    @{
      path = 'components/product-card/index.json'
      content = '{ "component": true, "usingComponents": {} }'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$validResult = Invoke-GenerationGateComponentV1 -JsonPayload $validPayload
Assert-Equal $validResult.Status 'pass' 'valid component payload should pass'
Assert-Equal $validResult.Errors.Count 0 'valid component payload should not return errors'

$missingComponentFlagPayload = @{
  component_name = 'product-card'
  files = @(
    @{
      path = 'components/product-card/index.wxml'
      content = '<view class="card"></view>'
    },
    @{
      path = 'components/product-card/index.js'
      content = 'Component({ properties: {}, data: {}, methods: {} })'
    },
    @{
      path = 'components/product-card/index.wxss'
      content = '.card { padding: 24rpx; }'
    },
    @{
      path = 'components/product-card/index.json'
      content = '{ "usingComponents": {} }'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$missingComponentFlagResult = Invoke-GenerationGateComponentV1 -JsonPayload $missingComponentFlagPayload
Assert-Equal $missingComponentFlagResult.Status 'retryable_fail' 'missing component=true should be retryable'
Assert-True (($missingComponentFlagResult.Errors | Where-Object { $_ -match 'component' }).Count -gt 0) 'missing component=true should be explained'

$pageCtorPayload = @{
  component_name = 'product-card'
  files = @(
    @{
      path = 'components/product-card/index.wxml'
      content = '<view class="card"></view>'
    },
    @{
      path = 'components/product-card/index.js'
      content = 'Page({ data: {} })'
    },
    @{
      path = 'components/product-card/index.wxss'
      content = '.card { padding: 24rpx; }'
    },
    @{
      path = 'components/product-card/index.json'
      content = '{ "component": true }'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$pageCtorResult = Invoke-GenerationGateComponentV1 -JsonPayload $pageCtorPayload
Assert-Equal $pageCtorResult.Status 'retryable_fail' 'Page() should be rejected in component generation'
Assert-True (($pageCtorResult.Errors | Where-Object { $_ -match 'Page\(\)|Component\(' }).Count -gt 0) 'Page() misuse should be explained'

$hardFailPayload = @{
  component_name = 'product-card'
  files = @(
    @{
      path = 'pages/home/index.js'
      content = 'Page({})'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$hardFailResult = Invoke-GenerationGateComponentV1 -JsonPayload $hardFailPayload
Assert-Equal $hardFailResult.Status 'hard_fail' 'page writes should hard fail in component mode'

New-TestResult -Name 'generation-gate-component-v1' -Data @{
  pass = $true
  exit_code = 0
  valid_status = $validResult.Status
  hard_fail_status = $hardFailResult.Status
}
