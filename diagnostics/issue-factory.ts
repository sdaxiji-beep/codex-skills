import {
  PageIssue, IssueType, IssueSource,
  SEVERITY_MAP, RETRYABLE_MAP
} from './page-issue.schema';

function makeIssueId(issue_type: IssueType, page_path: string, source: IssueSource): string {
  return `${issue_type}|${page_path}|${source}`;
}

export function createIssue(params: {
  issue_type: IssueType;
  source: IssueSource;
  page_path: string;
  project_path: string;
  target?: string | null;
  expected?: string;
  actual?: string;
  repair_hint?: string;
}): PageIssue {
  return {
    issue_id: makeIssueId(params.issue_type, params.page_path, params.source),
    status: 'failed',
    issue_type: params.issue_type,
    target: params.target ?? null,
    expected: params.expected ?? '',
    actual: params.actual ?? '',
    severity: SEVERITY_MAP[params.issue_type],
    source: params.source,
    page_path: params.page_path,
    project_path: params.project_path,
    repair_hint: params.repair_hint ?? '',
    retryable: RETRYABLE_MAP[params.issue_type],
    timestamp: new Date().toISOString(),
  };
}

export function createPassedResult(
  page_path: string,
  project_path: string,
  source: IssueSource
): PageIssue {
  return {
    issue_id: `passed|${page_path}|${source}`,
    status: 'passed',
    issue_type: 'missing_required_element',
    target: null,
    expected: 'page healthy',
    actual: 'page healthy',
    severity: 'info',
    source,
    page_path,
    project_path,
    repair_hint: '',
    retryable: false,
    timestamp: new Date().toISOString(),
  };
}
