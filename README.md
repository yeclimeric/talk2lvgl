# LLM-Powered Fully Automated LVGL Code Generator

**English** | [中文](README.zh-CN.md)

This is an LLM-driven automated UI workspace based on LVGL + SDL. It turns design mockups, HTML pages, or images into embedded LVGL code, and uses a simulator for visual preview and regression validation.

<img width="1536" height="1024" alt="c117f1b5-d526-4a43-aa65-8082fe4e1efc" src="https://github.com/user-attachments/assets/0324339e-fe5e-4f3e-92c7-41c432db06aa" />


## Web UI

<img width="3751" height="1879" alt="image" src="https://github.com/user-attachments/assets/7c83cfc6-b645-4f31-9b0c-5dcd286fef61" />
<img width="3034" height="1501" alt="image" src="https://github.com/user-attachments/assets/1e074c06-eb1a-470e-b629-89e6f63d6f0e" />
<img width="1880" height="1604" alt="image" src="https://github.com/user-attachments/assets/6df0e55e-e3e6-45e8-a142-7b69e227b3cb" />

Besides the command-line pipeline, a browser UI is also provided: drag-and-drop HTML/images and complete generation, validation, and export in one click.

### Startup

```bash
# Python dependencies (first run): flask + httpx + Pillow>=9.1
pip install -U flask httpx "Pillow>=9.1"

python3 tools/webui.py                            # local-only by default: http://127.0.0.1:5000
python3 tools/webui.py --host 0.0.0.0             # expose to LAN http://<host-ip>:5000 (mind security)
python3 tools/webui.py --host 0.0.0.0 --port 8080 # custom port
```

By default it listens on `http://localhost:5000`; adjust with `--host` / `--port`.

#### LLM Settings (read this first)

Steps such as analyze / generate / refine rely on an LLM. In the Web UI's "LLM Settings" panel, fill in:

- **API Key**: the key of an OpenAI-compatible gateway
- **Model**: e.g. `gpt-4o`, `gpt-5.5`, etc.
- **Base URL**: **must point to the `/v1` root path**, e.g. `https://api.openai.com/v1` or `https://your-gateway/v1`

> Common pitfall: when the Base URL is missing `/v1`, requests hit the gateway's web frontend (which returns HTML instead of JSON), so LLM steps silently degrade to heuristic fallbacks, or you get `Expecting value: line 1 column 1`. Model names containing `gpt-5.x` / `o1` / `o3` / `o4` / `codex` automatically use the Responses API (`/responses`); all others use `/chat/completions`.

### Features

- Upload HTML files (multi-file supported: HTML + CSS/JS/images), screenshots, or enter a URL
- Choose a Board Profile and a task name
- Run the full pipeline with one click (init → generate → lint → build → validate → refine → export)
- Real-time log streaming and step-by-step progress indicator
- Stop button to terminate a task at any time while it runs
- Three-column comparison (reference | current | heatmap) plus the validation report
- Download the portable LVGL code bundle
- LLM settings (API Key, model, Base URL) are configured and persisted inside the UI

## Core Pipeline

```text
HTML page design                Board Profile (resolution/fonts/constraints)
      │                                │
      └──────────┬─────────────────────┘
                 ▼
         Code generation (rule engine / LLM) (generate-page.py)
                 │
                 ▼
         generated/<page>.c/.h
                 │
                 ├── Portability lint (portability-lint.py)
                 │
                 ▼
         CMake build → SDL simulator render (headless)
                 │
                 ▼
         Screenshot (lv_snapshot_take → PNG)
                 │
                 ▼
         Pixel-level diff validation (page-validate.py)
                 │
                 ▼
         report.json (pass/fail) + diff.png (heatmap)
                 │
                 ▼
         Export portable bundle → embedded firmware project
```

## 3-Minute Quickstart

New to this repo? Don't create your own task yet — get the built-in demo running first:

### 1. Fetch the runtime dependencies

This repo depends on the upstream `lv_port_linux` worktree as its SDL/LVGL runtime base. If you cloned this repository fresh on a new machine, you need to fetch it first:

```bash
git clone https://github.com/lvgl/lv_port_linux.git lv_port_linux_test
git -C lv_port_linux_test submodule update --init --recursive
```

### 2. Install core dependencies

Recommended: Ubuntu 22.04/24.04, Linux x86_64.

```bash
# 1) System-level build dependencies: SDL/FreeType dev headers + toolchain
sudo apt update
sudo apt install -y \
  build-essential cmake pkg-config \
  python3 python3-pip python3-pil \
  libsdl2-dev libsdl2-image-dev libfreetype6-dev

# 2) Python runtime dependencies
#    - Pillow: the code uses the Image.Resampling API introduced in 9.1, but
#      Ubuntu 22.04's python3-pil is only 9.0.1 — you must upgrade via pip,
#      otherwise image-to-html fails with
#      "module 'PIL.Image' has no attribute 'Resampling'"
#    - httpx: dependency of llm_client.py; doctor does not check it — install it manually
pip install -U "Pillow>=9.1" flask httpx
```

### 3. Run an environment self-check

```bash
tools/pipeline.sh doctor
```

`doctor` checks:
- `cmake`, `pkg-config`, `python3`
- `Pillow`
- `SDL2` / `SDL2_image` / `FreeType` (including the repo's built-in `SDL2_image` fallback)
- whether a tool for rendering HTML reference images exists (`chromium` or `wkhtmltoimage`)
- whether the main runtime project `runtime_project/` can `cmake configure` successfully

> Note: `doctor` only verifies that Pillow **exists**, not its version, and it does not check `httpx` / `flask` either. Install the Python dependencies as shown in the previous step, otherwise LLM-dependent steps such as analyze / generate / refine will fail outright.

### 4. Run the built-in quickstart

```bash
tools/pipeline.sh quickstart
```

This command runs the repo's built-in demo task. On success, focus on:
- `workspace/tasks/demo_v1/artifacts/current.png`
- `workspace/tasks/demo_v1/artifacts/diff.png`
- `workspace/tasks/demo_v1/artifacts/report.json`

Notes:
- `quickstart` prefers the repo-provided `reference/reference.png`, so even without a browser screenshot tool installed you can complete the first full loop
- Whether you need a browser for rendering reference images is explained in the notes of the "Build + screenshot + validate" section below

Once this works, you are ready to create your own tasks.

## Generate Your Own LVGL Page from HTML or an Image

The whole workflow is organized around **tasks**. Each task corresponds to one page and holds the input HTML, the generated C code, validation artifacts, and the export bundle.

### 1. Initialize a task

```bash
tools/pipeline.sh init workspace/tasks/my_page_v1
```

If your input is a design mockup or a page screenshot, you can initialize an image task directly:

```bash
tools/pipeline.sh init workspace/tasks/my_image_page_v1 \
  --source-type image \
  --image /path/to/source.png
```

This creates the task directory structure and the `task.json` config file:

```text
workspace/tasks/my_page_v1/
├── task.json              # task config (viewport, profile, validation thresholds, etc.)
├── input/
│   ├── index.html         # HTML input; image tasks auto-generate this draft first
│   ├── source.png         # source screenshot for image tasks (filename follows the original extension)
│   ├── assets/            # images and other assets referenced by the page
│   └── notes.md           # layout notes, constraint notes
├── reference/             # visual reference image
├── generated/             # LLM-generated C code (auto-filled)
├── artifacts/             # screenshots, diff, report (auto-generated)
└── export/                # portable delivery bundle (auto-generated)
```

### 2. Put your page content in

There are three input methods:

**Option A: you already have an HTML file**

Copy it into the task's `input/` directory:

```bash
cp /path/to/your_page.html workspace/tasks/my_page_v1/input/index.html
```

If the HTML references images or other assets, put them under `input/assets/` as well:

```bash
cp logo.png workspace/tasks/my_page_v1/input/assets/
```

**Option B: you only have a URL**

Fetch the page content into `input/index.html` first:

```bash
# Simple pages (plain HTML, no heavy JS rendering)
curl -L "https://example.com/your-page" -o workspace/tasks/my_page_v1/input/index.html

# SPA pages that need JS rendering — export from a browser:
# 1. Open the target URL in a browser
# 2. Right-click → Save as → HTML only (or Ctrl+S)
# 3. Copy the saved .html file to input/index.html
```

If the page contains images you want to keep, download them into `input/assets/` manually and change the `src` paths in the HTML to relative paths (e.g. `assets/logo.png`).

> Tip: the generator parses tags like `h1/h2/h3/p/button/a/img` in the HTML and maps them to LVGL widgets. Complex CSS layouts and JS interactions are not converted — only structure and text content are extracted.

**Option C: you only have an image**

If you initialized an image task:

```bash
tools/pipeline.sh init workspace/tasks/my_image_page_v1 \
  --source-type image \
  --image /path/to/source.png
```

Before generating, you can take a manual look at the auto-drafted HTML:

```bash
tools/pipeline.sh draft-html workspace/tasks/my_image_page_v1/task.json
```

Notes:
- This step roughly splits the screenshot into several visual regions and writes `input/index.html`
- It is heuristic draft generation for now, not vision-model reverse restoration
- The produced HTML is meant to be hand-tuned further, then fed into the existing `HTML -> LVGL` pipeline
- Image tasks use the source image itself as `reference.image` by default and do not rely on a browser to render the HTML reference

### 3. Generate LVGL C code

```bash
tools/pipeline.sh generate workspace/tasks/my_page_v1/task.json
```

The generator reads the profile config in `task.json` and uses:
- HTML tasks: reads `input/index.html` directly
- Image tasks: first drafts `input/index.html` from `input/source.*`, then continues generation

Outputs:
- `generated/<page_id>_page.c` — LVGL page implementation
- `generated/<page_id>_page.h` — page header file
- `generated/manifest.json` — generation metadata
- `generated/codegen_prompt.md` — context summary used at generation time

The generated code follows the [LLM codegen rules](docs/llm_codegen_rules.md) to guarantee portability.

### 4. Build + screenshot + validate (one command)

```bash
tools/pipeline.sh run workspace/tasks/my_page_v1/task.json
```

The `run` command executes the full pipeline automatically:
1. Calls `generate` to produce the C code (unless it is a legacy-compat task)
2. Runs the portability lint
3. Builds → renders in the SDL simulator → takes a screenshot → runs pixel-level diff validation

The default mode is per-page isolation:
- Each task uses its own build directory, e.g. `runtime_project/build/demo-v1/`
- Only the current task's generated page is registered and compiled — other workspace pages are no longer compiled in
- This prevents "another page's compile error breaking the current page's run"

Notes (reference image rendering — authoritative):
- For newly created HTML/URL tasks, `reference.render_from_html = true` by default; the first `run` requires one of these browsers installed locally: `chromium` / `chromium-browser` / `google-chrome` / `wkhtmltoimage`
- Without any of these tools, you can manually place a `reference/reference.png` and set `render_from_html` to `false`
- Image tasks default to `render_from_html = false` and use the source image as the reference directly — no browser needed

Validation artifacts are written to `artifacts/`:

| File | Description |
|------|------|
| `current.png` | viewport screenshot |
| `full.png` | full-page content screenshot |
| `diff.png` | three-column comparison: reference \| current \| heatmap |
| `report.json` | structured validation report with the pass/fail verdict |

### 5. Export the delivery bundle

```bash
tools/pipeline.sh export workspace/tasks/my_page_v1/task.json
```

Packages the generated `.c/.h` files and assets into `export/portable_bundle/`, ready to be copied into an embedded firmware project.

## task.json Configuration

`task.json` is the core config of each task; it controls generation, validation, and export behavior:

```jsonc
{
  "page_id": "demo_page",           // page identifier, used for function and file names
  "page_name": "Demo Page",         // human-readable name
  "input": {
    "source_type": "html",
    "html_entry": "input/index.html", // HTML input file, or the drafted output for image tasks
    "image_entry": "input/source.png" // source screenshot for image tasks
  },
  "target": {
    "profile": "../../../profiles/sim_1280x800.json",  // board profile
    "viewport": { "width": 1280, "height": 800 },
    "language": "zh-CN"
  },
  "generation": {
    "allow_custom_draw": false,       // allow custom drawing
    "allow_freetype": false,         // allow FreeType runtime fonts
    "allow_filesystem_assets": false, // allow loading assets from the filesystem
    "component_mode": "portable"     // generation mode: portable = portable
  },
  "validation": {
    "max_diff_ratio": 0.18,          // max ratio of differing pixels
    "max_mean_abs_diff": 22.0        // max mean color difference
  },
  "failure_policy": {
    "max_iterations": 8,             // max refinement iterations
    "stop_on_build_error": true
  }
}
```

The full schema lives in `workspace/task.schema.json`.

## Board Profile

A board profile defines the target hardware's constraints and lives in the `profiles/` directory:

| Profile | Resolution | Use case |
|---------|--------|------|
| `sim_1280x800.json` | 1280x800 | Desktop simulator development |
| `esp32_480x320.json` | 480x320 | ESP32 embedded board |
| `stm32_800x480.json` | 800x480 | STM32 embedded board |

The profile controls font selection, asset policy, and API constraints during code generation, preventing the generator from relying on desktop-only features. See [docs/board_profiles.md](docs/board_profiles.md) for details.

## Generated Code Rules

LLM-generated page code must follow these constraints (details in [docs/llm_codegen_rules.md](docs/llm_codegen_rules.md)):

- Each page exports two functions: `xxx_page_create()` and `xxx_page_get_content_root()`
- No SDL/simulator-specific APIs
- No hardcoded absolute paths
- Font selection is decided by the board profile
- Asset paths must be relative to the task or the export bundle
- Generated code must pass both visual validation and the portability lint

## Directory Layout

```text
llm2lvgl/
├── runtime_project/       # main runtime project
│   ├── src/               # main.c, page_registry, token_page, home_page
│   ├── workflow/          # page-level task schema and configs
│   ├── references/        # reference images (PNG)
│   ├── artifacts/         # screenshots, diff, report artifacts
│   └── assets/            # image assets
├── workspace/             # LLM task-driven workspace
│   ├── task.schema.json   # task definition schema
│   └── tasks/             # task directories (demo_v1, web_*, ...)
│       └── <task_id>/     # full lifecycle directory of each task
├── profiles/              # board profiles (sim, esp32, stm32)
├── tools/                 # pipeline scripts (Bash + Python)
├── lv_port_linux_test/    # LVGL v9.6.0-dev + SDL simulator (upstream)
└── docs/                  # architecture docs, codegen rules, deployment guide
```

## Internal Architecture

### Layered responsibilities

- **Page layer** (`runtime_project/src/`) — built-in example pages implementing `xxx_page_create()` and `xxx_page_get_content_root()`
- **Registry layer** (`page_registry.c`) — built-in page id → function mapping; workspace user tasks are registered automatically via `sync-generated-pages.py`
- **Runtime layer** (`main.c`) — LVGL + SDL initialization; selects the page via the `LVGL_PAGE` environment variable; supports both viewport and full-page screenshot modes
- **Validation layer** (`page-validate.py`) — PIL pixel-level diff; produces the three-column comparison and a structured JSON report
- **Build layer** (`CMakeLists.txt`) — generates the config from `lv_conf.defaults` and outputs an isolated `build/<task_id>/lvgl_runtime_demo` per task

### CMake dependencies

```text
lvgl_runtime_demo (executable)
  ├── src/main.c, page_registry.c, home_page.c, token_page.c,
  │   stitch_smart_home_panel_page.c, image_converter_page.c,
  │   copy_scan_print_setup_page.c  (built-in example pages)
  ├── generated_page_registry.c (auto-generated for workspace user tasks)
  └── lvgl (static library) → SDL2, SDL2_image, FreeType, lodepng
```

## Tool Scripts Overview

| Script | Description |
|------|------|
| `tools/doctor.py` | Environment self-check: dependencies, the in-repo SDL2_image fallback, browser screenshot tools, and CMake configure |
| `tools/pipeline.sh` | Unified task pipeline entry (doctor/quickstart/init/draft-html/generate/render-ref/sync/lint/run/export) |
| `tools/image-to-html.py` | Image → HTML draft |
| `tools/generate-page.py` | HTML → LVGL C code generation |
| `tools/render-html-ref.py` | HTML reference image rendering |
| `tools/page-validate.py` | PIL pixel-level diff validator |
| `tools/portability-lint.py` | Portability static lint |
| `tools/sync-generated-pages.py` | Auto-registration bridge for workspace tasks |
| `tools/task-init.py` | Task directory initialization |
| `tools/task-run.py` | Task executor |
| `tools/export-page.py` | Page export and packaging |
| `tools/refine-page.py` | LLM-driven visual refinement loop (search-replace mode) |
| `tools/llm_client.py` | OpenAI-compatible API client (streaming, search-replace parsing) |
| `tools/webui.py` | Web UI launcher |
| `tools/web/server.py` | Web UI Flask backend |
| `tools/lvgl-runtime.sh` | Main project build/run/screenshot (low level) |
| `tools/page-flow.sh` | Page-level validation loop (low level) |

## Manual Operations Reference

These commands are for debugging or single-step execution; for daily use, prefer driving things through `pipeline.sh`.

```bash
# Environment self-check
tools/pipeline.sh doctor

# Run the built-in demo
tools/pipeline.sh quickstart

# List registered pages
tools/lvgl-runtime.sh list-pages

# GUI run (requires a desktop environment)
LVGL_PAGE=token tools/lvgl-runtime.sh run

# Run other built-in example pages
LVGL_PAGE=stitch_smart_home_panel tools/lvgl-runtime.sh run
LVGL_PAGE=image_converter tools/lvgl-runtime.sh run
LVGL_PAGE=copy_scan_print_setup tools/lvgl-runtime.sh run

# Standalone screenshot
LVGL_PAGE=token tools/lvgl-runtime.sh screenshot output.png

# Standalone validation
tools/page-flow.sh validate token
```

Note: legacy pages like `token` (defined in `runtime_project/src/`) are not in the workspace, so they go through the full-build path — the generated code of all workspace tasks gets compiled together. If some workspace task's code has compile errors, legacy pages fail to build too. In that case, fix or delete the broken workspace task's generated code first.

For workspace task pages, `tools/lvgl-runtime.sh` now supports deriving the run context automatically from `LVGL_PAGE` alone:

```bash
LVGL_PAGE=demo_page tools/lvgl-runtime.sh run
LVGL_PAGE=stitch_smart_home_panel tools/lvgl-runtime.sh screenshot output.png
```

Behavior notes:
- Looks up the matching `page_id` from `workspace/tasks/*/task.json` automatically
- Derives the isolated build directory automatically, e.g. `runtime_project/build/demo-v1/`
- If `LVGL_TASK_JSON` is not passed explicitly, the task's `target.viewport` is read automatically
- If the target binary has not been built yet, `configure + build` runs automatically

Manual parameters still work and take priority:
- `LVGL_TASK_JSON`
- `LVGL_BUILD_DIR`
- `LVGL_VIEWPORT_WIDTH`
- `LVGL_VIEWPORT_HEIGHT`


## Documentation Index

| Doc | Description |
|------|------|
| [docs/architecture.md](docs/architecture.md) | System architecture, execution stages, the refine loop, and the Web UI |
| [docs/llm_codegen_rules.md](docs/llm_codegen_rules.md) | LLM code generation constraint rules |
| [docs/board_profiles.md](docs/board_profiles.md) | Board profile configuration guide |
| [docs/lvgl-sdl-cross-machine-deployment.md](docs/lvgl-sdl-cross-machine-deployment.md) | Cross-machine deployment guide |
