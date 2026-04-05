const fs = require('fs');
const path = require('path');
function readJson(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
  return JSON.parse(raw);
}

function httpGetJson(url) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? require('https') : require('http');
    const req = mod.get(url, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          resolve({ statusCode: res.statusCode, data: parsed, raw: body });
        } catch (err) {
          resolve({ statusCode: res.statusCode, data: null, raw: body });
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(45000, () => {
      req.destroy(new Error('request_timeout'));
    });
  });
}

function listLocalFunctions(root) {
  if (!fs.existsSync(root)) {
    return [];
  }
  return fs.readdirSync(root, { withFileTypes: true })
    .filter((x) => x.isDirectory())
    .map((x) => {
      const funcRoot = path.join(root, x.name);
      return {
        name: x.name,
        path: funcRoot,
        has_index: fs.existsSync(path.join(funcRoot, 'index.js')),
        has_package_json: fs.existsSync(path.join(funcRoot, 'package.json'))
      };
    });
}

async function getDevtoolsPortAsync(fallback) {
  const os = require('os');
  const net = require('net');
  const childProcess = require('child_process');
  const psPortScript = path.join(__dirname, 'scripts', 'wechat-get-port.ps1');
  const base = path.join(
    process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'),
    '微信开发者工具',
    'User Data'
  );

  function checkTcp(port) {
    return new Promise((resolve) => {
      if (!Number.isInteger(port) || port <= 1024) {
        resolve(false);
        return;
      }
      const socket = new net.Socket();
      socket.setTimeout(300);
      socket.on('connect', () => {
        socket.destroy();
        resolve(true);
      });
      socket.on('error', () => {
        socket.destroy();
        resolve(false);
      });
      socket.on('timeout', () => {
        socket.destroy();
        resolve(false);
      });
      socket.connect(port, '127.0.0.1');
    });
  }

  // First choice: reuse the proven PowerShell detector from the current workspace.
  try {
    if (fs.existsSync(psPortScript)) {
      const command = `. '${psPortScript.replace(/'/g, "''")}'; Get-WechatDevtoolsPort`;
      const rawPort = childProcess.execFileSync(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command],
        { encoding: 'utf8' }
      ).trim();
      const psPort = Number(rawPort.split(/\r?\n/).pop());
      if (Number.isInteger(psPort) && psPort > 1024 && await checkTcp(psPort)) {
        console.error(`[PORT] ps_port=${psPort}`);
        return psPort;
      }
    }
  } catch (err) {
    console.error(`[PORT] ps_port_failed=${err.message}`);
  }

  try {
    const dirs = fs.readdirSync(base, { withFileTypes: true });
    let latest = { time: 0, port: 0 };
    for (const dir of dirs) {
      if (!dir.isDirectory()) continue;
      const idePath = path.join(base, dir.name, 'Default', '.ide');
      if (!fs.existsSync(idePath)) continue;
      const stat = fs.statSync(idePath);
      const port = Number(fs.readFileSync(idePath, 'utf8').trim());
      if (Number.isInteger(port) && port > 1024 && stat.mtimeMs > latest.time) {
        latest = { time: stat.mtimeMs, port };
      }
    }
    if (latest.port > 1024 && await checkTcp(latest.port)) {
      console.error(`[PORT] ide_port=${latest.port}`);
      return latest.port;
    }
  } catch (err) {
    console.error(`[PORT] ide_scan_failed=${err.message}`);
  }

  const fallbackPorts = [];
  const envPort = Number(process.env.DEVTOOLS_PORT || '');
  if (Number.isInteger(envPort) && envPort > 1024) {
    if (await checkTcp(envPort)) {
      console.error(`[PORT] env_port=${envPort}`);
      return envPort;
    }
    console.error(`[PORT] env_port_unreachable=${envPort}`);
  }
  if (Number.isInteger(Number(fallback)) && Number(fallback) > 1024) {
    fallbackPorts.push(Number(fallback));
  }
  fallbackPorts.push(51079, 34757, 23392, 9420);
  for (const port of [...new Set(fallbackPorts)]) {
    if (await checkTcp(port)) {
      console.error(`[PORT] tcp_port=${port}`);
      return port;
    }
  }

  if (Number.isInteger(Number(fallback)) && Number(fallback) > 1024) {
    console.error(`[PORT] fallback_port=${Number(fallback)}`);
    return Number(fallback);
  }

  console.error('[PORT] fallback_port=51079');
  return 51079;
}

function checkBeforeDeploy(config, funcName) {
  const errors = [];
  if (!config.cloudEnv) errors.push('cloudEnv missing');
  if (!config.projectPath || !fs.existsSync(config.projectPath)) errors.push(`projectPath missing: ${config.projectPath}`);
  if (!config.cloudFunctionRoot || !fs.existsSync(config.cloudFunctionRoot)) errors.push(`cloudFunctionRoot missing: ${config.cloudFunctionRoot}`);
  if (!config.privateKeyPath || !fs.existsSync(config.privateKeyPath)) errors.push(`privateKeyPath missing: ${config.privateKeyPath}`);

  if (funcName) {
    const funcPath = path.join(config.cloudFunctionRoot, funcName);
    if (!fs.existsSync(funcPath)) errors.push(`function directory missing: ${funcPath}`);
    if (!fs.existsSync(path.join(funcPath, 'index.js'))) errors.push(`index.js missing: ${path.join(funcPath, 'index.js')}`);
  }
  return errors;
}

async function deployViaHttp(funcName, port, config) {
  const projectRoot = config.projectRoot || path.dirname(config.projectPath);
  const params = new URLSearchParams({
    env: config.cloudEnv,
    names: funcName,
    project: projectRoot,
    'remote-npm-install': ''
  });
  const deployPath = `/v2/cloud/functions/deploy?${params.toString()}`;

  function pollTaskResult(taskPath, maxWait = 120000) {
    return new Promise(async (resolve) => {
      const started = Date.now();
      while (Date.now() - started < maxWait) {
        let polled;
        try {
          polled = await httpGetJson(`http://127.0.0.1:${port}${taskPath}`);
        } catch (err) {
          resolve({ done: true, success: false, reason: err.message });
          return;
        }

        console.error(`[DEPLOY] taskresult status=${polled.statusCode} body=${JSON.stringify(polled.data || polled.raw).slice(0, 200)}`);
        if (polled.statusCode === 200) {
          const body = polled.data || {};
          if (body && typeof body === 'object' && !Array.isArray(body) && body.status) {
            const statusValue = String(body.status).toLowerCase();
            resolve({ done: true, success: statusValue !== 'failed', result: body });
            return;
          }

          if (body && typeof body === 'object' && !Array.isArray(body)) {
            const keys = Object.keys(body);
            if (keys.length > 0) {
              const first = body[keys[0]];
              if (first && typeof first === 'object' && first.filesCount !== undefined) {
                resolve({
                  done: true,
                  success: true,
                  func: keys[0],
                  filesCount: first.filesCount,
                  packSize: first.packSize,
                  result: body
                });
                return;
              }
            }
          }

          resolve({ done: true, success: true, result: body || polled.raw });
          return;
        }
        if (polled.statusCode === 202) {
          await new Promise((r) => setTimeout(r, 2000));
          continue;
        }

        if (polled.statusCode === 404) {
          resolve({ done: true, success: null, reason: 'taskresult_expired', statusCode: polled.statusCode, result: polled.data || polled.raw });
          return;
        }

        resolve({ done: true, success: false, result: polled.data || polled.raw, statusCode: polled.statusCode });
        return;
      }

      resolve({ done: false, success: false, reason: 'timeout' });
    });
  }

  return new Promise((resolve, reject) => {
    const req = require('http').get({
      host: '127.0.0.1',
      port,
      path: deployPath
    }, (res) => {
      console.error(`[DEPLOY] deploy status=${res.statusCode}`);
      if (res.statusCode === 303) {
        const taskPath = res.headers.location;
        console.error(`[DEPLOY] taskresult location=${taskPath}`);
        pollTaskResult(taskPath).then(resolve).catch(reject);
        res.resume();
        return;
      }

      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve({ done: true, success: true, result: body ? JSON.parse(body) : {} });
          } catch (err) {
            resolve({ done: true, success: true, result: body });
          }
          return;
        }
        reject(new Error(`HTTP ${res.statusCode}: ${body}`));
      });
    });
    req.on('error', reject);
  });
}

async function previewViaHttp(port, projectPath) {
  const previewPath = `/v2/preview?project=${encodeURIComponent(projectPath)}&qr-format=terminal`;

  function pollTaskResult(taskPath, maxWait = 120000) {
    return new Promise(async (resolve) => {
      const started = Date.now();
      while (Date.now() - started < maxWait) {
        let polled;
        try {
          polled = await httpGetJson(`http://127.0.0.1:${port}${taskPath}`);
        } catch (err) {
          resolve({ done: true, success: false, reason: err.message });
          return;
        }

        console.error(`[PREVIEW] taskresult status=${polled.statusCode} body=${JSON.stringify(polled.data || polled.raw).slice(0, 200)}`);
        if (polled.statusCode === 200) {
          resolve({ done: true, success: true, result: polled.data || polled.raw });
          return;
        }
        if (polled.statusCode === 202) {
          await new Promise((r) => setTimeout(r, 2000));
          continue;
        }

        resolve({ done: true, success: false, result: polled.data || polled.raw, statusCode: polled.statusCode });
        return;
      }

      resolve({ done: false, success: false, reason: 'timeout' });
    });
  }

  return new Promise((resolve, reject) => {
    const req = require('http').get({
      host: '127.0.0.1',
      port,
      path: previewPath
    }, (res) => {
      console.error(`[PREVIEW] status=${res.statusCode}`);
      if (res.statusCode === 303) {
        const taskPath = res.headers.location;
        console.error(`[PREVIEW] taskresult location=${taskPath}`);
        pollTaskResult(taskPath).then(resolve).catch(reject);
        res.resume();
        return;
      }

      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve({ done: true, success: true, result: body ? JSON.parse(body) : {} });
          } catch (err) {
            resolve({ done: true, success: true, result: body });
          }
          return;
        }
        reject(new Error(`HTTP ${res.statusCode}: ${body}`));
      });
    });
    req.on('error', reject);
  });
}

async function verifyDeployment(config, funcName, port) {
  const projectRoot = config.projectRoot || path.dirname(config.projectPath);
  const url = `http://127.0.0.1:${port}/v2/cloud/functions/info` +
    `?env=${encodeURIComponent(config.cloudEnv)}` +
    `&names=${encodeURIComponent(funcName)}` +
    `&project=${encodeURIComponent(projectRoot)}`;
  return httpGetJson(url);
}

async function main() {
  const args = process.argv.slice(2);
  const mode = (args[0] || 'preview').toLowerCase();
  const configCandidates = [];
  if (process.env.WECHAT_DEPLOY_CONFIG_PATH) {
    configCandidates.push(process.env.WECHAT_DEPLOY_CONFIG_PATH);
  }
  configCandidates.push(path.join(__dirname, 'config', 'local-release.config.json'));
  configCandidates.push(path.join(__dirname, 'deploy-config.json'));
  const configPath = args[1] || configCandidates.find((p) => fs.existsSync(p)) || configCandidates[0];
  const functionName = args[2] || null;
  const config = readJson(configPath);
  const projectRoot = config.projectRoot || path.resolve(config.projectPath, '..');
  const projectPath = projectRoot.replace(/\\/g, '\\\\');
  const port = await getDevtoolsPortAsync(process.env.DEVTOOLS_PORT || config.devtoolsPort);

  if (mode === 'preview') {
    let resp;
    try {
      resp = await previewViaHttp(port, projectPath);
    } catch (err) {
      resp = { done: true, success: false, error: err.message };
    }
    console.log(JSON.stringify({
      mode: 'preview',
      status: resp.success ? 'preview_ok' : 'preview_failed',
      cloudEnv: config.cloudEnv,
      port,
      response: resp.result || resp.error || resp.reason
    }));
    process.exit(resp.success ? 0 : 1);
  }

  if (mode === 'list-functions' || mode === 'cloud-list') {
    console.log(JSON.stringify({
      mode,
      cloudEnv: config.cloudEnv,
      functions: listLocalFunctions(config.cloudFunctionRoot)
    }));
    process.exit(0);
  }

  if (mode === 'deploy-function') {
    if (!functionName) {
      console.log(JSON.stringify({
        status: 'preflight_failed',
        errors: ['deploy-function requires functionName']
      }));
      process.exit(2);
    }

    const errors = checkBeforeDeploy(config, functionName);
    if (errors.length > 0) {
      console.log(JSON.stringify({
        mode: 'deploy-function',
        status: 'preflight_failed',
        functionName,
        errors
      }));
      process.exit(1);
    }

    const deployPort = await getDevtoolsPortAsync(process.env.DEVTOOLS_PORT || config.devtoolsPort);
    console.error(`[DEPLOY] using_port=${deployPort}`);

    let deployResult;
    try {
      deployResult = await deployViaHttp(functionName, deployPort, config);
    } catch (err) {
      deployResult = { done: true, success: false, error: err.message };
    }
    const verifyResult = await verifyDeployment(config, functionName, deployPort);
    const verifyOk = verifyResult.statusCode >= 200 && verifyResult.statusCode < 300 &&
      !verifyResult.data?.error;
    const deployOk = deployResult && (
      deployResult.success === true ||
      (deployResult.success === null && verifyOk)
    );

    console.log(JSON.stringify({
      mode: 'deploy-function',
      functionName,
      status: deployOk ? 'deployed' : 'deploy_failed',
      verified: verifyOk,
      port: deployPort,
      deploy_result: deployResult.result || deployResult.error || deployResult.reason || null,
      verify_result: verifyResult.data || verifyResult.raw
    }));
    process.exit(deployOk && verifyOk ? 0 : 1);
  }

  console.log(JSON.stringify({
    status: 'unsupported_mode',
    mode
  }));
  process.exit(2);
}

main().catch((err) => {
  console.error(`fatal:${err.message}`);
  process.exit(1);
});

