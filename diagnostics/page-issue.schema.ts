export type IssueStatus = 'failed' | 'passed' | 'unknown';
export type IssueSeverity = 'critical' | 'warning' | 'info';
export type IssueSource = 'automator' | 'screenshot' | 'ast' | 'bundle' | 'gate' | 'overlay';

export type IssueType =
  // 页面结构缺失
  | 'missing_required_element'
  | 'missing_required_button'
  | 'missing_page_entry'
  | 'missing_navigation_bar'
  | 'component_not_rendered'
  // 数据渲染异常
  | 'empty_list_render'
  | 'data_not_bound'
  | 'stale_placeholder_visible'
  | 'required_text_missing'
  // 页面整体状态
  | 'page_blank'
  | 'error_page_visible'
  | 'page_not_found'
  | 'page_load_timeout'
  | 'unexpected_error_toast'
  // 权限/路由
  | 'unauthorized_redirect'
  | 'wrong_page_path'
  | 'tabbar_item_missing'
  // 代码/构建层
  | 'bundle_validation_failed'
  | 'ast_parse_error'
  | 'generation_gate_rejected'
  | 'text_encoding_garbled';

export interface PageIssue {
  issue_id: string;           // 格式: {issue_type}|{page_path}|{source}
  status: IssueStatus;
  issue_type: IssueType;
  target: string | null;
  expected: string;
  actual: string;
  severity: IssueSeverity;
  source: IssueSource;
  page_path: string;
  project_path: string;
  repair_hint: string;
  retryable: boolean;
  timestamp: string;
}

export const SEVERITY_MAP: Record<IssueType, IssueSeverity> = {
  missing_required_element: 'critical',
  missing_required_button: 'critical',
  missing_page_entry: 'critical',
  missing_navigation_bar: 'warning',
  component_not_rendered: 'critical',
  empty_list_render: 'critical',
  data_not_bound: 'critical',
  stale_placeholder_visible: 'warning',
  required_text_missing: 'critical',
  page_blank: 'critical',
  error_page_visible: 'critical',
  page_not_found: 'critical',
  page_load_timeout: 'warning',
  unexpected_error_toast: 'critical',
  unauthorized_redirect: 'critical',
  wrong_page_path: 'critical',
  tabbar_item_missing: 'critical',
  bundle_validation_failed: 'critical',
  ast_parse_error: 'critical',
  generation_gate_rejected: 'critical',
  text_encoding_garbled: 'critical',
};

export const RETRYABLE_MAP: Record<IssueType, boolean> = {
  missing_required_element: true,
  missing_required_button: true,
  missing_page_entry: true,
  missing_navigation_bar: true,
  component_not_rendered: true,
  empty_list_render: true,
  data_not_bound: true,
  stale_placeholder_visible: true,
  required_text_missing: true,
  page_blank: true,
  error_page_visible: true,
  page_not_found: false,
  page_load_timeout: true,
  unexpected_error_toast: true,
  unauthorized_redirect: false,
  wrong_page_path: true,
  tabbar_item_missing: true,
  bundle_validation_failed: true,
  ast_parse_error: false,
  generation_gate_rejected: true,
  text_encoding_garbled: true,
};

// 优先级越小越先修
export const PRIORITY_MAP: Record<IssueType, number> = {
  page_not_found: 1,
  wrong_page_path: 1,
  page_blank: 2,
  error_page_visible: 2,
  missing_required_element: 3,
  component_not_rendered: 3,
  empty_list_render: 4,
  required_text_missing: 4,
  missing_required_button: 5,
  missing_page_entry: 5,
  unexpected_error_toast: 5,
  unauthorized_redirect: 5,
  tabbar_item_missing: 5,
  missing_navigation_bar: 6,
  data_not_bound: 6,
  stale_placeholder_visible: 7,
  page_load_timeout: 7,
  bundle_validation_failed: 3,
  ast_parse_error: 2,
  generation_gate_rejected: 3,
  text_encoding_garbled: 2,
};
