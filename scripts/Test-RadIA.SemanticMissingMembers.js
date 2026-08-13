/* global __dirname, process */

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");

function readDelphiVersion(values) {
  const index = values.indexOf("--delphi-version");
  if (index < 0 || !values[index + 1]) {
    throw new Error("Use --delphi-version with 23.0 or 37.0.");
  }
  if (!["23.0", "37.0"].includes(values[index + 1])) {
    throw new Error("Only Delphi 12 (23.0) and Delphi 13 (37.0) are supported.");
  }
  return values[index + 1];
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

function compileFixture(delphiVersion, fixtureRoot) {
  const compiler = path.join(
    "C:\\Program Files (x86)\\Embarcadero\\Studio",
    delphiVersion,
    "bin",
    "dcc32.exe"
  );
  const result = childProcess.spawnSync(
    compiler,
    ["-B", "-Q", "-N0Output", "-EOutput", "SemanticMembersSmoke.dpr"],
    { cwd: fixtureRoot, encoding: "utf8", windowsHide: true }
  );
  if (result.status !== 0) {
    throw new Error(`Generated code did not compile.\n${result.stdout}\n${result.stderr}`);
  }
  return `${result.stdout}${result.stderr}`;
}

async function run() {
  const delphiVersion = readDelphiVersion(process.argv.slice(2));
  const repositoryRoot = path.resolve(__dirname, "..");
  const engine = path.join(
    repositoryRoot,
    "Output",
    delphiVersion,
    "bin",
    "Win32",
    "Debug",
    "RadIA.Semantic.Engine.exe"
  );
  if (!fs.existsSync(engine)) throw new Error(`Semantic engine not found: ${engine}`);

  const validationRoot = path.join(repositoryRoot, "Output", "Validation");
  const fixtureRoot = path.join(validationRoot, "SemanticMissingMembers", delphiVersion);
  if (!fixtureRoot.startsWith(`${validationRoot}${path.sep}`)) {
    throw new Error("Invalid validation output path.");
  }
  fs.rmSync(fixtureRoot, { recursive: true, force: true });
  fs.mkdirSync(path.join(fixtureRoot, "Output"), { recursive: true });

  const contractSource = [
    "unit Contracts;",
    "interface",
    "type",
    "  IWorker = interface(IInterface)",
    "    procedure Execute(const AValue: Integer);",
    "    function Ready: Boolean;",
    "  end;",
    "implementation",
    "end."
  ].join("\r\n");
  const workerSource = [
    "unit Worker;",
    "interface",
    "uses System.SysUtils, Contracts;",
    "type",
    "  TWorker = class(TInterfacedObject, IWorker)",
    "  end;",
    "implementation",
    "end."
  ].join("\r\n");

  const client = createEngineClient(engine);
  let requestId = 1;
  let proposedSource;
  try {
    await requireResult(client, requestId++, "initialize", {});
    await requireResult(client, requestId++, "indexUnit", {
      unitKey: "contracts",
      fileName: "Contracts.pas",
      scope: "group",
      revision: 1,
      source: contractSource
    });
    await requireResult(client, requestId++, "indexUnit", {
      unitKey: "worker",
      fileName: "Worker.pas",
      scope: "project",
      revision: 1,
      source: workerSource
    });
    const preview = await requireResult(client, requestId++, "prepareMissingMembers", {
      source: workerSource,
      container: "TWorker",
      defines: []
    });
    if (!preview.changed || preview.missingCount !== 2) {
      throw new Error("The first preview did not generate both missing members.");
    }
    proposedSource = preview.proposedSource;
    await requireResult(client, requestId++, "indexUnit", {
      unitKey: "worker",
      fileName: "Worker.pas",
      scope: "project",
      revision: 2,
      source: proposedSource
    });
    const repeated = await requireResult(client, requestId++, "prepareMissingMembers", {
      source: proposedSource,
      container: "TWorker",
      defines: []
    });
    if (repeated.changed || repeated.missingCount !== 0) {
      throw new Error("The repeated preview was not idempotent.");
    }
  } finally {
    await client.close(requestId);
  }

  fs.writeFileSync(path.join(fixtureRoot, "Contracts.pas"), contractSource, "utf8");
  fs.writeFileSync(path.join(fixtureRoot, "Worker.pas"), proposedSource, "utf8");
  fs.writeFileSync(path.join(fixtureRoot, "SemanticMembersSmoke.dpr"), [
    "program SemanticMembersSmoke;",
    "{$APPTYPE CONSOLE}",
    "uses Worker;",
    "var LWorker: TWorker;",
    "begin",
    "  LWorker := TWorker.Create;",
    "  LWorker.Free;",
    "end."
  ].join("\r\n"), "utf8");
  const compilerOutput = compileFixture(delphiVersion, fixtureRoot);
  fs.writeFileSync(path.join(fixtureRoot, "compile.log"), compilerOutput, "utf8");
  console.log(`Delphi ${delphiVersion}: generated members compiled and remained idempotent.`);
}

run().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
