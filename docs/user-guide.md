# User Guide: From HTML or Image to an LVGL Page

The whole workflow is organized around **tasks**. Each task corresponds to one page and holds the input HTML, the generated C code, validation artifacts, and the export bundle.

For environment setup and the built-in demo, see the [getting-started guide](getting-started.md).

## 1. Initialize a task

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

## 2. Put your page content in

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

## 3. Generate LVGL C code

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

The generated code follows the [LLM codegen rules](llm_codegen_rules.md) to guarantee portability.

## 4. Build + screenshot + validate (one command)

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

## 5. Export the delivery bundle

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

## Board Profiles

A board profile defines the target hardware's constraints and lives in the `profiles/` directory:

| Profile | Resolution | Use case |
|---------|--------|------|
| `sim_1280x800.json` | 1280x800 | Desktop simulator development |
| `esp32_480x320.json` | 480x320 | ESP32 embedded board |
| `stm32_800x480.json` | 800x480 | STM32 embedded board |

The profile controls font selection, asset policy, and API constraints during code generation, preventing the generator from relying on desktop-only features. See [board_profiles.md](board_profiles.md) for details.

## Generated Code Rules

LLM-generated page code must follow these constraints (details in [llm_codegen_rules.md](llm_codegen_rules.md)):

- Each page exports two functions: `xxx_page_create()` and `xxx_page_get_content_root()`
- No SDL/simulator-specific APIs
- No hardcoded absolute paths
- Font selection is decided by the board profile
- Asset paths must be relative to the task or the export bundle
- Generated code must pass both visual validation and the portability lint

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

For workspace task pages, `tools/lvgl-runtime.sh` supports deriving the run context automatically from `LVGL_PAGE` alone:

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
