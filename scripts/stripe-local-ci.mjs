import { spawnSync } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const settings = {
  api: ["port"], db: ["port", "shadow_port"], "db.pooler": ["port"],
  studio: ["port"], inbucket: ["port", "smtp_port", "pop3_port"],
  analytics: ["port"], edge_runtime: ["inspector_port"],
};
export const portCount = Object.values(settings).flat().length;

export function listen(port = 0) {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.once("error", reject);
    server.listen({ host: "0.0.0.0", port, exclusive: true }, () => resolve(server));
  });
}

export function close(server) {
  return new Promise((resolve, reject) =>
    server.close((error) => error ? reject(error) : resolve()));
}

export async function allocatePorts() {
  const reserved = [];
  try {
    for (let i = 0; i < portCount; i++) reserved.push(await listen());
    return reserved.map((server) => server.address().port);
  } finally {
    await Promise.all(reserved.map(close));
  }
}

export function isolatedConfig(projectId, ports) {
  if (!/^mort-stripe-ci-[a-f0-9]{12}$/.test(projectId) ||
      ports.length !== portCount || new Set(ports).size !== portCount ||
      ports.some((p) => !Number.isInteger(p) || p < 1024 || p > 65535)) {
    throw new Error("Invalid isolated Supabase project ID or ports");
  }
  return (config) => {
    const lines = config.split(/\r?\n/);
    const sectionStart = lines.findIndex((line) => /^\s*\[/.test(line));
    if (sectionStart < 0) throw new Error("No Supabase TOML sections");
    const out = [`project_id = "${projectId}"`,
      ...lines.slice(0, sectionStart).filter((line) => !/^\s*project_id\s*=/.test(line))];
    const seen = new Set();
    const mapped = new Map();
    let i = 0;
    for (const [section, keys] of Object.entries(settings)) {
      mapped.set(section, new Map(keys.map((key) => [key, ports[i++]])));
    }
    let active;
    const appendPorts = () => {
      for (const [key, port] of mapped.get(active) ?? []) out.push(`${key} = ${port}`);
    };
    for (const line of lines.slice(sectionStart)) {
      const table = line.match(/^\s*\[([^\]]+)\]\s*(?:#.*)?$/);
      if (table) {
        appendPorts();
        active = table[1];
        if (mapped.has(active) && seen.has(active)) throw new Error(`Duplicate section [${active}]`);
        seen.add(active);
      }
      const key = line.match(/^\s*([a-z_]+)\s*=/)?.[1];
      if (!mapped.get(active)?.has(key)) out.push(line);
    }
    appendPorts();
    for (const section of mapped.keys()) {
      if (!seen.has(section)) {
        out.push("", `[${section}]`);
        appendMissingSectionPorts(section);
      }
    }
    function appendMissingSectionPorts(section) {
      for (const [key, port] of mapped.get(section)) out.push(`${key} = ${port}`);
    }
    return `${out.join("\n")}\n`;
  };
}

function run(tool, args, env, inherit = false) {
  const result = spawnSync(tool, args, {
    cwd: root, env, encoding: "utf8", maxBuffer: 16 * 1024 * 1024,
    stdio: inherit ? "inherit" : ["ignore", "pipe", "pipe"],
  });
  if (result.error) throw result.error;
  return result;
}

export function localEnvironment(status, ports) {
  const vars = Object.fromEntries(status.split(/\r?\n/).flatMap((line) => {
    const fields = line.match(/^([A-Z0-9_]+)="([^"\r\n]*)"$/);
    return fields ? [[fields[1], fields[2]]] : [];
  }));
  // Check the exact reserved loopback endpoints before allowing tests to run.
  const api = `http://127.0.0.1:${ports[0]}`;
  const db = `postgresql://postgres:postgres@127.0.0.1:${ports[1]}/postgres`;
  if (vars.API_URL !== api || vars.DB_URL !== db || !vars.ANON_KEY || !vars.SERVICE_ROLE_KEY) {
    throw new Error("Supabase status did not return the expected local endpoints and keys");
  }
  return {
    EXPO_PUBLIC_SUPABASE_URL: api, EXPO_PUBLIC_SUPABASE_ANON_KEY: vars.ANON_KEY,
    SUPABASE_DB_URL: db, SUPABASE_SERVICE_ROLE_KEY: vars.SERVICE_ROLE_KEY,
    MORT_QA_LOCAL_SUPABASE: "true", MORT_STRIPE_MODE: "sandbox",
  };
}

async function main() {
  const args = process.argv.slice(2);
  if (args.some((a) => a !== "--occupy-default-db-port") || args.length > 1) {
    throw new Error("Usage: stripe-local-ci.mjs [--occupy-default-db-port]");
  }
  // Do not pass any ambient hosted/provider secrets through to local Supabase or its tests.
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) =>
    !/^(SUPABASE_|EXPO_PUBLIC_SUPABASE_|PLAY_REVIEW_|STRIPE_|MORT_STRIPE_|MORT_QA_|MORT_SUPABASE_|PG)/i.test(key)));
  const blocker = args.length ? await listen(54322).catch((error) => {
    if (error.code !== "EADDRINUSE") throw error;
    console.log("[stripe-local-ci] Default DB port 54322 is already occupied; leaving its owner alone.");
    return null;
  }) : null;
  if (blocker) console.log("[stripe-local-ci] Holding default DB port 54322 for the collision regression.");
  try {
    for (let attempt = 1; attempt <= 3; attempt++) {
      const ports = await allocatePorts();
      const id = `mort-stripe-ci-${randomUUID().replaceAll("-", "").slice(0, 12)}`;
      const workdir = mkdtempSync(join(tmpdir(), `${id}-`));
      const source = join(root, "supabase");
      const dest = join(workdir, "supabase");
      const stack = (command, ...args) =>
        run("supabase", [command, ...args, "--workdir", workdir], env);
      let attemptedStart = false;
      try {
        // Copy only CLI inputs. Never copy local link metadata or recovery archives.
        for (const name of ["config.toml", "functions", "migrations", "seed.sql"]) {
          try {
            cpSync(join(source, name), join(dest, name), {
              recursive: true, filter: (path) => !path.split(sep).some((part) => /^\.env(?:\.|$)/.test(part)),
            });
          } catch (error) {
            if (name !== "seed.sql" || error.code !== "ENOENT") throw error;
          }
        }
        const config = join(dest, "config.toml");
        writeFileSync(config, isolatedConfig(id, ports)(readFileSync(config, "utf8")));
        attemptedStart = true;
        console.log(`[stripe-local-ci] Attempt ${attempt}: ${id}, API ${ports[0]}, DB ${ports[1]}, shadow ${ports[2]}.`);
        const start = stack("start");
        if (start.status !== 0) {
          const output = `${start.stdout}\n${start.stderr}`;
          if (attempt < 3 && /(?:failed to bind|address already in use|port is already allocated)/i.test(output)) {
            console.log("[stripe-local-ci] Bind collision during Docker startup; retrying in a new project on new ports.");
            continue;
          }
          // Do not echo CLI output, which can contain connection credentials.
          throw new Error(`Isolated Supabase start failed (${start.status ?? start.signal})${/address already in use/i.test(output) ? ": bind collision" : ""}.`);
        }
        const reset = stack("db", "reset", "--local");
        if (reset.status !== 0) throw new Error(`Isolated local DB reset failed (${reset.status ?? reset.signal}).`);
        const migrations = stack("migration", "list", "--local");
        if (migrations.status !== 0) throw new Error("Could not list the isolated local migration ledger.");
        const status = stack("status", "-o", "env");
        if (status.status !== 0) throw new Error("Could not read isolated Supabase status.");
        const local = localEnvironment(status.stdout, ports);
        console.log("[stripe-local-ci] Local reset, migration ledger and endpoint guard passed.");
        const result = run("pwsh", ["-NoProfile", "-File", "scripts/run-mort-stripe-regression.ps1",
          "-SkipLocalReset", "-SkipFlutter", "-LocalAuthOnly"], { ...env, ...local }, true);
        if (result.status !== 0) throw new Error(`Local Auth regression failed (${result.status ?? result.signal}).`);
        if (blocker?.address()?.port === 54322) {
          console.log("[stripe-local-ci] Tests completed with the original DB port still occupied.");
        }
        return;
      } finally {
        try {
          if (attemptedStart) {
            const stop = stack("stop", "--no-backup");
            if (stop.status !== 0) throw new Error(`Could not stop isolated Supabase project ${id}; aborting.`);
            console.log(`[stripe-local-ci] Stopped isolated project ${id}.`);
          }
        } finally {
          rmSync(workdir, { recursive: true, force: true });
        }
      }
    }
  } finally {
    if (blocker) await close(blocker);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(`[stripe-local-ci] ${error.message}`);
    process.exitCode = 1;
  });
}
