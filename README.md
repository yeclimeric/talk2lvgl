<a id="english"></a>

# LLM-Powered Fully Automated LVGL Code Generator

**English** | [中文](#chinese)

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

---

<a id="chinese"></a>

# LLM驱动的全自动化LVGL代码生成器

[English](#english) | **中文**

这是一个面向 LLM 驱动，基于 LVGL + SDL 的自动化 UI 工作仓库，用于把设计稿、HTML 页面或图像生成成嵌入式 LVGL 代码，并通过模拟器做可视化预览和回归验证。

<img width="1536" height="1024" alt="c117f1b5-d526-4a43-aa65-8082fe4e1efc" src="https://github.com/user-attachments/assets/0324339e-fe5e-4f3e-92c7-41c432db06aa" />


## Web UI

<img width="3751" height="1879" alt="image" src="https://github.com/user-attachments/assets/7c83cfc6-b645-4f31-9b0c-5dcd286fef61" />
<img width="3034" height="1501" alt="image" src="https://github.com/user-attachments/assets/1e074c06-eb1a-470e-b629-89e6f63d6f0e" />
<img width="1880" height="1604" alt="image" src="https://github.com/user-attachments/assets/6df0e55e-e3e6-45e8-a142-7b69e227b3cb" />

除了命令行流水线，还提供了一个浏览器界面，可以拖拽上传 HTML/图片，一键完成生成、校验和导出。

### 启动

```bash
# Python 依赖（首次）：flask + httpx + Pillow>=9.1
pip install -U flask httpx "Pillow>=9.1"

python3 tools/webui.py                            # 默认仅本机访问 http://127.0.0.1:5000
python3 tools/webui.py --host 0.0.0.0             # 开放到局域网 http://<本机IP>:5000（注意安全）
python3 tools/webui.py --host 0.0.0.0 --port 8080 # 自定义端口
```

默认监听 `http://localhost:5000`，可用 `--host` / `--port` 调整。

#### LLM 设置（首次必看）

analyze / generate / refine 等步骤依赖 LLM。在 Web UI 的「LLM 设置」面板填入：

- **API Key**：OpenAI 兼容网关的密钥
- **模型**：如 `gpt-4o`、`gpt-5.5` 等
- **Base URL**：**必须填到 `/v1` 根路径**，例如 `https://api.openai.com/v1` 或 `https://your-gateway/v1`

> 常见坑：Base URL 少了 `/v1` 时，请求会打到网关的网页前端（返回 HTML 而非 JSON），LLM 步骤会静默退化为启发式兜底，或报 `Expecting value: line 1 column 1`。模型名带 `gpt-5.x` / `o1` / `o3` / `o4` / `codex` 会自动走 Responses API（`/responses`），其余走 `/chat/completions`。

### 功能

- 上传 HTML 文件（支持多文件：HTML + CSS/JS/图片）、截图或输入 URL
- 选择 Board Profile 和任务名称
- 一键运行完整流水线（init → generate → lint → build → validate → refine → export）
- 实时日志流和步骤进度指示
- 运行中可随时点击 Stop 按钮终止任务
- 查看三栏对比图（参考 | 当前 | 热力图）和校验报告
- 下载可移植 LVGL 代码包
- LLM 设置（API Key、模型、Base URL）在界面内配置并持久化

## 核心流程

```text
HTML 页面设计                  Board Profile (分辨率/字体/约束)
      │                                │
      └──────────┬─────────────────────┘
                 ▼
         代码生成（规则引擎 / LLM） (generate-page.py)
                 │
                 ▼
         generated/<page>.c/.h
                 │
                 ├── 可移植性检查 (portability-lint.py)
                 │
                 ▼
         CMake 编译 → SDL 模拟器渲染 (headless)
                 │
                 ▼
         截图 (lv_snapshot_take → PNG)
                 │
                 ▼
         像素级 diff 校验 (page-validate.py)
                 │
                 ▼
         report.json (pass/fail) + diff.png (热力图)
                 │
                 ▼
         导出可移植交付包 → 嵌入式固件项目
```

## 3 分钟上手

第一次接触这个仓库，先不要自己建 task，先跑通内置 demo：

### 1. 拉取运行时依赖

这个仓库依赖上游 `lv_port_linux` 工作树作为 SDL/LVGL 运行时底座；如果你是新机器直接 clone 当前仓库，需要先补齐它：

```bash
git clone https://github.com/lvgl/lv_port_linux.git lv_port_linux_test
git -C lv_port_linux_test submodule update --init --recursive
```

### 2. 安装核心依赖

推荐 Ubuntu 22.04/24.04, Linux x86_64。

```bash
# 1) 系统级构建依赖：SDL/FreeType 开发头文件 + 编译工具链
sudo apt update
sudo apt install -y \
  build-essential cmake pkg-config \
  python3 python3-pip python3-pil \
  libsdl2-dev libsdl2-image-dev libfreetype6-dev

# 2) Python 运行时依赖
#    - Pillow：代码用到了 9.1+ 的 Image.Resampling API，而 Ubuntu 22.04 的
#      python3-pil 只有 9.0.1，必须用 pip 升级，否则 image-to-html 会报
#      "module 'PIL.Image' has no attribute 'Resampling'"
#    - httpx：llm_client.py 的依赖，doctor 不检查，必须手动装
pip install -U "Pillow>=9.1" flask httpx
```

### 3. 做一次环境自检

```bash
tools/pipeline.sh doctor
```

`doctor` 会检查：
- `cmake`、`pkg-config`、`python3`
- `Pillow`
- `SDL2` / `SDL2_image` / `FreeType`（包含仓库内置的 `SDL2_image` fallback）
- 是否存在 HTML 参考图渲染工具（`chromium` 或 `wkhtmltoimage`）
- 运行时主工程 `runtime_project/` 能否成功 `cmake configure`

> 说明：`doctor` 只校验 Pillow 是否**存在**，不校验版本；也不会检查 `httpx` / `flask`。请按上一步的 `pip install` 装齐 Python 依赖，否则 analyze / generate / refine 等用到 LLM 的步骤会直接报错。

### 4. 跑内置 quickstart

```bash
tools/pipeline.sh quickstart
```

这条命令会直接跑仓库内置 demo task，成功后重点看：
- `workspace/tasks/demo_v1/artifacts/current.png`
- `workspace/tasks/demo_v1/artifacts/diff.png`
- `workspace/tasks/demo_v1/artifacts/report.json`

说明：
- `quickstart` 优先使用仓库已提供的 `reference/reference.png`，所以即使本机还没装浏览器截图工具，也能先跑通第一条闭环
- 是否需要安装浏览器来渲染参考图，见下文「编译 + 截图 + 校验」一节的注意项

如果这里已经跑通，你再开始创建自己的 task。

## 从 HTML 或图片生成自己的 LVGL 页面

整个流程围绕 **任务 (task)** 组织。每个任务对应一个页面，包含输入 HTML、生成的 C 代码、校验产物和导出包。

### 1. 初始化任务

```bash
tools/pipeline.sh init workspace/tasks/my_page_v1
```

如果你的输入是一张设计稿或页面截图，可以直接初始化图片任务：

```bash
tools/pipeline.sh init workspace/tasks/my_image_page_v1 \
  --source-type image \
  --image /path/to/source.png
```

这会创建任务目录结构和 `task.json` 配置文件：

```text
workspace/tasks/my_page_v1/
├── task.json              # 任务配置（视口、profile、校验阈值等）
├── input/
│   ├── index.html         # HTML 输入，图片任务会先自动生成这个草稿
│   ├── source.png         # 图片任务时的源截图（文件名按原始扩展名变化）
│   ├── assets/            # 页面引用的图片等资源
│   └── notes.md           # 布局备注、约束说明
├── reference/             # 视觉参考图
├── generated/             # LLM 生成的 C 代码（自动填充）
├── artifacts/             # 截图、diff、report（自动生成）
└── export/                # 可移植交付包（自动生成）
```

### 2. 放入页面内容

有两种输入方式：

**方式 A：已有 HTML 文件**

直接复制到任务的 `input/` 目录：

```bash
cp /path/to/your_page.html workspace/tasks/my_page_v1/input/index.html
```

如果 HTML 中引用了图片等资源，一并放到 `input/assets/` 下：

```bash
cp logo.png workspace/tasks/my_page_v1/input/assets/
```

**方式 B：只有一个 URL**

先把页面内容抓取到 `input/index.html`：

```bash
# 简单页面（纯 HTML，无复杂 JS 渲染）
curl -L "https://example.com/your-page" -o workspace/tasks/my_page_v1/input/index.html

# 需要 JS 渲染的 SPA 页面，用浏览器导出：
# 1. 在浏览器中打开目标 URL
# 2. 右键 → 另存为 → 仅 HTML（或 Ctrl+S）
# 3. 将保存的 .html 文件复制到 input/index.html
```

如果页面有需要保留的图片，手动下载到 `input/assets/` 并修改 HTML 中的 `src` 路径为相对路径（如 `assets/logo.png`）。

> 提示：生成器解析 HTML 中的 `h1/h2/h3/p/button/a/img` 等标签，转换为对应的 LVGL 控件。复杂的 CSS 布局和 JS 交互不会被转换，只提取结构和文本内容。

**方式 C：只有一张图片**

如果你初始化的是图片任务：

```bash
tools/pipeline.sh init workspace/tasks/my_image_page_v1 \
  --source-type image \
  --image /path/to/source.png
```

生成前可以先手动看一眼自动草拟的 HTML：

```bash
tools/pipeline.sh draft-html workspace/tasks/my_image_page_v1/task.json
```

说明：
- 这一步会把截图粗略拆成几个视觉区域，再写入 `input/index.html`
- 当前是启发式草稿生成，不是视觉大模型逆向还原
- 产出的 HTML 适合继续人工修改，然后再走现有 `HTML -> LVGL` 流水线
- 图片任务默认把源图本身当作 `reference.image`，不会依赖浏览器渲染 HTML 参考图

### 3. 生成 LVGL C 代码

```bash
tools/pipeline.sh generate workspace/tasks/my_page_v1/task.json
```

生成器读取 `task.json` 中的 profile 配置，并使用：
- HTML 任务：直接读取 `input/index.html`
- 图片任务：先从 `input/source.*` 草拟 `input/index.html`，再继续生成

输出：
- `generated/<page_id>_page.c` — LVGL 页面实现
- `generated/<page_id>_page.h` — 页面头文件
- `generated/manifest.json` — 生成元数据
- `generated/codegen_prompt.md` — 生成时使用的上下文摘要

生成的代码遵循 [LLM 代码生成规则](docs/llm_codegen_rules.md)，确保可移植性。

### 4. 编译 + 截图 + 校验（一键完成）

```bash
tools/pipeline.sh run workspace/tasks/my_page_v1/task.json
```

`run` 命令自动执行完整流水线：
1. 调用 `generate` 生成 C 代码（如果不是 legacy 兼容任务）
2. 运行可移植性检查
3. 编译 → SDL 模拟器渲染 → 截图 → 像素级 diff 校验

当前默认使用单页隔离模式：
- 每个 task 使用独立 build 目录，例如 `runtime_project/build/demo-v1/`
- 当前 task 只注册并编译自己的 generated page，不再把其它 workspace 页面一起编进来
- 这样可以避免“别的页面编译失败影响当前页面运行”

注意（参考图渲染，权威说明）：
- 对于新建的 HTML/URL 任务，默认 `reference.render_from_html = true`，第一次 `run` 需要本机装有下列浏览器之一：`chromium` / `chromium-browser` / `google-chrome` / `wkhtmltoimage`
- 若没有这些工具，可手动放一张 `reference/reference.png`，并把 `render_from_html` 改为 `false`
- 图片任务默认 `render_from_html = false`，直接拿源图当参考图，无需浏览器

校验产物输出到 `artifacts/`：

| 文件 | 说明 |
|------|------|
| `current.png` | viewport 截图 |
| `full.png` | 整页内容截图 |
| `diff.png` | 三栏对比：参考 \| 当前 \| 热力图 |
| `report.json` | 结构化校验报告，含 pass/fail 判定 |

### 5. 导出交付包

```bash
tools/pipeline.sh export workspace/tasks/my_page_v1/task.json
```

将生成的 `.c/.h` 和资源打包到 `export/portable_bundle/`，可直接复制到嵌入式固件项目中使用。

## task.json 配置说明

`task.json` 是每个任务的核心配置，控制生成、校验和导出行为：

```jsonc
{
  "page_id": "demo_page",           // 页面标识，用于生成函数名和文件名
  "page_name": "Demo Page",         // 人类可读名称
  "input": {
    "source_type": "html",
    "html_entry": "input/index.html", // HTML 输入文件或图片任务的草稿输出
    "image_entry": "input/source.png" // 图片任务时的源截图
  },
  "target": {
    "profile": "../../../profiles/sim_1280x800.json",  // 板级 profile
    "viewport": { "width": 1280, "height": 800 },
    "language": "zh-CN"
  },
  "generation": {
    "allow_custom_draw": false,       // 是否允许自定义绘制
    "allow_freetype": false,         // 是否允许 FreeType 运行时字体
    "allow_filesystem_assets": false, // 是否允许文件系统资源加载
    "component_mode": "portable"     // 生成模式：portable = 可移植
  },
  "validation": {
    "max_diff_ratio": 0.18,          // 最大差异像素占比
    "max_mean_abs_diff": 22.0        // 最大平均色差
  },
  "failure_policy": {
    "max_iterations": 8,             // 最大迭代次数
    "stop_on_build_error": true
  }
}
```

完整 schema 见 `workspace/task.schema.json`。

## Board Profile

Board profile 定义目标硬件的约束，位于 `profiles/` 目录：

| Profile | 分辨率 | 用途 |
|---------|--------|------|
| `sim_1280x800.json` | 1280x800 | 桌面模拟器开发 |
| `esp32_480x320.json` | 480x320 | ESP32 嵌入式板 |
| `stm32_800x480.json` | 800x480 | STM32 嵌入式板 |

Profile 控制代码生成时的字体选择、资源策略和 API 约束，防止生成器依赖桌面专有特性。详见 [docs/board_profiles.md](docs/board_profiles.md)。

## 生成代码规范

LLM 生成的页面代码必须遵循以下约束（详见 [docs/llm_codegen_rules.md](docs/llm_codegen_rules.md)）：

- 每个页面导出 `xxx_page_create()` 和 `xxx_page_get_content_root()` 两个函数
- 禁止使用 SDL/模拟器专有 API
- 禁止硬编码绝对路径
- 字体选择由 board profile 决定
- 资源路径必须相对于任务或导出包
- 生成的代码必须同时通过视觉校验和可移植性检查

## 目录结构

```text
llm2lvgl/
├── runtime_project/       # 运行时主工程
│   ├── src/               # main.c, page_registry, token_page, home_page
│   ├── workflow/          # 页面级任务 schema 和配置
│   ├── references/        # 参考图 (PNG)
│   ├── artifacts/         # 截图、diff、report 产物
│   └── assets/            # 图片资源
├── workspace/             # LLM 任务驱动工作区
│   ├── task.schema.json   # 任务定义 schema
│   └── tasks/             # 各任务目录 (demo_v1, web_*, ...)
│       └── <task_id>/     # 每个任务的完整生命周期目录
├── profiles/              # 板级 profile (sim, esp32, stm32)
├── tools/                 # 流水线脚本 (Bash + Python)
├── lv_port_linux_test/    # LVGL v9.6.0-dev + SDL 模拟器（上游）
└── docs/                  # 架构文档、生成规则、部署指南
```

## 工程内部架构

### 分层职责

- **页面层** (`runtime_project/src/`) — 内置示例页面，实现 `xxx_page_create()` 和 `xxx_page_get_content_root()`
- **注册层** (`page_registry.c`) — 内置页面 id → 函数映射，workspace 用户任务通过 `sync-generated-pages.py` 自动注册
- **运行层** (`main.c`) — LVGL + SDL 初始化，通过 `LVGL_PAGE` 环境变量选择页面，支持 viewport 和整页两种截图模式
- **校验层** (`page-validate.py`) — PIL 像素级 diff，输出三栏对比图和结构化 JSON 报告
- **构建层** (`CMakeLists.txt`) — 从 `lv_conf.defaults` 生成配置，按 task 输出独立 `build/<task_id>/lvgl_runtime_demo`

### CMake 依赖

```text
lvgl_runtime_demo (executable)
  ├── src/main.c, page_registry.c, home_page.c, token_page.c,
  │   stitch_smart_home_panel_page.c, image_converter_page.c,
  │   copy_scan_print_setup_page.c  (内置示例页面)
  ├── generated_page_registry.c (workspace 用户任务自动生成)
  └── lvgl (static library) → SDL2, SDL2_image, FreeType, lodepng
```

## 工具脚本一览

| 脚本 | 说明 |
|------|------|
| `tools/doctor.py` | 环境自检，检查依赖、仓库内 SDL2_image fallback、浏览器截图工具和 CMake configure |
| `tools/pipeline.sh` | 任务流水线统一入口（doctor/quickstart/init/draft-html/generate/render-ref/sync/lint/run/export） |
| `tools/image-to-html.py` | 图片 → HTML 草稿 |
| `tools/generate-page.py` | HTML → LVGL C 代码生成 |
| `tools/render-html-ref.py` | HTML 参考图渲染 |
| `tools/page-validate.py` | PIL 像素级 diff 校验器 |
| `tools/portability-lint.py` | 可移植性静态检查 |
| `tools/sync-generated-pages.py` | workspace 任务自动注册桥接 |
| `tools/task-init.py` | 任务目录初始化 |
| `tools/task-run.py` | 任务执行器 |
| `tools/export-page.py` | 页面导出打包 |
| `tools/refine-page.py` | LLM 驱动的视觉迭代优化（search-replace 模式） |
| `tools/llm_client.py` | OpenAI 兼容 API 客户端（streaming、search-replace 解析） |
| `tools/webui.py` | Web UI 启动入口 |
| `tools/web/server.py` | Web UI Flask 后端 |
| `tools/lvgl-runtime.sh` | 主工程编译/运行/截图（底层） |
| `tools/page-flow.sh` | 页面级校验闭环（底层） |

## 手动操作参考

以下命令用于调试或单步执行，日常使用推荐通过 `pipeline.sh` 驱动。

```bash
# 环境自检
tools/pipeline.sh doctor

# 跑内置 demo
tools/pipeline.sh quickstart

# 查看已注册页面
tools/lvgl-runtime.sh list-pages

# GUI 运行（需要桌面环境）
LVGL_PAGE=token tools/lvgl-runtime.sh run

# 运行其他内置示例页面
LVGL_PAGE=stitch_smart_home_panel tools/lvgl-runtime.sh run
LVGL_PAGE=image_converter tools/lvgl-runtime.sh run
LVGL_PAGE=copy_scan_print_setup tools/lvgl-runtime.sh run

# 单独截图
LVGL_PAGE=token tools/lvgl-runtime.sh screenshot output.png

# 单独校验
tools/page-flow.sh validate token
```

注意：`token` 等 legacy 页面（定义在 `runtime_project/src/` 中）不在 workspace 里，因此会走全量编译路径，所有 workspace task 的生成代码也会一起编译。如果某个 workspace task 的代码有编译错误，会导致 legacy 页面也无法编译。遇到这种情况可以先修复或删除出错的 workspace task 生成代码。

对于 workspace task 页面，`tools/lvgl-runtime.sh` 现在支持仅通过 `LVGL_PAGE` 自动推导运行上下文：

```bash
LVGL_PAGE=demo_page tools/lvgl-runtime.sh run
LVGL_PAGE=stitch_smart_home_panel tools/lvgl-runtime.sh screenshot output.png
```

行为说明：
- 自动从 `workspace/tasks/*/task.json` 反查对应的 `page_id`
- 自动推导对应的隔离 build 目录，例如 `runtime_project/build/demo-v1/`
- 如果未显式传入 `LVGL_TASK_JSON`，会自动读取 task 里的 `target.viewport`
- 如果目标二进制尚未构建，会自动执行 `configure + build`

手动传参仍然有效，并且优先级更高：
- `LVGL_TASK_JSON`
- `LVGL_BUILD_DIR`
- `LVGL_VIEWPORT_WIDTH`
- `LVGL_VIEWPORT_HEIGHT`


## 文档索引

| 文档 | 说明 |
|------|------|
| [docs/architecture.md](docs/architecture.md) | 系统架构、执行阶段、Refine 循环与 Web UI |
| [docs/llm_codegen_rules.md](docs/llm_codegen_rules.md) | LLM 代码生成约束规则 |
| [docs/board_profiles.md](docs/board_profiles.md) | Board profile 配置说明 |
| [docs/lvgl-sdl-cross-machine-deployment.md](docs/lvgl-sdl-cross-machine-deployment.md) | 跨机器部署指南 |
