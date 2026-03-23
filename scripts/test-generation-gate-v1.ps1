param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-page-gate-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'components\product-card') -Force | Out-Null
Set-Content -Path (Join-Path $tempRoot 'components\product-card\index.js') -Value 'Component({ properties: {}, data: {}, methods: {} })' -Encoding ASCII

$validPayload = @{
  page_name = 'todo'
  files = @(
    @{
      path = 'pages/todo/index.wxml'
      content = '<view class="container"><product-card></product-card><text>{{title}}</text></view>'
    },
    @{
      path = 'pages/todo/index.js'
      content = 'Page({ data: { title: "Todo" }, onLoad() {} })'
    },
    @{
      path = 'pages/todo/index.wxss'
      content = '.container { padding: 20rpx; display: flex; }'
    },
    @{
      path = 'pages/todo/index.json'
      content = '{ "navigationBarTitleText": "Todo", "usingComponents": { "product-card": "/components/product-card/index" } }'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$validResult = Invoke-GenerationGateV1 -JsonPayload $validPayload -TargetWorkspace $tempRoot
Assert-Equal $validResult.Status 'pass' 'valid payload should pass'
Assert-Equal $validResult.Errors.Count 0 'valid payload should not return errors'

$invalidJsonResult = Invoke-GenerationGateV1 -JsonPayload '```json { } ```'
Assert-Equal $invalidJsonResult.Status 'retryable_fail' 'invalid JSON should be retryable'
Assert-True ($invalidJsonResult.Errors.Count -gt 0) 'invalid JSON should return parse errors'

$hardFailPayload = @{
  page_name = 'todo'
  files = @(
    @{
      path = 'app.js'
      content = 'App({})'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$hardFailResult = Invoke-GenerationGateV1 -JsonPayload $hardFailPayload
Assert-Equal $hardFailResult.Status 'hard_fail' 'global config writes should hard fail'

$htmlFailPayload = @{
  page_name = 'todo'
  files = @(
    @{
      path = 'pages/todo/index.wxml'
      content = '<div>bad</div>'
    },
    @{
      path = 'pages/todo/index.js'
      content = 'Page({ data: {} })'
    },
    @{
      path = 'pages/todo/index.wxss'
      content = '.container { padding: 20rpx; }'
    },
    @{
      path = 'pages/todo/index.json'
      content = '{ "usingComponents": {} }'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$htmlFailResult = Invoke-GenerationGateV1 -JsonPayload $htmlFailPayload
Assert-Equal $htmlFailResult.Status 'retryable_fail' 'HTML tags should be retryable failures'
Assert-True (($htmlFailResult.Errors | Where-Object { $_ -match 'unauthorized HTML tag|unauthorized tag' }).Count -gt 0) 'HTML failure should explain the WXML violation'

$invalidComponentPathPayload = @{
  page_name = 'todo'
  files = @(
    @{
      path = 'pages/todo/index.wxml'
      content = '<view class="container"><text>{{title}}</text></view>'
    },
    @{
      path = 'pages/todo/index.js'
      content = 'Page({ data: {} })'
    },
    @{
      path = 'pages/todo/index.wxss'
      content = '.container { padding: 20rpx; }'
    },
    @{
      path = 'pages/todo/index.json'
      content = '{ "usingComponents": { "bad-card": "../utils/malicious" } }'
    }
  )
} | ConvertTo-Json -Depth 8 -Compress

$invalidComponentPathResult = Invoke-GenerationGateV1 -JsonPayload $invalidComponentPathPayload -TargetWorkspace $tempRoot
Assert-Equal $invalidComponentPathResult.Status 'retryable_fail' 'invalid usingComponents paths should be retryable failures'
Assert-True (($invalidComponentPathResult.Errors | Where-Object { $_ -match 'usingComponents entry' }).Count -gt 0) 'invalid usingComponents paths should be explained'

New-TestResult -Name 'generation-gate-v1' -Data @{
  pass = $true
  exit_code = 0
  valid_status = $validResult.Status
  hard_fail_status = $hardFailResult.Status
}

if (Test-Path $tempRoot) {
  Remove-Item -Path $tempRoot -Recurse -Force
}
