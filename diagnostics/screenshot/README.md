# Screenshot Fallback

调用入口：Invoke-ScreenshotFallback.ps1
输出：标准 PageIssue，与 automator 路线完全一致。

第一版检测规则（按优先级短路）：
1. page_blank          — 中心区域 95%+ 白色
2. error_page_visible  — 中心区域 90%+ 黑色
3. unexpected_error_toast — 中心区域 5%+ 红色像素
4. passed              — 无命中，视觉通过

后续可扩展（不在第一版）：
- OCR 关键文案 → required_text_missing
- 商品卡片区域存在性 → missing_required_element
- 组件区域缺失 → component_not_rendered
