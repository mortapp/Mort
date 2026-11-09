const expectedStages = {
  reviewer_demo: "closed_test",
  closed_test: "closed_test",
  production_candidate: "production_pilot",
  production_prelaunch: "production_public",
  production: "production_public",
};

export function getReleaseStatusError(profile, status) {
  if (!(profile in expectedStages) && !["development", "automated_test"].includes(profile)) {
    return "unknown release profile";
  }
  if (["development", "automated_test"].includes(profile)) return null;
  if (!status || typeof status !== "object" || Array.isArray(status)) {
    return "server release RPC returned malformed data";
  }
  if (status.maintenance_mode === true) return "server maintenance mode is active";

  const expectedStage = expectedStages[profile];
  if (status.release_mode !== expectedStage) {
    return `server release mode is ${status.release_mode ?? "missing"}, expected ${expectedStage}`;
  }
  if (profile === "production_prelaunch") {
    if (status.public_marketplace_enabled !== false) {
      return "server marketplace must remain disabled for production prelaunch";
    }
    if (status.real_document_collection !== false) {
      return "server document collection must remain disabled for production prelaunch";
    }
  }
  if (profile !== "production" && status.public_marketplace_enabled === true) {
    return "non-production build cannot target a public server marketplace";
  }
  if (profile === "production") {
    if (status.public_marketplace_enabled !== true) {
      return "server has not approved public marketplace activation";
    }
    if (status.real_document_collection !== true) {
      return "server has not approved production identity verification";
    }
  }
  return null;
}
