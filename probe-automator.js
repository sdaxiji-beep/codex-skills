const automator = require('miniprogram-automator');
const net = require('net');
const path = require('path');

const pageConfig = require(path.join(__dirname, 'config', 'page-elements.json'));

const requestedPort = Number.parseInt(
  process.env.WECHAT_DEVTOOLS_PORT || process.env.WECHAT_AUTOMATOR_PORT || '9420',
  10
);
const PORT = Number.isFinite(requestedPort) && requestedPort > 0 ? requestedPort : 9420;

function checkPort(port, timeout = 500) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    socket.setTimeout(timeout);
    socket.on('connect', () => {
      socket.destroy();
      resolve(true);
    });
    socket.on('timeout', () => {
      socket.destroy();
      resolve(false);
    });
    socket.on('error', () => {
      socket.destroy();
      resolve(false);
    });
    socket.connect(port, '127.0.0.1');
  });
}

async function probe() {
  const portOpen = await checkPort(PORT, 500);
  if (!portOpen) {
    console.error(`[PROBE] Port ${PORT} unavailable, skip automator.`);
    process.exit(2);
  }

  let lastErr;
  for (let i = 0; i < 3; i += 1) {
    try {
      const mp = await automator.connect({
        wsEndpoint: `ws://127.0.0.1:${PORT}`,
        timeout: 5000
      });
      const page = await mp.currentPage();
      const data = await page.data();
      const elements = {};
      const selectors = new Set();
      const config = pageConfig[page.path];
      if (config) {
        (config.required_elements || []).forEach((sel) => selectors.add(sel));
        (config.optional_elements || []).forEach((sel) => selectors.add(sel));
      }
      // Always include a small base set for visibility.
      ['text', 'image', 'button'].forEach((sel) => selectors.add(sel));

      for (const sel of selectors) {
        try {
          const els = await page.$$(sel);
          if (els.length > 0) elements[sel] = els.length;
        } catch (e) {}
      }

      const dataKeys = Object.keys(data);
      const validation = {};
      const issues = [];
      let pageUnderstood = false;
      let isValid = false;
      let pageName = null;

      if (!config) {
        issues.push('no_config_for_page');
      } else {
        pageUnderstood = true;
        pageName = config.name;

        for (const key of (config.required_data || [])) {
          if (!dataKeys.includes(key)) {
            issues.push(`missing_required_data:${key}`);
          }
        }

        for (const sel of (config.required_elements || [])) {
          if (!elements[sel] || elements[sel] === 0) {
            issues.push(`missing_required_element:${sel}`);
          }
        }

        const rules = config.validation_rules || {};
        for (const [ruleName, ruleExpr] of Object.entries(rules)) {
          let ruleResult = null;
          const matchList = ruleExpr.match(/^([A-Za-z0-9_]+)\.length\s*>\s*0$/);
          if (matchList) {
            const arr = data[matchList[1]];
            ruleResult = Array.isArray(arr) && arr.length > 0;
          }
          const matchCount = ruleExpr.match(/^(\.[^\s]+)\s+count\s*>\s*0$/);
          if (matchCount) {
            const sel = matchCount[1];
            ruleResult = (elements[sel] || 0) > 0;
          }
          const matchExists = ruleExpr.match(/^([A-Za-z0-9_]+)\s*exists$/);
          if (matchExists) {
            ruleResult = dataKeys.includes(matchExists[1]);
          }
          if (ruleResult === null) {
            issues.push(`unsupported_rule:${ruleName}`);
          }
          validation[ruleName] = ruleResult;
        }

        isValid = issues.length === 0;
      }

      console.log(JSON.stringify({
        path: page.path,
        query: page.query,
        page_name: pageName,
        page_understood: pageUnderstood,
        is_valid: isValid,
        issues,
        data_keys: dataKeys,
        page_elements: elements,
        validation
      }));
      await mp.disconnect();
      return;
    } catch (e) {
      lastErr = e;
      await new Promise((r) => setTimeout(r, 1000));
    }
  }

  console.error('FAIL', lastErr && lastErr.message ? lastErr.message : 'unknown_error');
  process.exit(1);
}

probe();
