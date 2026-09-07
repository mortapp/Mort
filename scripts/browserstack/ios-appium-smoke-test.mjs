// Minimal real-device smoke test: launches the uploaded MORT iOS QA build on
// a real BrowserStack iPhone, confirms the session stays alive (no crash on
// launch), captures a screenshot as evidence, and ends the session cleanly.
//
// This is deliberately narrow in scope -- a launch/no-crash check, not the
// full flow-by-flow QA matrix. Driving specific screens (auth, onboarding,
// marketplace, etc.) via Appium element-finding needs semantics/accessibility
// identifiers wired up consistently across those screens first; that is real
// follow-up engineering work, not something to fake here.
//
// Required env vars: BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY,
// BROWSERSTACK_APP_URL (the bs://<id> from the upload step),
// BS_DEVICE_NAME, BS_OS_VERSION (from list-ios-devices.ps1's real output).

import { remote } from "webdriverio";
import { writeFile } from "node:fs/promises";

const required = [
  "BROWSERSTACK_USERNAME",
  "BROWSERSTACK_ACCESS_KEY",
  "BROWSERSTACK_APP_URL",
  "BS_DEVICE_NAME",
  "BS_OS_VERSION",
];
for (const name of required) {
  if (!process.env[name]) {
    console.error(`Missing required env var: ${name}`);
    process.exit(1);
  }
}

const opts = {
  path: "/wd/hub",
  hostname: "hub.browserstack.com",
  port: 443,
  protocol: "https",
  user: process.env.BROWSERSTACK_USERNAME,
  key: process.env.BROWSERSTACK_ACCESS_KEY,
  logLevel: "warn",
  capabilities: {
    platformName: "iOS",
    "appium:automationName": "XCUITest",
    "appium:app": process.env.BROWSERSTACK_APP_URL,
    "appium:deviceName": process.env.BS_DEVICE_NAME,
    "appium:osVersion": process.env.BS_OS_VERSION,
    "appium:autoAcceptAlerts": true,
    "bstack:options": {
      projectName: "MORT",
      buildName: `mort-ios-qa-${process.env.GITHUB_SHA ?? "local"}`,
      sessionName: `launch-smoke-${process.env.BS_DEVICE_NAME}-${process.env.BS_OS_VERSION}`,
    },
  },
};

async function main() {
  console.log(
    `Starting BrowserStack session: device="${process.env.BS_DEVICE_NAME}" iOS ${process.env.BS_OS_VERSION}`,
  );
  const driver = await remote(opts);
  const sessionId = driver.sessionId;
  console.log(`BROWSERSTACK_SESSION_ID=${sessionId}`);
  console.log(
    `BROWSERSTACK_SESSION_URL=https://app-automate.browserstack.com/dashboard/v2/sessions/${sessionId}`,
  );

  try {
    // Give the app time to finish launching before checking it's alive.
    await driver.pause(8000);

    // A session that can still report window/page source is a session whose
    // app process did not crash on launch. This is a real, if narrow, signal
    // -- not a simulated result.
    const source = await driver.getPageSource();
    const stillAlive = typeof source === "string" && source.length > 0;
    console.log(`APP_ALIVE_AFTER_LAUNCH=${stillAlive}`);

    const screenshot = await driver.takeScreenshot();
    await writeFile(
      "browserstack-launch-screenshot.png",
      Buffer.from(screenshot, "base64"),
    );
    console.log("Saved browserstack-launch-screenshot.png");

    if (!stillAlive) {
      throw new Error("App did not report a live page source after launch.");
    }
    console.log("RESULT=PASS");
  } catch (error) {
    console.error("RESULT=FAIL");
    console.error(error);
    process.exitCode = 1;
  } finally {
    await driver.deleteSession();
  }
}

main();
