import { spawn } from "node:child_process";
import { resolve } from "node:path";

const script = process.argv[2];
if (!script) {
  console.error("Usage: node run-node-qa-with-transport-retry.mjs <script>");
  process.exitCode = 2;
} else {
  const transientTransportFailure =
    /\b(?:ECONNRESET|ETIMEDOUT|EAI_AGAIN|ENETUNREACH|ECONNREFUSED)\b|TypeError: fetch failed|Connect Timeout Error|Connection terminated unexpectedly|UND_ERR_(?:CONNECT_TIMEOUT|SOCKET)/i;
  const maxAttempts = 3;
  const timeoutMs = parsePositiveInteger(
    process.env.MORT_QA_SCRIPT_TIMEOUT_MS,
    180_000,
  );

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const result = await run(resolve(script), timeoutMs);
    if (result.code === 0) {
      process.exitCode = 0;
      break;
    }
    if (!transientTransportFailure.test(result.output) || attempt === maxAttempts) {
      process.exitCode = result.code || 1;
      break;
    }
    const delayMs = attempt * 1000;
    console.log(
      `[qa-transport] RETRY: ${script} hit a transient hosted-network failure ` +
        `(attempt ${attempt}/${maxAttempts}); retrying after ${delayMs} ms.`,
    );
    await new Promise((resolveDelay) => setTimeout(resolveDelay, delayMs));
  }
}

function run(scriptPath, timeoutMs) {
  return new Promise((resolveRun, rejectRun) => {
    const child = spawn(process.execPath, [scriptPath], {
      cwd: process.cwd(),
      env: process.env,
      stdio: ["inherit", "pipe", "pipe"],
      windowsHide: true,
    });
    let output = "";
    let settled = false;
    const forward = (chunk) => {
      const text = chunk.toString();
      output = `${output}${text}`.slice(-131072);
      process.stdout.write(text);
    };
    child.stdout.on("data", forward);
    child.stderr.on("data", forward);
    const timer = setTimeout(() => {
      if (settled) return;
      const timeoutMessage =
        `[qa-transport] FAIL: ${scriptPath} exceeded ${timeoutMs} ms.\n`;
      forward(timeoutMessage);
      child.kill("SIGTERM");
    }, timeoutMs);
    timer.unref();

    child.once("error", (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      rejectRun(error);
    });
    child.once("close", (code, signal) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      const timedOut = output.includes("exceeded") && signal !== null;
      resolveRun({ code: timedOut ? 124 : (code ?? 1), output });
    });
  });
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}
