process.env.EXPO_ROUTER_APP_ROOT = process.env.EXPO_ROUTER_APP_ROOT || "app";

const { getDefaultConfig } = require("expo/metro-config");

module.exports = getDefaultConfig(__dirname);
