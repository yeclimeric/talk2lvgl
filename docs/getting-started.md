# Getting Started

This guide sets up the environment and runs the built-in demo end to end. Recommended: Ubuntu 22.04/24.04, Linux x86_64.

For an overview of the project itself, see the [README](../README.md). Once the demo works, the [user guide](user-guide.md) walks you through creating your own page task.

## 1. Fetch the runtime dependencies

This repo depends on the upstream `lv_port_linux` worktree as its SDL/LVGL runtime base. If you cloned this repository fresh on a new machine, you need to fetch it first:

```bash
git clone https://github.com/lvgl/lv_port_linux.git lv_port_linux_test
git -C lv_port_linux_test submodule update --init --recursive
```

## 2. Install core dependencies

### Linux (recommended path)

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

### macOS

On macOS, the project is expected to work with the native Homebrew toolchain and the repo-local SDL fallback detection logic. The helper scripts no longer assume a Linux-only `x86_64-linux-gnu` path and automatically detect the platform-specific library directory.

#### Recommended one-click setup

From the repository root:

```bash
./tools/setup-macos.sh
```

This installs the required Homebrew packages, Python dependencies, and the upstream `lv_port_linux_test` checkout, then runs the built-in doctor check and the bundled quickstart demo.

Useful variants:

```bash
./tools/setup-macos.sh --doctor-only
./tools/setup-macos.sh --skip-brew
./tools/setup-macos.sh --skip-quickstart
```

#### Manual setup (if you prefer to do it yourself)

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install cmake pkg-config python@3.12 sdl2 sdl2_image freetype
python3 -m pip install -U "Pillow>=9.1" flask httpx

git clone https://github.com/lvgl/lv_port_linux.git lv_port_linux_test
git -C lv_port_linux_test submodule update --init --recursive
```

#### Apple Silicon vs Intel notes

- Apple Silicon: Homebrew is usually installed under `/opt/homebrew`.
- Intel: Homebrew is usually installed under `/usr/local`.
- The setup script and runtime helpers automatically add the correct prefix to `PATH` and detect the right SDL pkg-config directory.

#### macOS troubleshooting

If `pkg-config` cannot find `SDL2_image`, confirm the issue is not a missing Homebrew install or PATH mismatch:

```bash
which brew
brew --prefix
pkg-config --list-all | grep SDL2_image
pkg-config --modversion sdl2
pkg-config --modversion SDL2_image
```

If the repo still cannot resolve the fallback, inspect the generated log file from the automated installer:

```bash
ls -1 .tmp
```

The log file contains the exact step where the installation or doctor check failed. The helper scripts automatically detect the correct library directory for both `arm64` and `x86_64` Macs.

If the runtime dependency is still missing, re-run the same doctor check:

```bash
python3 tools/doctor.py
```

#### macOS PATH and sanity check

On some machines, the issue is not missing packages but a stale `PATH` or a different Homebrew prefix. Add the correct one before continuing:

```bash
# Apple Silicon
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Intel
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
```

Then verify the toolchain and SDL stack:

```bash
which brew
brew --prefix
which cmake
which pkg-config
which python3
pkg-config --modversion sdl2
pkg-config --modversion SDL2_image
pkg-config --modversion freetype2
```

If `pkg-config` still cannot find SDL libraries, reinstall the relevant formulae and confirm that Homebrew is using the correct prefix:

```bash
brew reinstall sdl2 sdl2_image freetype
brew info sdl2_image
```

The repo's helper scripts also support headless run modes for CI and remote environments:

```bash
bash tools/lvgl-runtime.sh run-headless
bash tools/lvgl-sdl-sim.sh run-headless
```

## 3. Run an environment self-check

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

## 4. Run the built-in quickstart

```bash
tools/pipeline.sh quickstart
```

This command runs the repo's built-in demo task. On success, focus on:

- `workspace/tasks/demo_v1/artifacts/current.png`
- `workspace/tasks/demo_v1/artifacts/diff.png`
- `workspace/tasks/demo_v1/artifacts/report.json`

Notes:

- `quickstart` prefers the repo-provided `reference/reference.png`, so even without a browser screenshot tool installed you can complete the first full loop
- Whether you need a browser for rendering reference images is explained in the notes of the "Build + screenshot + validate" section of the [user guide](user-guide.md)

Once this works, you are ready to create your own tasks.

## Web UI

Besides the command-line pipeline, a browser UI is also provided: drag-and-drop HTML/images and complete generation, validation, and export in one click.

<img width="3034" height="1501" alt="image" src="https://github.com/user-attachments/assets/1e074c06-eb1a-470e-b629-89e6f63d6f0e" />
<img width="1880" height="1604" alt="image" src="https://github.com/user-attachments/assets/6df0e55e-e3e6-45e8-a142-7b69e227b3cb" />

### Startup

```bash
# Python dependencies (first run): flask + httpx + Pillow>=9.1
pip install -U flask httpx "Pillow>=9.1"

python3 tools/webui.py                            # local-only by default: http://127.0.0.1:5000
python3 tools/webui.py --host 0.0.0.0             # expose to LAN http://<host-ip>:5000 (mind security)
python3 tools/webui.py --host 0.0.0.0 --port 8080 # custom port
```

By default it listens on `http://localhost:5000`; adjust with `--host` / `--port`.

### LLM Settings (read this first)

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
