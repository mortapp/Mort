const supportedProductionClient = "flutter";

function expoProductionSupport() {
  return {
    supported: false,
    reason: "reference_only",
  };
}

module.exports = {
  expoProductionSupport,
  supportedProductionClient,
};
