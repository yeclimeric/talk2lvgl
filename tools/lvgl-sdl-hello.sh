#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PORT_DIR="${ROOT_DIR}/lv_port_linux_test"
DEP_ROOT="${ROOT_DIR}/.deps/sdl2-image/root/usr"
BUILD_DIR="${PORT_DIR}/build-hello"
BIN_PATH="${BUILD_DIR}/bin/lvglsim"

resolve_local_sdl_pkgconfig_dir() {
    local candidates=(
        "${DEP_ROOT}/lib/pkgconfig"
        "${DEP_ROOT}/lib/x86_64-linux-gnu/pkgconfig"
        "${DEP_ROOT}/lib/aarch64-linux-gnu/pkgconfig"
        "${DEP_ROOT}/lib/arm64-linux-gnu/pkgconfig"
        "${DEP_ROOT}/local/lib/pkgconfig"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -f "${candidate}/SDL2_image.pc" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

resolve_local_sdl_lib_dir() {
    local pkg_dir
    pkg_dir="$(resolve_local_sdl_pkgconfig_dir || true)"
    if [[ -n "${pkg_dir}" ]]; then
        printf '%s\n' "$(dirname "${pkg_dir}")"
        return 0
    fi

    return 1
}

detect_cpu_count() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu 2>/dev/null || echo 1
    else
        echo 1
    fi
}

env_with_local_sdl() {
    local pkg_config_path_value="$(resolve_local_sdl_pkgconfig_dir || true)"
    local lib_dir="$(resolve_local_sdl_lib_dir || true)"

    if [[ -n "${pkg_config_path_value}" && -n "${lib_dir}" ]]; then
        env \
            PKG_CONFIG_PATH="${pkg_config_path_value}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" \
            LD_LIBRARY_PATH="${lib_dir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
            "$@"
        return
    fi

    env "$@"
}

configure() {
    env_with_local_sdl cmake -S "${PORT_DIR}" -B "${BUILD_DIR}" -DCONFIG=sdl-hello
}

build() {
    env_with_local_sdl cmake --build "${BUILD_DIR}" -j"$(detect_cpu_count)"
}

backend_info() {
    env_with_local_sdl "${BIN_PATH}" -B
}

run_gui() {
    env_with_local_sdl "${BIN_PATH}" -b sdl
}

run_headless() {
    env_with_local_sdl \
        SDL_VIDEODRIVER=dummy \
        SDL_RENDER_DRIVER=software \
        "${BIN_PATH}" -b sdl
}

usage() {
    cat <<'EOF'
Usage: tools/lvgl-sdl-hello.sh <command>

Commands:
  configure      Configure the hello-world SDL demo
  build          Build the hello-world SDL demo
  rebuild        Clean and rebuild the hello-world SDL demo
  backend-info   Print default and supported backends
  run            Run the hello-world SDL demo with a real window
  run-headless   Run the hello-world SDL demo in headless mode
EOF
}

cmd="${1:-}"

case "${cmd}" in
    configure)
        configure
        ;;
    build)
        build
        ;;
    rebuild)
        rm -rf "${BUILD_DIR}"
        configure
        build
        ;;
    backend-info)
        backend_info
        ;;
    run)
        run_gui
        ;;
    run-headless)
        run_headless
        ;;
    *)
        usage
        exit 1
        ;;
esac
