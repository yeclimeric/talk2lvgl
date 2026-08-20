# LLM-Powered Fully Automated LVGL Code Generator

**English** | [中文](README.zh-CN.md)

This is an LLM-driven automated UI workspace based on LVGL + SDL. It turns design mockups, HTML pages, or images into embedded LVGL code, and uses a simulator for visual preview and regression validation.

<img width="1536" height="1024" alt="c117f1b5-d526-4a43-aa65-8082fe4e1efc" src="https://github.com/user-attachments/assets/0324339e-fe5e-4f3e-92c7-41c432db06aa" />

## Highlights

- **HTML / image → LVGL C code** — a rule engine plus LLM generate portable page code for embedded firmware
- **Closed-loop validation** — build → SDL simulator render → screenshot → pixel-level diff against a reference image, with an LLM-driven refine loop
- **Board profiles** — sim (1280x800), ESP32 (480x320), and STM32 (800x480) constraints keep the generated code portable
- **Web UI** — drag-and-drop HTML/images, one-click pipeline, real-time logs, stop anytime, three-column comparison, portable bundle download

## Web UI

<img width="3751" height="1879" alt="image" src="https://github.com/user-attachments/assets/7c83cfc6-b645-4f31-9b0c-5dcd286fef61" />

Besides the command-line pipeline, a browser UI is provided: drag-and-drop HTML/images and complete generation, validation, and export in one click. Startup commands and LLM configuration are covered in the [getting-started guide](docs/getting-started.md#web-ui).

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

## Quick Start

After installing the dependencies ([getting-started guide](docs/getting-started.md)):

```bash
tools/pipeline.sh doctor      # environment self-check
tools/pipeline.sh quickstart  # run the built-in demo task
```

Once the demo passes, the [user guide](docs/user-guide.md) walks you through generating your own page from an HTML file or an image.

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

## Documentation

| Doc | Description |
|------|------|
| [docs/getting-started.md](docs/getting-started.md) | Environment setup, dependency installation, self-check, built-in demo, Web UI configuration |
| [docs/user-guide.md](docs/user-guide.md) | Creating your own task: init → content → generate → validate → export; task.json reference; manual commands |
| [docs/architecture.md](docs/architecture.md) | System architecture, execution stages, the refine loop, and the Web UI |
| [docs/llm_codegen_rules.md](docs/llm_codegen_rules.md) | LLM code generation constraint rules |
| [docs/board_profiles.md](docs/board_profiles.md) | Board profile configuration guide |
| [docs/lvgl-sdl-cross-machine-deployment.md](docs/lvgl-sdl-cross-machine-deployment.md) | Cross-machine deployment guide |

## Acknowledgments

Thanks to the LinuxDo community for the support!
![LinuxDo](https://img.shields.io/badge/LinuxDo-Community_Support-blue)
