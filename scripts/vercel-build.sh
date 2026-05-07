#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_SDK_DIR="${ROOT_DIR}/.local_toolchain/flutter"
FLUTTER_BIN="${FLUTTER_SDK_DIR}/bin/flutter"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    flutter --version
    return
  fi

  if [[ ! -x "${FLUTTER_BIN}" ]]; then
    rm -rf "${FLUTTER_SDK_DIR}"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_SDK_DIR}"
  fi

  export PATH="${FLUTTER_SDK_DIR}/bin:${PATH}"
  flutter --version
}

main() {
  cd "${ROOT_DIR}"
  ensure_flutter
  flutter config --enable-web
  flutter pub get

  local dart_defines=()
  if [[ -n "${SUPABASE_URL:-}" ]]; then
    dart_defines+=(--dart-define="SUPABASE_URL=${SUPABASE_URL}")
  fi
  if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
    dart_defines+=(--dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")
  fi
  dart_defines+=(
    --dart-define="BACKEND_API_URL=${BACKEND_API_URL:-https://student-system-backend.onrender.com/api/v1}"
  )

  flutter build web --release --base-href=/ "${dart_defines[@]}"
}

main "$@"
