#!/usr/bin/env node
/**
 * Browser smoke check for Godot Web export.
 * Opens the exported game in headless Chrome/Chromium and verifies that:
 * 1. The engine downloads, initializes, and reaches window.godotReady().
 * 2. No font/resource loading errors occur (e.g. "ERROR: Failed loading resource"
 *    or "Unrecognized binary resource file").
 *
 * Usage:
 *   node scripts/smoke_check_web.js [dir-or-url] [--timeout <seconds>]
 * Examples:
 *   node scripts/smoke_check_web.js build/web
 *   node scripts/smoke_check_web.js --url https://dustinmichels.github.io/stroad-hero/
 */

const { spawn, execSync } = require("node:child_process");
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".json": "application/json",
  ".css": "text/css; charset=utf-8",
};

function findChromeBinary() {
  if (process.env.CHROME_BIN && fs.existsSync(process.env.CHROME_BIN)) {
    return process.env.CHROME_BIN;
  }

  const candidates = [
    // macOS
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    // Linux / CI runners
    "google-chrome-stable",
    "google-chrome",
    "chromium-browser",
    "chromium",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
  ];

  for (const candidate of candidates) {
    if (candidate.startsWith("/")) {
      if (fs.existsSync(candidate)) return candidate;
    } else {
      try {
        const p = execSync(`which ${candidate}`, { stdio: ["ignore", "pipe", "ignore"] })
          .toString()
          .trim();
        if (p && fs.existsSync(p)) return p;
      } catch {}
    }
  }

  throw new Error("No Chrome/Chromium executable found. Set CHROME_BIN environment variable.");
}

function startStaticServer(directory) {
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      let reqPath = decodeURIComponent(req.url.split("?")[0]);
      if (reqPath === "/") reqPath = "/index.html";
      const filePath = path.join(directory, reqPath);

      if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
        res.writeHead(404, { "Content-Type": "text/plain" });
        res.end("Not Found: " + reqPath);
        return;
      }

      const ext = path.extname(filePath).toLowerCase();
      const contentType = MIME_TYPES[ext] || "application/octet-stream";

      res.writeHead(200, {
        "Content-Type": contentType,
        "Access-Control-Allow-Origin": "*",
      });
      fs.createReadStream(filePath).pipe(res);
    });

    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const port = server.address().port;
      resolve({
        server,
        port,
        url: `http://127.0.0.1:${port}/`,
      });
    });
  });
}

async function runSmokeCheck(targetUrl, timeoutSec = 30) {
  const chromeBin = findChromeBinary();
  console.log(`Using Chrome binary: ${chromeBin}`);
  console.log(`Testing target URL:  ${targetUrl}`);

  const debugPort = 9222 + Math.floor(Math.random() * 500);
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "godot-smoke-"));

  const chromeArgs = [
    "--headless",
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--use-gl=angle",
    "--use-angle=swiftshader",
    "--enable-webgl",
    "--ignore-gpu-blocklist",
    `--remote-debugging-port=${debugPort}`,
    "--remote-allow-origins=*",
    `--user-data-dir=${tmpDir}`,
    "about:blank",
  ];

  const chromeProc = spawn(chromeBin, chromeArgs, { stdio: "ignore" });

  const cleanup = () => {
    try {
      chromeProc.kill();
    } catch {}
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch {}
  };

  try {
    // Wait for Chrome DevTools port to open
    let pageTarget = null;
    const startConnect = Date.now();
    while (Date.now() - startConnect < 10000) {
      try {
        const res = await fetch(`http://127.0.0.1:${debugPort}/json/list`);
        if (res.ok) {
          const list = await res.json();
          pageTarget = list.find((t) => t.type === "page");
          if (pageTarget && pageTarget.webSocketDebuggerUrl) break;
        }
      } catch {}
      await new Promise((r) => setTimeout(r, 100));
    }

    if (!pageTarget || !pageTarget.webSocketDebuggerUrl) {
      throw new Error("Failed to connect to Chrome DevTools Protocol endpoint.");
    }

    const ws = new WebSocket(pageTarget.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.onopen = resolve;
      ws.onerror = reject;
    });

    const fatalErrors = [];
    const allLogs = [];
    let isGodotReady = false;

    const checkTextForErrors = (text) => {
      if (
        text.includes("ERROR: Failed loading resource") ||
        text.includes("Unrecognized binary resource file") ||
        text.includes("Failed to load resource: the server responded with a status of 404")
      ) {
        fatalErrors.push(text);
      }
    };

    await new Promise((resolve, reject) => {
      let timer = null;

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          if (msg.method === "Runtime.consoleAPICalled") {
            const text = msg.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
            allLogs.push(`[${msg.params.type}] ${text}`);
            console.log(`[browser:${msg.params.type}] ${text}`);
            checkTextForErrors(text);

            if (text.includes("[Startup] Godot ready")) {
              isGodotReady = true;
              // Give 1.5 seconds after ready for any lingering asset loads or script errors
              setTimeout(resolve, 1500);
            }
          } else if (msg.method === "Runtime.exceptionThrown") {
            const desc =
              msg.params.exceptionDetails.text +
              " " +
              (msg.params.exceptionDetails.exception?.description || "");
            allLogs.push(`[exception] ${desc}`);
            console.error(`[browser:exception] ${desc}`);
            checkTextForErrors(desc);
          }
        } catch (e) {
          console.error("Error parsing DevTools message:", e);
        }
      };

      ws.onerror = (e) => reject(new Error("WebSocket error: " + e.message));

      // Enable domains and navigate
      ws.send(JSON.stringify({ id: 1, method: "Runtime.enable" }));
      ws.send(JSON.stringify({ id: 2, method: "Page.enable" }));
      ws.send(JSON.stringify({ id: 3, method: "Page.navigate", params: { url: targetUrl } }));

      timer = setTimeout(() => {
        if (!isGodotReady) {
          reject(new Error(`Timeout after ${timeoutSec}s waiting for [Startup] Godot ready.`));
        } else {
          resolve();
        }
      }, timeoutSec * 1000);
    });

    ws.close();

    console.log("\n=== Smoke Check Results ===");
    console.log(`Godot ready: ${isGodotReady ? "YES" : "NO"}`);
    console.log(`Fatal errors found: ${fatalErrors.length}`);

    if (fatalErrors.length > 0) {
      console.error("\nFAIL: Detected fatal resource errors:");
      for (const err of fatalErrors) {
        console.error(` - ${err}`);
      }
      process.exit(1);
    }

    if (!isGodotReady) {
      console.error("\nFAIL: Engine did not reach Godot ready state.");
      process.exit(1);
    }

    console.log("PASS: Game booted cleanly without resource loading errors.\n");
  } finally {
    cleanup();
  }
}

async function main() {
  const args = process.argv.slice(2);
  let target = "build/web";
  let timeoutSec = 30;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--timeout" && args[i + 1]) {
      timeoutSec = parseInt(args[++i], 10);
    } else if (args[i] === "--url" && args[i + 1]) {
      target = args[++i];
    } else if (!args[i].startsWith("-")) {
      target = args[i];
    }
  }

  let serverInfo = null;
  try {
    let testUrl = target;
    if (!target.startsWith("http://") && !target.startsWith("https://")) {
      const resolvedDir = path.resolve(target);
      if (!fs.existsSync(resolvedDir)) {
        console.error(`Error: Directory not found: ${resolvedDir}`);
        process.exit(1);
      }
      console.log(`Starting local static server for ${resolvedDir}...`);
      serverInfo = await startStaticServer(resolvedDir);
      testUrl = serverInfo.url;
    }

    await runSmokeCheck(testUrl, timeoutSec);
  } finally {
    if (serverInfo?.server) {
      serverInfo.server.close();
    }
  }
}

main().catch((err) => {
  console.error("FATAL ERROR:", err.message);
  process.exit(1);
});
