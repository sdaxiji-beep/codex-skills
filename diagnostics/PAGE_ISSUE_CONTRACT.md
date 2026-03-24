# Page Issue Contract

## 定位
所有检测来源（automator / screenshot / ast / bundle / gate）必须将结果转换成 PageIssue 格式。
调度器只消费 PageIssue，不直接读取各检测层原始输出。

## Severity 处理规则
- critical：立即进入修复循环
- warning：记录，本轮不修，下一轮重评
- info：只记录日志，不触发任何动作

## 单轮修复规则
同一轮出现多个 critical 时，只修优先级最高的 1 个，禁止并发修复。
优先级顺序：
1. page_not_found / wrong_page_path
2. page_blank / error_page_visible
3. missing_required_element / component_not_rendered
4. empty_list_render / required_text_missing
5. 其他

## retryable: false 处理规则
立即停止修复循环，输出标准化报告，等待人工介入。不继续跑其他修复。

## issue_id 生成规则
格式：{issue_type}|{page_path}|{source}
用途：去重 + 调度器判断本轮是否已修过此问题
