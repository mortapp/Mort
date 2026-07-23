#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
repo_root="$(cd -- "${script_dir}/.." >/dev/null 2>&1 && pwd)"
flutter_app="${repo_root}/flutter_mort"
output_dir="${flutter_app}/build/web"
flutter_version="${FLUTTER_VERSION:-3.41.2}"

if [[ ! -d "${flutter_app}" ]]; then
  echo "Flutter app directory is missing: ${flutter_app}" >&2
  exit 1
fi

supabase_url="${SUPABASE_URL:-${EXPO_PUBLIC_SUPABASE_URL:-}}"
supabase_anon_key="${SUPABASE_ANON_KEY:-${EXPO_PUBLIC_SUPABASE_ANON_KEY:-}}"

if [[ -z "${supabase_url}" ]]; then
  echo "Set EXPO_PUBLIC_SUPABASE_URL or SUPABASE_URL in Netlify with Builds scope." >&2
  exit 1
fi
if [[ "${supabase_url}" != https://* ]]; then
  echo "The Supabase URL used for the web build must use HTTPS." >&2
  exit 1
fi
if [[ -z "${supabase_anon_key}" ]]; then
  echo "Set EXPO_PUBLIC_SUPABASE_ANON_KEY or SUPABASE_ANON_KEY in Netlify with Builds scope." >&2
  exit 1
fi
if [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Remove SUPABASE_SERVICE_ROLE_KEY from the Netlify build environment." >&2
  exit 1
fi

if [[ "${NETLIFY:-}" == "true" ]]; then
  cache_root="${NETLIFY_CACHE_DIR:-${HOME}/.cache/netlify}"
  flutter_home="${cache_root}/mort-flutter-${flutter_version}"
  flutter_temp="${flutter_home}.installing"

  case "${flutter_home}" in
    "${cache_root}"/*) ;;
    *)
      echo "Flutter cache path escaped the Netlify cache directory." >&2
      exit 1
      ;;
  esac

  mkdir -p "${cache_root}"
  if [[ ! -x "${flutter_home}/bin/flutter" ]]; then
    rm -rf -- "${flutter_temp}" "${flutter_home}"
    echo "Installing cached Flutter ${flutter_version} for the Netlify build."
    git clone \
      --branch "${flutter_version}" \
      --depth 1 \
      --filter=blob:none \
      --single-branch \
      https://github.com/flutter/flutter.git \
      "${flutter_temp}"
    mv -- "${flutter_temp}" "${flutter_home}"
  fi

  git config --global --add safe.directory "${flutter_home}"
  flutter_command="${flutter_home}/bin/flutter"
  export PUB_CACHE="${cache_root}/mort-pub-cache"
  mkdir -p "${PUB_CACHE}"
else
  flutter_command="${FLUTTER_BIN:-}"
  if [[ -z "${flutter_command}" ]]; then
    flutter_command="$(command -v flutter || true)"
  fi
  if [[ -z "${flutter_command}" ]]; then
    echo "Flutter is not installed or available on PATH." >&2
    exit 1
  fi
fi

export PATH="$(dirname -- "${flutter_command}"):${PATH}"
"${flutter_command}" --disable-analytics >/dev/null
"${flutter_command}" config --enable-web >/dev/null

echo "Building the MORT Flutter web app with Flutter ${flutter_version}."
cd -- "${flutter_app}"
"${flutter_command}" pub get
"${flutter_command}" build web \
  --release \
  "--dart-define=SUPABASE_URL=${supabase_url}" \
  "--dart-define=SUPABASE_ANON_KEY=${supabase_anon_key}" \
  --dart-define=WEB_PREVIEW_MODE=true \
  --dart-define=IAP_ENABLED=false \
  --dart-define=ADS_ENABLED=false \
  --dart-define=USE_TEST_ADS=true

required_files=(
  "index.html"
  "manifest.json"
  "flutter_bootstrap.js"
  "main.dart.js"
)
for required_file in "${required_files[@]}"; do
  if [[ ! -f "${output_dir}/${required_file}" ]]; then
    echo "Flutter web output is missing ${required_file}." >&2
    exit 1
  fi
done

echo "Netlify Flutter build completed and build/web is ready to publish."
