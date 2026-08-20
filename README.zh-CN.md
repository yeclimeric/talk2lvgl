# LLM驱动的全自动化LVGL代码生成器

[English](README.md) | **中文**

这是一个面向 LLM 驱动，基于 LVGL + SDL 的自动化 UI 工作仓库，用于把设计稿、HTML 页面或图像生成成嵌入式 LVGL 代码，并通过模拟器做可视化预览和回归验证。

<img width="1536" height="1024" alt="c117f1b5-d526-4a43-aa65-8082fe4e1efc" src="https://github.com/user-attachments/assets/0324339e-fe5e-4f3e-92c7-41c432db06aa" />

## 特性亮点

- **HTML / 图片 → LVGL C 代码** — 规则引擎 + LLM 生成可移植的页面代码，直接用于嵌入式固件
- **闭环校验** — 编译 → SDL 模拟器渲染 → 截图 → 与参考图像素级 diff，配合 LLM 驱动的 refine 迭代
- **板级 Profile** — sim (1280x800)、ESP32 (480x320)、STM32 (800x480) 约束，保证生成代码可移植
- **Web UI** — 拖拽上传 HTML/图片，一键流水线，实时日志，随时 Stop，三栏对比图，可移植代码包下载

## Web UI

<img width="3751" height="1879" alt="image" src="https://github.com/user-attachments/assets/7c83cfc6-b645-4f31-9b0c-5dcd286fef61" />

除了命令行流水线，还提供了一个浏览器界面，可以拖拽上传 HTML/图片，一键完成生成、校验和导出。启动方式和 LLM 配置见[上手指南](docs/getting-started.md#web-ui)。

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

## 快速开始

安装依赖后（见[上手指南](docs/getting-started.md)）：

```bash
tools/pipeline.sh doctor      # 环境自检
tools/pipeline.sh quickstart  # 跑内置 demo 任务
```

demo 跑通后，按[用户指南](docs/user-guide.md)从 HTML 文件或图片生成你自己的页面。

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

## 文档索引

| 文档 | 说明 |
|------|------|
| [docs/getting-started.md](docs/getting-started.md) | 环境搭建、依赖安装、环境自检、内置 demo、Web UI 配置 |
| [docs/user-guide.md](docs/user-guide.md) | 创建自己的任务：init → 内容 → 生成 → 校验 → 导出；task.json 配置；手动命令 |
| [docs/architecture.md](docs/architecture.md) | 系统架构、执行阶段、Refine 循环与 Web UI |
| [docs/llm_codegen_rules.md](docs/llm_codegen_rules.md) | LLM 代码生成约束规则 |
| [docs/board_profiles.md](docs/board_profiles.md) | Board profile 配置说明 |
| [docs/lvgl-sdl-cross-machine-deployment.md](docs/lvgl-sdl-cross-machine-deployment.md) | 跨机器部署指南 |

## 致谢

感谢 LinuxDo 社区的支持！
![LinuxDo](https://img.shields.io/badge/LinuxDo-%E7%A4%BE%E5%8C%BA%E6%94%AF%E6%8C%81-blue)
