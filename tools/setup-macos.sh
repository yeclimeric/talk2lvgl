#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKIP_BREW_INSTALL=0
SKIP_QUICKSTART=0
DOCTOR_ONLY=0
LOG_FILE="${REPO_ROOT}/.tmp/setup-macos-$(date '+%Y%m%d-%H%M%S').log"
PYTHON_BIN="${PYTHON_BIN:-python3}"

mkdir -p "${REPO_ROOT}/.tmp"

log() {
    printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "${LOG_FILE}"
}

warn() {
    printf '\n[WARN] %s\n' "$*" | tee -a "${LOG_FILE}" >&2
}

fail() {
    printf '\n[ERROR] %s\n' "$*" | tee -a "${LOG_FILE}" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: tools/setup-macos.sh [--skip-brew] [--skip-quickstart] [--doctor-only]

Options:
  --skip-brew         Skip Homebrew package installation (useful if already set up)
  --skip-quickstart   Install deps and run doctor, but do not trigger quickstart
  --doctor-only       Run only doctor and exit
  -h, --help          Show this help text

Log file:
  ${REPO_ROOT}/.tmp/setup-macos-<timestamp>.log
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-brew)
                SKIP_BREW_INSTALL=1
                ;;
            --skip-quickstart)
                SKIP_QUICKSTART=1
                ;;
            --doctor-only)
                DOCTOR_ONLY=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                fail "Unknown argument: $1"
                ;;
        esac
        shift
    done
}

require_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        fail "This setup script is intended for macOS only. Current OS: $(uname -s)"
    fi

    local arch
    arch="$(uname -m)"
    if [[ "${arch}" == "arm64" ]]; then
        log "Detected macOS Apple Silicon (arm64)."
    elif [[ "${arch}" == "x86_64" ]]; then
        log "Detected macOS Intel (x86_64)."
    else
        log "Detected macOS architecture: ${arch}"
    fi
}

ensure_xcode_tools() {
    if ! xcode-select -p >/dev/null 2>&1; then
        log "Installing Xcode Command Line Tools..."
        xcode-select --install || true
        echo "Please complete the Xcode Command Line Tools installation prompt and rerun this script."
        exit 1
    fi
}

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        log "Homebrew already available at $(command -v brew)"
        return
    fi

    log "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        fail "Homebrew installation did not add a brew binary to PATH."
    fi
}

ensure_brew_path() {
    local brew_bin=""
    for candidate in /opt/homebrew/bin /usr/local/bin; do
        if [[ -x "${candidate}/brew" ]]; then
            brew_bin="${candidate}"
            break
        fi
    done

    if [[ -n "${brew_bin}" ]]; then
        export PATH="${brew_bin}:${PATH}"
        log "Added Homebrew to PATH: ${brew_bin}"
    fi
}

ensure_python_bin() {
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_BIN="$(command -v python3)"
        return
    fi

    local candidates=(
        /opt/homebrew/opt/python@3.12/libexec/bin/python
        /usr/local/opt/python@3.12/libexec/bin/python
        /opt/homebrew/opt/python@3.13/libexec/bin/python
        /usr/local/opt/python@3.13/libexec/bin/python
        /opt/homebrew/bin/python3
        /usr/local/bin/python3
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -x "${candidate}" ]]; then
            export PATH="$(dirname "${candidate}"):${PATH}"
            PYTHON_BIN="${candidate}"
            return
        fi
    done

    fail "python3 is required but was not found in PATH or common Homebrew locations."
}

install_brew_packages() {
    if [[ "${SKIP_BREW_INSTALL}" -eq 1 ]]; then
        log "Skipping Homebrew package installation (--skip-brew)."
        return
    fi

    log "Installing required Homebrew dependencies..."
    brew install --quiet \
        cmake \
        pkg-config \
        git \
        python@3.12 \
        sdl2 \
        sdl2_image \
        freetype || fail "Homebrew dependency installation failed. See ${LOG_FILE} for details."
}

install_python_packages() {
    ensure_python_bin
    log "Using Python interpreter: ${PYTHON_BIN}"
    log "Installing Python dependencies..."
    "${PYTHON_BIN}" -m pip install --upgrade pip
    "${PYTHON_BIN}" -m pip install --upgrade "Pillow>=9.1" flask httpx
}

ensure_playwright_browser() {
    if command -v chromium >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1 || command -v wkhtmltoimage >/dev/null 2>&1; then
        log "A browser renderer is already available; skipping Playwright browser install."
        return
    fi

    log "Installing Playwright browser for HTML reference rendering..."
    "${PYTHON_BIN}" -m pip install --upgrade playwright || true
    if "${PYTHON_BIN}" - <<'PY'
import importlib.util
print('yes' if importlib.util.find_spec('playwright') else 'no')
PY
    then
        "${PYTHON_BIN}" -m playwright install chromium || warn "Playwright Chromium install failed; the repo may still run quickstart with the built-in reference image."
    fi
}

ensure_lv_port_linux() {
    local port_dir="${REPO_ROOT}/lv_port_linux_test"

    if [[ -d "${port_dir}/.git" ]]; then
        log "lv_port_linux_test already exists; updating submodules..."
        git -C "${port_dir}" submodule update --init --recursive
        return
    fi

    if [[ -d "${port_dir}" ]]; then
        fail "Found ${port_dir} but it is not a git checkout. Please remove or rename it and rerun."
    fi

    log "Cloning lv_port_linux_test..."
    git clone https://github.com/lvgl/lv_port_linux.git "${port_dir}"
    git -C "${port_dir}" submodule update --init --recursive
}

run_doctor() {
    ensure_python_bin
    log "Running project doctor check..."
    "${PYTHON_BIN}" "${REPO_ROOT}/tools/doctor.py"
}

run_quickstart() {
    if [[ "${SKIP_QUICKSTART}" -eq 1 ]]; then
        log "Skipping quickstart (--skip-quickstart)."
        return
    fi

    log "Running the bundled quickstart demo..."
    bash "${REPO_ROOT}/tools/pipeline.sh" quickstart
}

main() {
    parse_args "$@"
    require_macos
    log "Setup log: ${LOG_FILE}"
    ensure_xcode_tools
    ensure_brew_path
    ensure_homebrew
    ensure_brew_path
    install_brew_packages
    install_python_packages
    ensure_playwright_browser
    ensure_lv_port_linux
    run_doctor

    if [[ "${DOCTOR_ONLY}" -eq 1 ]]; then
        log "Doctor-only mode enabled; exiting after environment health check."
        log "Final environment summary:"
        log "  arch: $(uname -m)"
        log "  brew: $(command -v brew || echo missing)"
        log "  python: ${PYTHON_BIN}"
        exit 0
    fi

    run_quickstart

    log "Environment setup completed successfully."
    log "Final environment summary:"
    log "  arch: $(uname -m)"
    log "  brew: $(command -v brew || echo missing)"
    log "  python: ${PYTHON_BIN}"
    log "  log file: ${LOG_FILE}"
    log "You can rerun the project any time with:"
    log "  bash tools/pipeline.sh doctor"
    log "  bash tools/pipeline.sh quickstart"
}

main "$@"
