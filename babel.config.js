module.exports = function babelConfig(api) {
  api.cache(true);
  return {
    presets: ["babel-preset-expo"],
    plugins: [require("./scripts/babel-expo-router-root"), "react-native-reanimated/plugin"]
  };
};
