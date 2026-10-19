# Web Loading and Startup Architecture

This document describes the browser startup lifecycle, performance bottlenecks, and the multi-stage progress tracking system used in **Stroad Hero**'s Web export (`web/custom_web_template.html` and `ui/start_screen.gd`).

---

## 1. Overview & Problem Context

When exporting Godot 4.7 to the Web, the game runs via WebAssembly and WebGL2 inside a custom HTML shell (`web/custom_web_template.html`).

In default setups, progress bars hook into `engine.startGame({ onProgress })`. However, `onProgress` **only tracks network byte download** for `.wasm` and `.pck`. Once downloads reach 100%, the browser and Godot engine still have to execute several heavy initialization phases before the game becomes interactive. On mobile devices with slower single-thread performance, this caused the start screen to appear frozen at 100% before suddenly launching.

---

## 2. Complete Startup Lifecycle

The startup sequence is divided into five distinct phases:

| Phase | Stage                                | Responsible Component                        | Estimated Duration (Mobile)  | Observable Status                      |
| ----- | ------------------------------------ | -------------------------------------------- | ---------------------------- | -------------------------------------- |
| **1** | **Asset & Binary Download**          | Browser HTTP fetch                           | Bandwidth-dependent (~10 MB) | `Downloading game assets: X%`          |
| **2** | **WASM Compilation & Instantiation** | Browser JS/WASM engine (V8 / JavaScriptCore) | ~1–3 seconds                 | `Initializing engine...`               |
| **3** | **Engine Runtime & FS Boot**         | Emscripten & Godot core                      | ~200–500 ms                  | `Initializing engine...`               |
| **4** | **Scene Load & Shader Compilation**  | Godot C++ `Main::start()`, WebGL2 driver     | ~1–4 seconds                 | `Compiling shaders & loading world...` |
| **5** | **Warmup & First Frame Settle**      | `StartScreen._ready()` in GDScript           | 2 process frames (~33–66 ms) | `Ready!`                               |

> **Note**: Timing estimates vary significantly across mobile chipsets and thermal states. `web/custom_web_template.html` instruments each transition with `performance.now()` logging to the browser console (`[Startup] Download completed...`, `[Startup] Engine started...`, `[Startup] Godot ready...`) to allow empirical profiling.

### Detailed Breakdown

1. **Asset & Binary Download**:
   - The browser streams `index.wasm` (~39.5 MB uncompressed, ~10 MB gzipped per baseline in `docs/improvements.md`) and `index.pck` (~855 KB).
   - Tracked with byte accuracy via `engine.startGame`'s `onProgress(current, total)`.

2. **WebAssembly Compilation & Instantiation**:
   - Once all bytes are received, the browser compiles WebAssembly bytecode into native machine instructions and allocates WASM linear memory.
   - The browser provides **no incremental progress events** during compilation.

3. **Engine Runtime & Virtual FS**:
   - Emscripten initializes audio (`AudioContext`) and graphics (`WebGL2RenderingContext`), and mounts the `.pck` package into its virtual filesystem.
   - Occurs within the pending `engine.startGame()` Promise.

4. **Scene Deserialization & GPU Shader Compilation**:
   - Godot instantiates `application/run/main_scene` (`res://main.tscn`).
   - Meshes, textures, and collision shapes for the entire environment (strip mall, Cramped Inn, fast food restaurants, vehicles, player) are uploaded to WebGL buffers.
   - WebGL2 compiles and links GLSL ES 3.00 shader programs synchronously on the main thread, which can block execution on mobile GPUs.
5. **Warmup Frames**:
   - `ui/start_screen.gd` waits for 2 `process_frame` ticks to ensure initial render pipelines and materials settle without visual stutter before signaling game readiness.

---

## 3. Staged Progress Bar Architecture

To prevent the UI from freezing at 100% and to keep the user informed during shader and engine compilation, the progress bar in `web/custom_web_template.html` maps the startup sequence to **weighted stages**:

```
0% ──────────── 70% ──────────── 85% ──────────── 95% ──── 100%
  Downloading       Initializing     Compiling        Ready!
  Assets (bytes)    Engine (WASM)    World & Shaders
```

### Allocation Weights & Measurement Reality

Only two phases represent **real, measured events**; the middle segments are **timed synthetic crawls** (`setInterval`) to keep the UI active while waiting on blocking operations:

- **0% – 70% [Measured] (`Downloading game assets: X%`)**:
  Calculated as `Math.floor((current / total) * 70)`. Directly tracks network byte transfer from `onProgress`.
- **70% – 85% [Synthetic Crawl] (`Initializing engine...`)**:
  Begins when download reaches 100%. While awaiting `engine.startGame()` to compile WASM and initialize Emscripten, an interval timer steps from 70% to 85% at ~160ms/step so the progress bar does not appear frozen.
- **85% – 95% [Synthetic Crawl] (`Compiling shaders & loading world...`)**:
  Begins when `engine.startGame().then(...)` resolves. The progress bar stays visible and crawls up to 95% at ~120ms/step while the main scene and shaders initialize.
- **100% [Measured] (`Ready!`)**:
  Triggered when Godot finishes warmup frames and executes `JavaScriptBridge.eval("if (window.godotReady) window.godotReady();")`. The progress bar snaps to 100%, displays `"Ready!"`, pauses 200 ms, and fades out.

---

## 4. JavaScript ↔ Godot Bridge Contract

The HTML shell and GDScript communicate through window-level bridge methods:

### `window.godotReady()`

- **Caller**: `ui/start_screen.gd` (`_mark_loaded()`).
- **Effect**: Clears all crawl timers, snaps the progress bar to 100%, sets text to `"Ready!"`, and schedules `finishStartup()` after a 200 ms confirmation delay.

### `window.godotProgress(pct: number, text?: string)`

- **Status**: Unused forward-compatibility hook.
- **Note**: Because `main.tscn` is currently loaded synchronously as Godot's boot scene, GDScript does not call this hook. If future optimizations switch to a lightweight boot scene that streams the world via `ResourceLoader.load_threaded_request()`, this method can be invoked from GDScript to report real scene loading percentages directly to the shell.

### Safety Fallback Timeout

- In `web/custom_web_template.html`, a fallback timer runs in `.then()`. If `window.godotReady()` is not received within **20 seconds** (e.g., due to an unexpected script error or extreme shader compilation lag on budget mobile chipsets), `finishStartup()` runs automatically so players are not permanently blocked behind the loading overlay.

---

## 5. Web Export Settings Reference

In `export_presets.cfg`:

- `variant/thread_support=false`: Godot runs single-threaded on Web. Required for GitHub Pages deployment without Cross-Origin Isolation headers (`COOP`/`COEP`).
- `html/custom_html_shell="res://web/custom_web_template.html"`: Points to the custom responsive HTML template.
- `vram_texture_compression/for_mobile=false`: Mobile uses standard desktop texture formats unless mobile compression is configured.
