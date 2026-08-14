/* global __dirname, process */

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");

function readDelphiVersion(values) {
  const index = values.indexOf("--delphi-version");
  if (index < 0 || !values[index + 1]) throw new Error("Use --delphi-version with 23.0 or 37.0.");
  if (!["23.0", "37.0"].includes(values[index + 1])) {
    throw new Error("Only Delphi 12 (23.0) and Delphi 13 (37.0) are supported.");
  }
  return values[index + 1];
}

function createEngineClient(executable) {
  const child = childProcess.spawn(executable, [], { stdio: ["pipe", "pipe", "pipe"], windowsHide: true });
  const lines = readline.createInterface({ input: child.stdout });
  const pending = [];
  let stderr = "";
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", value => { stderr += value; });
  lines.on("line", line => {
    const request = pending.shift();
    if (!request) return;
    try {
      request.resolve(JSON.parse(line));
    } catch (error) {
      request.reject(new Error(`Invalid engine response: ${error.message}`));
    }
  });
  child.on("exit", code => {
    const message = `Semantic engine exited with code ${code}. ${stderr}`.trim();
    while (pending.length > 0) pending.shift().reject(new Error(message));
  });
  return {
    request(payload) {
      return new Promise((resolve, reject) => {
        pending.push({ resolve, reject });
        child.stdin.write(`${JSON.stringify(payload)}\n`, "utf8");
      });
    },
    async close(id) {
      await this.request({ id, method: "shutdown" });
      child.stdin.end();
      lines.close();
    }
  };
}

async function requireResult(client, id, method, params) {
  const response = await client.request({ id, method, params });
  if (response.error) throw new Error(response.error.message);
  if (!response.result) throw new Error(`${method} returned no result.`);
  return response.result;
}

function compileFixture(delphiVersion, fixtureRoot, projectName, defines) {
  const compiler = path.join(
    "C:\\Program Files (x86)\\Embarcadero\\Studio", delphiVersion, "bin", "dcc32.exe"
  );
  const arguments = ["-B", "-Q", "-N0Output", "-EOutput"];
  if (defines.length > 0) arguments.push(`-D${defines.join(";")}`);
  arguments.push(`${projectName}.dpr`);
  const result = childProcess.spawnSync(
    compiler,
    arguments,
    { cwd: fixtureRoot, encoding: "utf8", windowsHide: true }
  );
  if (result.status !== 0) {
    throw new Error(`${projectName} did not compile.\n${result.stdout}\n${result.stderr}`);
  }
  return `${result.stdout}${result.stderr}`;
}

function runFixture(fixtureRoot, projectName) {
  const executable = path.join(fixtureRoot, "Output", `${projectName}.exe`);
  const result = childProcess.spawnSync(executable, [], {
    cwd: fixtureRoot,
    encoding: "utf8",
    windowsHide: true
  });
  if (result.status !== 0 || !result.stdout.includes("SEMANTIC_PROBE_OK")) {
    throw new Error(`${projectName} failed at runtime.\n${result.stdout}\n${result.stderr}`);
  }
  return `${result.stdout}${result.stderr}`;
}

function createCases() {
  return [
    {
      name: "basic-signatures", defines: [], expectedMissing: 2,
      contracts: [
        "unit Contracts;", "interface", "type", "  IWorker = interface(IInterface)",
        "    procedure Execute(const AValue: Integer);", "    function Ready: Boolean;", "  end;",
        "implementation", "end."
      ],
      workerAncestors: "TInterfacedObject, IWorker",
      runtimeCalls: ["  LContract.Execute(42);", "  LContract.Ready;"]
    },
    {
      name: "overloaded-methods", defines: [], expectedMissing: 2,
      contracts: [
        "unit Contracts;", "interface", "type", "  IWorker = interface(IInterface)",
        "    procedure Execute(const AValue: Integer); overload;",
        "    procedure Execute(const AValue: string); overload;", "  end;", "implementation", "end."
      ],
      workerAncestors: "TInterfacedObject, IWorker",
      runtimeCalls: ["  LContract.Execute(42);", "  LContract.Execute('probe');"]
    },
    {
      name: "inherited-interface", defines: [], expectedMissing: 2,
      contracts: [
        "unit Contracts;", "interface", "type", "  IBaseWorker = interface(IInterface)",
        "    procedure Start;", "  end;", "  IWorker = interface(IBaseWorker)",
        "    procedure Stop;", "  end;", "implementation", "end."
      ],
      workerAncestors: "TInterfacedObject, IWorker",
      runtimeCalls: ["  LContract.Start;", "  LContract.Stop;"]
    },
    {
      name: "inherited-implementation", defines: [], expectedMissing: 1,
      contracts: [
        "unit Contracts;", "interface", "type", "  IWorker = interface(IInterface)",
        "    procedure Start;", "    procedure Stop;", "  end;", "implementation", "end."
      ],
      baseDeclaration: "  TBaseWorker = class(TInterfacedObject)\r\n  public\r\n    procedure Start;\r\n  end;",
      baseImplementation: "procedure TBaseWorker.Start;\r\nbegin\r\nend;\r\n\r\n",
      workerAncestors: "TBaseWorker, IWorker",
      runtimeCalls: ["  LContract.Start;", "  LContract.Stop;"]
    },
    {
      name: "conditional-contract", defines: ["FEATURE_EXTRA"], expectedMissing: 2,
      contracts: [
        "unit Contracts;", "interface", "type", "  IWorker = interface(IInterface)",
        "    procedure Execute;", "{$IFDEF FEATURE_EXTRA}", "    procedure ExecuteExtra;",
        "{$ENDIF}", "  end;", "implementation", "end."
      ],
      workerAncestors: "TInterfacedObject, IWorker",
      runtimeCalls: ["  LContract.Execute;", "  LContract.ExecuteExtra;"]
    }
  ];
}

function buildWorkerSource(probe) {
  const typeLines = ["type"];
  if (probe.baseDeclaration) typeLines.push(probe.baseDeclaration);
  typeLines.push(`  TWorker = class(${probe.workerAncestors})`, "  end;");
  return [
    "unit Worker;", "interface", "uses System.SysUtils, Contracts;", ...typeLines,
    "implementation", probe.baseImplementation || "", "end."
  ].join("\r\n");
}

function writeProject(fixtureRoot, probe, contractSource, proposedSource) {
  const projectName = probe.name.replaceAll("-", "_");
  fs.mkdirSync(path.join(fixtureRoot, "Output"), { recursive: true });
  fs.writeFileSync(path.join(fixtureRoot, "Contracts.pas"), contractSource, "utf8");
  fs.writeFileSync(path.join(fixtureRoot, "Worker.pas"), proposedSource, "utf8");
  fs.writeFileSync(path.join(fixtureRoot, `${projectName}.dpr`), [
    `program ${projectName};`, "{$APPTYPE CONSOLE}", "uses Contracts, Worker;", "var LContract: IWorker;",
    "begin", "  LContract := TWorker.Create;", ...probe.runtimeCalls, "  Writeln('SEMANTIC_PROBE_OK');",
    "end."
  ].join("\r\n"), "utf8");
  return projectName;
}

async function evaluateCase(client, requestId, probe, fixtureRoot, delphiVersion) {
  const contractSource = probe.contracts.join("\r\n");
  const workerSource = buildWorkerSource(probe);
  await requireResult(client, requestId.value++, "indexUnit", {
    unitKey: `contracts-${probe.name}`, fileName: "Contracts.pas", scope: "group", revision: 1,
    source: contractSource, defines: probe.defines
  });
  await requireResult(client, requestId.value++, "indexUnit", {
    unitKey: `worker-${probe.name}`, fileName: "Worker.pas", scope: "project", revision: 1,
    source: workerSource, defines: probe.defines
  });
  const preview = await requireResult(client, requestId.value++, "prepareMissingMembers", {
    source: workerSource, container: "TWorker", defines: probe.defines
  });
  if (!preview.changed || preview.missingCount !== probe.expectedMissing) {
    throw new Error(`${probe.name}: expected ${probe.expectedMissing} missing members.`);
  }
  await requireResult(client, requestId.value++, "indexUnit", {
    unitKey: `worker-${probe.name}`, fileName: "Worker.pas", scope: "project", revision: 2,
    source: preview.proposedSource, defines: probe.defines
  });
  const repeated = await requireResult(client, requestId.value++, "prepareMissingMembers", {
    source: preview.proposedSource, container: "TWorker", defines: probe.defines
  });
  if (repeated.changed || repeated.missingCount !== 0) {
    throw new Error(`${probe.name}: repeated preview was not idempotent.`);
  }
  const projectName = writeProject(fixtureRoot, probe, contractSource, preview.proposedSource);
  const compilerOutput = compileFixture(delphiVersion, fixtureRoot, projectName, probe.defines);
  const runtimeOutput = runFixture(fixtureRoot, projectName);
  fs.writeFileSync(path.join(fixtureRoot, "compile.log"), compilerOutput, "utf8");
  fs.writeFileSync(path.join(fixtureRoot, "runtime.log"), runtimeOutput, "utf8");
}

async function run() {
  const delphiVersion = readDelphiVersion(process.argv.slice(2));
  const repositoryRoot = path.resolve(__dirname, "..");
  const engine = path.join(
    repositoryRoot, "Output", delphiVersion, "bin", "Win32", "Debug", "RadIA.Semantic.Engine.exe"
  );
  if (!fs.existsSync(engine)) throw new Error(`Semantic engine not found: ${engine}`);
  const validationRoot = path.join(repositoryRoot, "Output", "Validation", "SemanticLanguageProbes");
  const versionRoot = path.join(validationRoot, delphiVersion);
  if (!versionRoot.startsWith(`${validationRoot}${path.sep}`)) throw new Error("Invalid validation output path.");
  fs.rmSync(versionRoot, { recursive: true, force: true });
  fs.mkdirSync(versionRoot, { recursive: true });
  const probes = createCases();
  for (const probe of probes) {
    const client = createEngineClient(engine);
    const requestId = { value: 1 };
    try {
    await requireResult(client, requestId.value++, "initialize", {});
      const fixtureRoot = path.join(versionRoot, probe.name);
      fs.mkdirSync(fixtureRoot, { recursive: true });
      await evaluateCase(client, requestId, probe, fixtureRoot, delphiVersion);
    } finally {
      await client.close(requestId.value);
    }
  }
  console.log(
    `Delphi ${delphiVersion}: ${probes.length} semantic language probes compiled and ran successfully.`
  );
}

run().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
