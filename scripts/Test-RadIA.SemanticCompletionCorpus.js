/* global __dirname, process */

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");
const { performance } = require("node:perf_hooks");

function readArguments(values) {
  const result = { delphiVersion: "23.0", engine: "", maxSites: 2000, output: "" };
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    const next = values[index + 1];
    if (value === "--delphi-version" && next) {
      result.delphiVersion = next;
    } else if (value === "--engine" && next) {
      result.engine = next;
    } else if (value === "--max-sites" && next) {
      result.maxSites = Number(next);
    } else if (value === "--output" && next) {
      result.output = next;
    } else {
      throw new Error(`Unknown or incomplete argument: ${value}`);
    }
    index += 1;
  }
  if (!Number.isInteger(result.maxSites) || result.maxSites < 1) {
    throw new Error("--max-sites must be a positive integer.");
  }
  return result;
}

function collectPascalFiles(root) {
  const result = [];
  const visit = directory => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const entryPath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        visit(entryPath);
      } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".pas")) {
        result.push(entryPath);
      }
    }
  };
  visit(root);
  return result;
}

function createEngineClient(executable) {
  const child = childProcess.spawn(executable, [], {
    stdio: ["pipe", "pipe", "pipe"],
    windowsHide: true
  });
  const lines = readline.createInterface({ input: child.stdout });
  const pending = [];
  let stderr = "";
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", value => {
    stderr += value;
  });
  lines.on("line", line => {
    const request = pending.shift();
    if (!request) {
      return;
    }
    try {
      request.resolve(JSON.parse(line));
    } catch (error) {
      request.reject(new Error(`Invalid engine response: ${error.message}`));
    }
  });
  child.on("exit", code => {
    const message = `Semantic engine exited with code ${code}. ${stderr}`.trim();
    while (pending.length > 0) {
      pending.shift().reject(new Error(message));
    }
  });
  return {
    request(payload) {
      return new Promise((resolve, reject) => {
        pending.push({ resolve, reject });
        child.stdin.write(`${JSON.stringify(payload)}\n`, "utf8");
      });
    },
    async close(nextId) {
      await this.request({ id: nextId, method: "shutdown" });
      child.stdin.end();
      lines.close();
    }
  };
}

function percentile(values, ratio) {
  if (values.length === 0) {
    return 0;
  }
  const sorted = [...values].sort((left, right) => left - right);
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * ratio))];
}

function structuralNames(symbols) {
  const kinds = new Set(["class", "helper", "interface", "record"]);
  return symbols.filter(symbol => kinds.has(symbol.kind)).map(symbol => symbol.name);
}

function collectSites(symbols, fileName) {
  const containers = new Set(structuralNames(symbols).map(name => name.toLowerCase()));
  return symbols
    .filter(symbol => symbol.kind === "method")
    .filter(symbol => containers.has((symbol.container || "").toLowerCase()))
    .filter(symbol => symbol.name && symbol.name.length >= 2)
    .map(symbol => ({
      container: symbol.container,
      expectedName: symbol.name,
      fileName,
      prefix: symbol.name.slice(0, 2)
    }));
}

function uniqueSites(sites) {
  const seen = new Set();
  return sites.filter(site => {
    const key = `${site.container.toLowerCase()}:${site.prefix.toLowerCase()}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

async function indexCorpus(client, sourceRoot, files, requestId) {
  const sites = [];
  const containerCounts = new Map();
  for (const fileName of files) {
    const source = fs.readFileSync(fileName, "utf8");
    const relativeName = path.relative(sourceRoot, fileName);
    const scope = relativeName.toLowerCase().startsWith("vcl") ? "vcl" : "rtl";
    const parseResponse = await client.request({
      id: requestId.value++,
      method: "parse",
      params: { source, defines: [] }
    });
    if (parseResponse.error) {
      throw new Error(`${relativeName}: ${parseResponse.error.message}`);
    }
    const symbols = parseResponse.result.symbols || [];
    for (const name of structuralNames(symbols)) {
      const key = name.toLowerCase();
      containerCounts.set(key, (containerCounts.get(key) || 0) + 1);
    }
    sites.push(...collectSites(symbols, relativeName));
    const indexResponse = await client.request({
      id: requestId.value++,
      method: "indexUnit",
      params: {
        defines: [],
        fileName,
        revision: 1,
        scope,
        source,
        unitKey: relativeName.replaceAll("\\", "/")
      }
    });
    if (indexResponse.error) {
      throw new Error(`${relativeName}: ${indexResponse.error.message}`);
    }
  }
  return uniqueSites(
    sites.filter(site => containerCounts.get(site.container.toLowerCase()) === 1)
  );
}

async function evaluateSite(client, site, requestId) {
  const started = performance.now();
  const response = await client.request({
    id: requestId,
    method: "completeResolvedMembers",
    params: { container: site.container, maxItems: 100, prefix: site.prefix }
  });
  const latencyMs = performance.now() - started;
  if (response.error) {
    return { failure: response.error.message, latencyMs, reason: "engine-error" };
  }
  const result = response.result || {};
  const resolution = result.resolution || {};
  const symbols = result.symbols || [];
  let failure = "";
  if (!resolution.status || !resolution.reason) {
    failure = "silent-resolution";
  } else if (resolution.status !== "resolved") {
    failure = `unexpected-${resolution.status}`;
  } else if (symbols.length === 0) {
    failure = "candidate-list-empty";
  } else if (!symbols.every(symbol =>
    symbol.name.toLowerCase().startsWith(site.prefix.toLowerCase())
  )) {
    failure = "candidate-prefix-mismatch";
  }
  return {
    candidateCount: symbols.length,
    failure,
    latencyMs,
    reason: resolution.reason || "",
    status: resolution.status || ""
  };
}

async function run() {
  const options = readArguments(process.argv.slice(2));
  const repositoryRoot = path.resolve(__dirname, "..");
  const sourceRoot = path.join(
    "C:\\Program Files (x86)\\Embarcadero\\Studio",
    options.delphiVersion,
    "source"
  );
  const engine = options.engine || path.join(
    repositoryRoot,
    "Output",
    options.delphiVersion,
    "bin",
    "Win32",
    "Debug",
    "RadIA.Semantic.Engine.exe"
  );
  const roots = ["rtl", "vcl"].map(area => path.join(sourceRoot, area));
  for (const requiredPath of [engine, ...roots]) {
    if (!fs.existsSync(requiredPath)) {
      throw new Error(`Required corpus path does not exist: ${requiredPath}`);
    }
  }
  const files = roots.flatMap(collectPascalFiles).sort();
  const client = createEngineClient(engine);
  const requestId = { value: 1 };
  const outcomes = [];
  try {
    const availableSites = await indexCorpus(client, sourceRoot, files, requestId);
    const sites = availableSites.slice(0, options.maxSites);
    for (const site of sites) {
      outcomes.push({
        ...site,
        ...await evaluateSite(client, site, requestId.value++)
      });
    }
  } finally {
    await client.close(requestId.value);
  }
  const failures = outcomes.filter(outcome => outcome.failure);
  const latencies = outcomes.map(outcome => outcome.latencyMs);
  const report = {
    schemaVersion: "1.0",
    delphiVersion: options.delphiVersion,
    indexedFiles: files.length,
    evaluatedSites: outcomes.length,
    resolvedSites: outcomes.length - failures.length,
    silentSites: failures.filter(item => item.failure === "silent-resolution").length,
    averageCandidateCount: outcomes.length === 0 ? 0 :
      outcomes.reduce(
        (sum, item) => sum + (item.candidateCount || 0),
        0
      ) / outcomes.length,
    latencyMs: {
      maximum: latencies.length === 0 ? 0 : Math.max(...latencies),
      p50: percentile(latencies, 0.5),
      p95: percentile(latencies, 0.95)
    },
    failures
  };
  const output = options.output || path.join(
    repositoryRoot,
    "Output",
    "Evidence",
    `semantic-completion-corpus-${options.delphiVersion}.json`
  );
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  console.log(
    `Delphi ${options.delphiVersion}: ${report.resolvedSites}/${report.evaluatedSites} ` +
      `completion sites resolved; p95 ${report.latencyMs.p95.toFixed(2)} ms.`
  );
  console.log(`Evidence: ${output}`);
  if (outcomes.length === 0 || failures.length > 0) {
    process.exitCode = 1;
  }
}

run().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
