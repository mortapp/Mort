const sqlstates = new Set([
  "08000",
  "08001",
  "08003",
  "08004",
  "08006",
  "08P01",
  "22P02",
  "22023",
  "23502",
  "23503",
  "23505",
  "28000",
  "28P01",
  "3D000",
  "3F000",
  "40P01",
  "42501",
  "42601",
  "42704",
  "42710",
  "42883",
  "42P01",
  "53300",
  "53400",
  "55P03",
  "57014",
  "57P01",
  "57P02",
  "57P03",
  "58000",
  "58030",
  "P0001",
  "XX000",
]);
const connectionCodes = new Set([
  "ECONNREFUSED",
  "ECONNRESET",
  "ETIMEDOUT",
  "EHOSTUNREACH",
  "ENETUNREACH",
  "EPIPE",
]);
const connectionDeadlines = new Set([
  // Exact fixed messages in the pinned pg 8.22.0 / pg-pool 3.14.0 implementation.
  "Connection terminated due to connection timeout",
  "timeout exceeded when trying to connect",
  "timeout expired",
]);
const failureClasses = new Set([
  "connection_deadline",
  "query_deadline",
  "database_sqlstate",
  "identity_mismatch",
  "connection_error",
  "unclassified",
]);
type StoreInitializationDiagnostic = Readonly<{
  failureClass:
    | "connection_deadline"
    | "query_deadline"
    | "database_sqlstate"
    | "identity_mismatch"
    | "connection_error"
    | "unclassified";
  sqlstate: string;
  elapsedMs: number;
}>;
export class FixtureStoreIdentityMismatch extends Error {
  constructor() {
    super("Fixture store identity mismatch");
  }
}
export class FixtureStoreInitializationError extends Error {
  readonly diagnostic: StoreInitializationDiagnostic;
  constructor(error: unknown, elapsedMs: number) {
    super("Fixture store refused");
    const candidate = error as { message?: unknown; code?: unknown } | null;
    const message = typeof candidate?.message === "string"
      ? candidate.message
      : "";
    const code = typeof candidate?.code === "string" ? candidate.code : "";
    const failureClass = error instanceof FixtureStoreIdentityMismatch
      ? "identity_mismatch"
      : connectionDeadlines.has(message)
      ? "connection_deadline"
      : message === "Query read timeout"
      ? "query_deadline"
      : connectionCodes.has(code)
      ? "connection_error"
      : /^[A-Z0-9]{5}$/.test(code)
      ? "database_sqlstate"
      : "unclassified";
    this.diagnostic = Object.freeze({
      failureClass,
      sqlstate: failureClass === "database_sqlstate"
        ? sqlstates.has(code) ? code : "unclassified"
        : "none",
      elapsedMs: Number.isFinite(elapsedMs) && elapsedMs >= 0 &&
          elapsedMs <= Number.MAX_SAFE_INTEGER
        ? Math.floor(elapsedMs)
        : 0,
    });
    Object.defineProperty(this, "diagnostic", {
      writable: false,
      configurable: false,
    });
  }
}
export function fixtureStoreInitializationLine(
  error: unknown,
): string | undefined {
  if (!(error instanceof FixtureStoreInitializationError)) return undefined;
  const diagnostic = error.diagnostic;
  if (!diagnostic) return undefined;
  const { failureClass, sqlstate, elapsedMs } = diagnostic;
  if (
    !failureClasses.has(failureClass) || !Number.isSafeInteger(elapsedMs) ||
    elapsedMs < 0 ||
    (failureClass === "database_sqlstate"
      ? !sqlstates.has(sqlstate) && sqlstate !== "unclassified"
      : sqlstate !== "none")
  ) return undefined;
  // Reconstruct only the immutable diagnosis, never original error messages,
  // causes, server details, identifiers, query text or connection configuration.
  return `Fixture store initialization failed: class=${failureClass} sqlstate=${sqlstate} elapsedMs=${elapsedMs}`;
}
