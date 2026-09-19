#!/usr/bin/env bash

set -Eeuo pipefail

if (( $# != 1 )); then
  echo "Usage: $0 CHROMIUM_EXECUTABLE" >&2
  exit 2
fi

chromium_executable=$1
target_url=https://www.google.com/
startup_timeout=${CHROMIUM_STARTUP_TIMEOUT:-300}
stability_time=${CHROMIUM_STABILITY_TIME:-150}

if [[ ! -x "$chromium_executable" ]]; then
  echo "Chromium executable is missing or not executable: $chromium_executable" >&2
  exit 1
fi

for dependency in curl xvfb-run; do
  if ! command -v "$dependency" >/dev/null; then
    echo "Required command is unavailable: $dependency" >&2
    exit 1
  fi
done

profile_dir=$(mktemp -d "${TMPDIR:-/tmp}/chromium-xvfb-smoke.XXXXXXXX")
chromium_log=$profile_dir/chromium.log
browser_pid=

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  if [[ -n "$browser_pid" ]] && kill -0 "$browser_pid" 2>/dev/null; then
    kill "$browser_pid" 2>/dev/null || true
    wait "$browser_pid" 2>/dev/null || true
  fi

  if (( status != 0 )) && [[ -s "$chromium_log" ]]; then
    echo "---- Chromium output (last 200 lines) ----" >&2
    tail -n 200 "$chromium_log" >&2
  fi

  rm -rf "$profile_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Launching $chromium_executable under Xvfb with $target_url"
xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
  "$chromium_executable" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --no-first-run \
  --no-default-browser-check \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port=0 \
  --user-data-dir="$profile_dir/profile" \
  "$target_url" >"$chromium_log" 2>&1 &
browser_pid=$!

devtools_port_file=$profile_dir/profile/DevToolsActivePort
startup_deadline=$((SECONDS + startup_timeout))

while [[ ! -s "$devtools_port_file" ]]; do
  if ! kill -0 "$browser_pid" 2>/dev/null; then
    wait "$browser_pid" || status=$?
    echo "Chromium exited before becoming ready (status ${status:-0})" >&2
    exit 1
  fi
  if (( SECONDS >= startup_deadline )); then
    echo "Chromium did not become ready within ${startup_timeout}s" >&2
    exit 1
  fi
  sleep 1
done

read -r devtools_port < "$devtools_port_file"
if [[ ! "$devtools_port" =~ ^[0-9]+$ ]]; then
  echo "Chromium wrote an invalid DevTools port: $devtools_port" >&2
  exit 1
fi

devtools_url="http://127.0.0.1:${devtools_port}/json/version"
while ! curl --fail --silent --show-error --max-time 2 "$devtools_url" >/dev/null; do
  if ! kill -0 "$browser_pid" 2>/dev/null; then
    echo "Chromium exited while its DevTools endpoint was starting" >&2
    exit 1
  fi
  if (( SECONDS >= startup_deadline )); then
    echo "Chromium's DevTools endpoint did not respond within ${startup_timeout}s" >&2
    exit 1
  fi
  sleep 1
done

targets_url="http://127.0.0.1:${devtools_port}/json/list"
navigation_deadline=$((SECONDS + startup_timeout))
while ! curl --fail --silent --max-time 2 "$targets_url" |
  grep -Eq '"url"[[:space:]]*:[[:space:]]*"https://(www\.)?google\.com/'; do
  if ! kill -0 "$browser_pid" 2>/dev/null; then
    echo "Chromium exited while opening the Google page" >&2
    exit 1
  fi
  if (( SECONDS >= navigation_deadline )); then
    echo "Chromium did not open the expected Google page within ${startup_timeout}s" >&2
    exit 1
  fi
  sleep 1
done

stability_deadline=$((SECONDS + stability_time))
while (( SECONDS < stability_deadline )); do
  if ! kill -0 "$browser_pid" 2>/dev/null; then
    wait "$browser_pid" || status=$?
    echo "Chromium crashed during the stability window (status ${status:-0})" >&2
    exit 1
  fi
  sleep 1
done

curl --fail --silent --show-error --max-time 2 "$devtools_url" >/dev/null
echo "Chromium remained responsive for ${stability_time}s after startup"
