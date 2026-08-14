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

function activeTokenTexts(source, tokens) {
  return tokens
    .filter(token => token.activity !== "inactive")
    .filter(token => token.kind !== "whitespace" && token.kind !== "comment")
    .map(token => ({
      offset: token.startOffset,
      text: source.slice(token.startOffset, token.startOffset + token.length).toLowerCase()
    }));
}

function findStructuralAnchors(tokens) {
  const structuralKinds = new Set(["class", "interface", "object", "record"]);
  const result = [];
  for (let index = 0; index + 3 < tokens.length; index += 1) {
    if (tokens[index].text === "implementation") {
      break;
    }
    if (tokens[index].text !== "type" || tokens[index + 2].text !== "=") {
      continue;
    }
    let kindIndex = index + 3;
    if (tokens[kindIndex].text === "packed") {
      kindIndex += 1;
    }
    const nextText = kindIndex + 1 < tokens.length ? tokens[kindIndex + 1].text : "";
    if (
      kindIndex < tokens.length &&
      structuralKinds.has(tokens[kindIndex].text) &&
      !(tokens[kindIndex].text === "class" && nextText === "of")
    ) {
      result.push({
        name: tokens[index + 1].text,
        offset: tokens[index + 1].offset
      });
    }
  }
  return result;
}

function inspectParsedSymbols(source, symbols) {
  const structuralKinds = new Set(["class", "helper", "interface", "record"]);
  const offsets = new Set();
  let spansValid = true;
  let structuralCount = 0;
  let moduleCount = 0;
  for (const symbol of symbols) {
    const endOffset = symbol.startOffset + symbol.length;
    if (symbol.startOffset < 0 || symbol.length < 1 || endOffset > source.length) {
      spansValid = false;
    }
    if (symbol.kind === "module") {
      moduleCount += 1;
    }
    if (structuralKinds.has(symbol.kind)) {
      structuralCount += 1;
      const identity = `${symbol.startOffset}:${symbol.length}`;
      if (offsets.has(identity)) {
        spansValid = false;
      }
      offsets.add(identity);
    }
  }
  return { moduleCount, offsets, spansValid, structuralCount };
}

async function analyzeFile(client, fileName, requestId) {
  const source = fs.readFileSync(fileName, "utf8");
  const analyzeResponse = await client.request({
    id: requestId,
    method: "analyze",
    params: { source, defines: [] }
  });
  const preprocessResponse = await client.request({
    id: requestId + 1,
    method: "preprocess",
    params: { source, defines: [] }
  });
  const parseResponse = await client.request({
    id: requestId + 2,
    method: "parse",
    params: { source, defines: [] }
  });
  if (analyzeResponse.error || preprocessResponse.error || parseResponse.error) {
    const error = analyzeResponse.error || preprocessResponse.error || parseResponse.error;
    return {
      tokenCoverage: false,
      parsed: false,
      oracleMatches: false,
      spansValid: false,
      diagnostics: [error.message]
    };
  }
  const diagnostics = analyzeResponse.result.diagnostics || [];
  const tokens = activeTokenTexts(source, preprocessResponse.result.tokens || []);
  const symbolInspection = inspectParsedSymbols(
    source,
    parseResponse.result.symbols || []
  );
  const oracleAnchors = findStructuralAnchors(tokens);
  const missingAnchors = oracleAnchors.filter(
    anchor => !symbolInspection.offsets.has(`${anchor.offset}:${anchor.name.length}`)
  );
  return {
    tokenCoverage: analyzeResponse.result.tokensContiguous &&
      analyzeResponse.result.coveredLength === analyzeResponse.result.sourceLength,
    parsed: analyzeResponse.result.hasModule && !diagnostics.some(isFatalDiagnostic),
    oracleMatches: missingAnchors.length === 0,
    oracleStructuralCount: oracleAnchors.length,
    parsedStructuralCount: symbolInspection.structuralCount,
    missingAnchors,
    spansValid: symbolInspection.spansValid && symbolInspection.moduleCount === 1,
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
  const oracleFailures = [];
  const spanFailures = [];
  const tokenCoverageFailures = [];
  let coveredFiles = 0;
  let parsedFiles = 0;
  let requestId = 1;
  const client = createEngineClient(engine);
  try {
    for (const fileName of files) {
      const result = await analyzeFile(client, fileName, requestId);
      requestId += 3;
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
      if (!result.oracleMatches) {
        oracleFailures.push({
          file: path.relative(sourceRoot, fileName),
          oracleStructuralCount: result.oracleStructuralCount || 0,
          parsedStructuralCount: result.parsedStructuralCount || 0,
          missingAnchors: result.missingAnchors || []
        });
      }
      if (!result.spansValid) {
        spanFailures.push(path.relative(sourceRoot, fileName));
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
    oracleMatchedFiles: files.length - oracleFailures.length,
    oracleMatchRate: files.length === 0 ? 0 :
      (files.length - oracleFailures.length) / files.length,
    validSpanFiles: files.length - spanFailures.length,
    tokenCoverageFailures,
    oracleFailures,
    spanFailures,
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
  if (
    coveredFiles !== files.length ||
    parseRate < options.minimumParseRate ||
    oracleFailures.length > 0 ||
    spanFailures.length > 0
  ) {
    process.exitCode = 1;
  }
}

run().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
