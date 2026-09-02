#!/usr/bin/env node

const base = "https://www.matths.kr";
const contact = "dltkddbs4553@matths.kr";
let failed = false;

function fail(message) {
  failed = true;
  console.error(`APPSTORE-LIVE FAIL: ${message}`);
}

async function request(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    return await fetch(`${base}${path}`, {
      redirect: "follow",
      signal: controller.signal,
      ...options,
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function page(path, required) {
  let response;
  try {
    response = await request(path);
  } catch (error) {
    fail(`${path} request failed: ${error.message}`);
    return;
  }
  if (response.status !== 200) {
    fail(`${path} returned HTTP ${response.status}`);
    return;
  }
  if (!response.url.startsWith(`${base}/`)) {
    fail(`${path} redirected outside ${base}: ${response.url}`);
  }
  const body = await response.text();
  for (const text of required) {
    if (!body.includes(text)) fail(`${path} does not contain ${JSON.stringify(text)}`);
  }
}

async function postBoundary(path, expectedStatus) {
  let response;
  try {
    response = await request(path, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
  } catch (error) {
    fail(`${path} request failed: ${error.message}`);
    return;
  }
  if (response.status !== expectedStatus) {
    fail(`${path} returned HTTP ${response.status}; expected ${expectedStatus}`);
  }
}

async function main() {
  await Promise.all([
    page("/privacy", ["iPhone·iPad 앱", contact]),
    page("/terms", ["iPhone·iPad 앱", contact]),
    page("/faq", [contact]),
    page("/intro", [contact]),
    postBoundary("/api/v1/commerce/apple/redeem", 401),
    postBoundary("/api/v1/commerce/apple/notifications", 400),
  ]);

  if (failed) process.exitCode = 1;
  else console.log("APPSTORE-LIVE PASS: policy, support contact, and Apple commerce HTTP boundaries are deployed");
}

main().catch((error) => {
  console.error(`APPSTORE-LIVE FAIL: ${error.message}`);
  process.exitCode = 1;
});
