# Web Build and Deployment Guide (Godot 4.3)

This guide documents how to build, test, and deploy **Stroad Hero** for the web using Godot 4.3.

---

## 1. Architecture & Key Considerations

- **Renderer**: The desktop build uses `Forward Plus`. Web browsers in Godot 4 do not reliably run Forward+; web exports must use the `gl_compatibility` (WebGL 2.0) renderer. Godot supports feature overrides so desktop remains Forward+ while the web export uses Compatibility automatically.
- **Single-Threaded Export (New in Godot 4.3)**:
  - Export with `variant/thread_support = false`.
  - Godot 4.0–4.2 required `SharedArrayBuffer` (multi-threading), requiring strict `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers, which broke GitHub Pages, itch.io embeds, and iOS Safari without service-worker workarounds.
  - Godot 4.3 single-threaded web exports require **no special response headers**, running cleanly as static files on any host (GitHub Pages, itch.io, Netlify, Cloudflare Pages).
- **Editor Safety**:
  - The Godot editor hot-reloads `.gd` scripts, but configuration files (`project.godot`, `export_presets.cfg`) can be overwritten on save if edited externally while the editor is open. Prefer setting these options in the Godot Editor UI or close the editor before modifying config files.
  - Never run `--export-release` or `--export-debug` via the CLI while the Godot editor GUI is open, as export commands trigger an internal import that can corrupt editor cache files in `.godot/`.
- **Preventing Asset Re-import (`.gdignore`)**:
  - If exporting into a subfolder of the project (e.g. `build/web/`), the Godot editor will scan exported PNGs (`index.icon.png`, `index.apple-touch-icon.png`) and create `.import` files. Later exports might package these back into `index.pck`.
  - Place an empty `.gdignore` file inside `build/` (`touch build/.gdignore`) or export to a directory outside the repository root.

---

## 2. Setup & Configuration

### A. Install Godot 4.3 Export Templates

Templates must match your engine version (`4.3.stable`).

- **Via Editor**: Open Godot → **Editor** → **Manage Export Templates...** → click **Download and Install**.
- **Via CLI** (macOS):
  ```bash
  TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/4.3.stable"
  mkdir -p "$TEMPLATES_DIR"
  curl -L -o /tmp/templates.tpz https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
  unzip -q /tmp/templates.tpz "templates/*" -d /tmp/godot_templates
  mv /tmp/godot_templates/templates/* "$TEMPLATES_DIR/"
  rm -rf /tmp/templates.tpz /tmp/godot_templates
  ```

### B. Configure Project Settings (`project.godot`)

In the Godot editor:

1. Open **Project** → **Project Settings...**
2. Enable **Advanced Settings** (top-right toggle).
3. Navigate to **Rendering** → **Renderer**.
4. Keep **Rendering Method** as `forward_plus`.
5. Click the **Add Feature Override** button next to **Rendering Method** (or select **Web**).
6. Set `renderer/rendering_method.web` to `gl_compatibility`.
7. _(Optional)_ Navigate to **Audio** → **General** → set `default_playback_type.web` to `Sample` (`1`) to prevent audio crackling in single-threaded web browsers.

_(If editing `project.godot` while the editor is closed, add:)_

```ini
[rendering]

renderer/rendering_method="forward_plus"
renderer/rendering_method.web="gl_compatibility"
```

### C. Create the Web Export Preset

In the Godot editor:

1. Open **Project** → **Export...**
2. Click **Add...** → select **Web**.
3. Set **Export Path** to `build/web/index.html`.
4. Under the **Options** tab:
   - **Thread Support**: Ensure this is `false` (unchecked).
   - **Extensions Support**: `false` (unchecked; GDExtension is not used).
   - **VRAM Texture Compression**: Keep desktop and mobile enabled.
   - **Canvas Resize Policy**: `Adaptive` (`2`).
   - **Focus Canvas On Start**: `true` (captures keyboard controls immediately).
5. Click **Close**. This writes `export_presets.cfg` at the project root. Commit this file to git.

### D. Ignore Build Output in Godot

Create an empty `.gdignore` file so Godot does not index build outputs:

```bash
mkdir -p build
touch build/.gdignore
```

---

## 3. Building for Web

### Option A: From the Godot Editor (Recommended during local work)

1. Open **Project** → **Export...**
2. Select **Web**.
3. Click **Export Project...**
4. Set path to `build/web/index.html` (uncheck _Export With Debug_ for production builds).
5. Click **Save**.
6. _(Quick Test)_: Click the browser icon next to the "Play Scene" button in the top-right toolbar to launch Godot's built-in local web server and open your default browser.

### Option B: From the CLI (Only with Godot Editor Closed)

```bash
mkdir -p build/web
touch build/.gdignore
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" build/web/index.html
```

---

## 4. Local Testing

Browsers block WebAssembly and PCK asset loading over `file://` URLs due to CORS restrictions. Always test through a local HTTP server:

```bash
# Using Python 3
python3 -m http.server 8080 --directory build/web

# Or using npx
npx serve build/web
```

Visit `http://localhost:8080` in your web browser.

---

## 5. Deployment Pipelines

### Option A: GitHub Pages via GitHub Actions (Automated)

#### Step 1: Set Up Remote Repository

If your local git repository does not yet have a remote configured:

```bash
git remote add origin https://github.com/<your-username>/<your-repo-name>.git
git branch -M main
git push -u origin main
```

#### Step 2: Add GitHub Actions Workflow

Create `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy Web to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-24.04
    container:
      image: barichello/godot-ci:4.3
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          lfs: true

      - name: Setup Export Templates
        run: |
          mkdir -v -p ~/.local/share/godot/export_templates/
          mv /root/.local/share/godot/export_templates/4.3.stable ~/.local/share/godot/export_templates/4.3.stable

      - name: Build Web
        run: |
          mkdir -v -p build/web
          touch build/.gdignore
          godot --headless --verbose --export-release "Web" build/web/index.html

      - name: Upload Artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

#### Step 3: Enable GitHub Pages

In your repository on GitHub:

1. Go to **Settings** → **Pages**.
2. Under **Build and deployment** → **Source**, select **GitHub Actions**.

### Option B: Itch.io (via Butler CLI)

1. Compress the export folder:
   ```bash
   cd build/web && zip -r ../../stroad-hero-web.zip . && cd ../..
   ```
2. Upload using itch.io's `butler`:
   ```bash
   butler push stroad-hero-web.zip <username>/stroad-hero:web
   ```
3. In the itch.io dashboard for your game:
   - Set **Kind of project** to **HTML**.
   - Check **This file will be played in the browser**.
   - Embed options: Set dimensions (e.g., `1280 x 720` or viewport adaptive) and enable fullscreen button.
   - _SharedArrayBuffer support_: Leave unchecked (single-threaded build does not require it).

### Option C: Cloudflare Pages / Netlify / Vercel

- Upload or link git repository.
- Publish directory: `build/web`.
- No special HTTP headers or server runtime needed.

---

## 6. Verification Checklist

- [ ] Compatibility renderer verification: launch the game in non-headless mode or browser to verify visual fidelity (sky, lighting, shadows, and `grass.gdshader`).
- [ ] Keyboard input: ensure arrow keys, Spacebar (`jump`), and `C` (`character_editor`) respond without causing the browser page to scroll.
- [ ] Audio autoplay: verify audio initiates after the first user click/interaction on the canvas.
- [ ] `.gdignore` is present in `build/` so exported PNGs are not tracked by Godot's asset importer.
