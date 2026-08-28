const path = require("node:path");

module.exports = function mortExpoRouterRootPlugin({ types: t }) {
  const appRoot = path.join(process.cwd(), "app");
  const projectRoot = process.cwd();

  return {
    name: "mort-expo-router-root",
    visitor: {
      MemberExpression(memberPath, state) {
        const node = memberPath.node;
        if (!t.isMemberExpression(node.object)) return;
        if (!t.isIdentifier(node.object.object, { name: "process" })) return;
        if (!t.isIdentifier(node.object.property, { name: "env" })) return;

        const key = memberPath.toComputedKey();
        if (!t.isStringLiteral(key)) return;

        if (key.value === "EXPO_ROUTER_IMPORT_MODE") {
          memberPath.replaceWith(t.stringLiteral("sync"));
          return;
        }

        if (key.value === "EXPO_PROJECT_ROOT") {
          memberPath.replaceWith(t.stringLiteral(projectRoot));
          return;
        }

        if (key.value === "EXPO_ROUTER_ABS_APP_ROOT") {
          memberPath.replaceWith(t.stringLiteral(appRoot));
          return;
        }

        if (key.value === "EXPO_ROUTER_APP_ROOT") {
          const filename = state.filename || state.file.opts.filename || projectRoot;
          let relativeRoot = path.relative(path.dirname(filename), appRoot).replace(/\\/g, "/");
          if (!relativeRoot.startsWith(".")) {
            relativeRoot = `./${relativeRoot}`;
          }
          memberPath.replaceWith(t.stringLiteral(relativeRoot));
        }
      }
    }
  };
};
