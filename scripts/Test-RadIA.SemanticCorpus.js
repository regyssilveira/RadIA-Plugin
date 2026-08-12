/* global __dirname, process */

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");

function readArguments(values) {
  const result = {
    delphiVersion: "23.0",
    engine: "",
    minimumParseRate: 0.99,
    output: ""
  };
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    const next = values[index + 1];
    if (value === "--delphi-version" && next) {
      result.delphiVersion = next;
      index += 1;
    } else if (value === "--engine" && next) {
      result.engine = next;
      index += 1;
    } else if (value === "--minimum-parse-rate" && next) {
      result.minimumParseRate = Number(next);
      index += 1;
    } else if (value === "--output" && next) {
      result.output = next;
      index += 1;
    } else {
      throw new Error(`Unknown or incomplete argument: ${value}`);
    }
  }
  return result;
}

function collectPascalFiles(root) {
  const result = [];
  const visit = (directory) => {
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
  child.stderr.on("data", (value) => {
    stderr += value;
  });
  lines.on("line", (line) => {
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
  child.on("exit", (code) => {
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

function isFatalDiagnostic(message) {
  return /not closed|is missing|has no equals sign/i.test(message);
}

async function analyzeFile(client, fileName, requestId) {
  const source = fs.readFileSync(fileName, "utf8");
  const response = await client.request({
    id: requestId,
    method: "analyze",
    params: { source, defines: [] }
  });
  if (response.error) {
    return {
      tokenCoverage: false,
      parsed: false,
      diagnostics: [response.error.message]
    };
  }
  const diagnostics = response.result.diagnostics || [];
  return {
    tokenCoverage: response.result.tokensContiguous &&
      response.result.coveredLength === response.result.sourceLength,
    parsed: response.result.hasModule && !diagnostics.some(isFatalDiagnostic),
    diagnostics
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
  const roots = ["rtl", "vcl"].map((area) => path.join(sourceRoot, area));
  for (const requiredPath of [engine, ...roots]) {
    if (!fs.existsSync(requiredPath)) {
      throw new Error(`Required corpus path does not exist: ${requiredPath}`);
    }
  }

  const files = roots.flatMap(collectPascalFiles).sort();
  const failures = [];
  const tokenCoverageFailures = [];
  let coveredFiles = 0;
  let parsedFiles = 0;
  let requestId = 1;
  const client = createEngineClient(engine);
  try {
    for (const fileName of files) {
      const result = await analyzeFile(client, fileName, requestId);
      requestId += 1;
      if (result.tokenCoverage) {
        coveredFiles += 1;
      } else {
        tokenCoverageFailures.push(path.relative(sourceRoot, fileName));
      }
      if (result.parsed) {
        parsedFiles += 1;
      } else {
        failures.push({
          file: path.relative(sourceRoot, fileName),
          diagnostics: result.diagnostics
        });
      }
    }
  } finally {
    await client.close(requestId);
  }

  const parseRate = files.length === 0 ? 0 : parsedFiles / files.length;
  const report = {
    schemaVersion: "1.0",
    delphiVersion: options.delphiVersion,
    sourceRoot,
    corpusAreas: ["rtl", "vcl"],
    totalFiles: files.length,
    tokenCoverageFiles: coveredFiles,
    tokenCoverageRate: files.length === 0 ? 0 : coveredFiles / files.length,
    parsedFiles,
    parseRate,
    minimumParseRate: options.minimumParseRate,
    tokenCoverageFailures,
    failures
  };
  const output = options.output || path.join(
    repositoryRoot,
    "Output",
    "Evidence",
    `semantic-corpus-${options.delphiVersion}.json`
  );
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`, "utf8");

  console.log(
    `Delphi ${options.delphiVersion}: ${parsedFiles}/${files.length} parsed, ` +
      `${coveredFiles}/${files.length} exact token coverage.`
  );
  console.log(`Evidence: ${output}`);
  if (coveredFiles !== files.length || parseRate < options.minimumParseRate) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
