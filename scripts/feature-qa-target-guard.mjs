const QA_PROJECT_REF = "ckcxakhxqlkhppsxxjhv";
const QA_API_HOST = `${QA_PROJECT_REF}.supabase.co`;
const QA_DATABASE_HOST = `db.${QA_PROJECT_REF}.supabase.co`;
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "::1"]);

export function isLoopbackHost(hostname) {
  return LOOPBACK_HOSTS.has(hostname.toLowerCase().replace(/^\[|\]$/g, ""));
}

function parseEndpoint(value, label, allowedProtocols) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${label} endpoint is required.`);
  }

  let endpoint;
  try {
    endpoint = new URL(value);
  } catch {
    throw new Error(`${label} endpoint is invalid.`);
  }

  if (!allowedProtocols.includes(endpoint.protocol)) {
    throw new Error(`${label} endpoint protocol is invalid.`);
  }
  return endpoint;
}

export function assertFeatureQaTarget({ projectRef, supabaseUrl, dbUrl, localQa }) {
  if (localQa === true) {
    let api;
    let database;
    try {
      api = parseEndpoint(supabaseUrl, "Supabase API", ["http:", "https:"]);
      database = parseEndpoint(dbUrl, "Postgres", ["postgres:", "postgresql:"]);
    } catch {
      throw new Error("local QA requires loopback API and database endpoints.");
    }
    if (!isLoopbackHost(api.hostname) || !isLoopbackHost(database.hostname)) {
      throw new Error("local QA requires loopback API and database endpoints.");
    }
    return "local_qa";
  }

  if (projectRef !== QA_PROJECT_REF) {
    throw new Error("hosted feature QA requires the isolated QA project.");
  }

  const api = parseEndpoint(supabaseUrl, "Supabase API", ["https:"]);
  if (api.hostname.toLowerCase() !== QA_API_HOST) {
    throw new Error("hosted feature QA requires the isolated QA project.");
  }

  if (dbUrl) {
    const database = parseEndpoint(dbUrl, "Postgres", ["postgres:", "postgresql:"]);
    if (database.hostname.toLowerCase() !== QA_DATABASE_HOST) {
      throw new Error("database host must match the isolated QA project.");
    }
  }

  return "hosted_qa";
}
