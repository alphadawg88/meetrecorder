#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="MeetRecorder"
BUNDLE_DIR="$SCRIPT_DIR/dist/${APP_NAME}.app"
RES="$BUNDLE_DIR/Contents/Resources"
MACOS="$BUNDLE_DIR/Contents/MacOS"

# Clean previous build
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS" "$RES/static"

# ───── Copy app assets ──────────────────────────────────────
cp "$SCRIPT_DIR/backend.py" "$RES/"
cp "$SCRIPT_DIR/static/index.html" "$RES/static/"

# Copy project scripts so backend can shell out to them
cp -r "$PROJECT_ROOT/bin" "$RES/"
cp -r "$PROJECT_ROOT/src" "$RES/"

# ───── Info.plist ───────────────────────────────────────
cat > "$BUNDLE_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>MeetRecorder</string>
  <key>CFBundleIdentifier</key>
  <string>com.alfredwong.meetrecorder</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MeetRecorder</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>2.0</string>
  <key>CFBundleVersion</key>
  <string>200</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.15</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# ───── Launcher script ──────────────────────────────────
cat > "$MACOS/MeetRecorder" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
PIDFILE="/tmp/meetrecorder_app.pid"
PORT=8742

# Kill any previous instance
if [[ -f "$PIDFILE" ]]; then
  oldpid=$(cat "$PIDFILE" 2>/dev/null) || true
  if [[ -n "${oldpid:-}" ]]; then
    kill "$oldpid" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
fi

# Find Python3
PYTHON="${PYTHON:-$(command -v python3 || command -v python || echo '')}"
if [[ -z "$PYTHON" ]]; then
  osascript -e 'display alert "Python not found" message "MeetRecorder requires Python 3 to be installed."'
  exit 1
fi

# Set env so backend can find bundled scripts
export MEETRECORDER_ROOT="$RES"
export MEETRECORDER_PORT="$PORT"

# Start backend
nohup "$PYTHON" "$RES/backend.py" > "$RES/backend.log" 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > "$PIDFILE"

# Wait for server to be ready
for i in {1..30}; do
  if curl -s "http://127.0.0.1:$PORT/api/status" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

# Open browser in app-like window
osascript -e "tell application \"Safari\" to make new document with properties {URL:\"http://127.0.0.1:$PORT\"}" 2>/dev/null || \
open "http://127.0.0.1:$PORT"

# Keep script alive so the .app doesn't exit immediately
# When user quits the app, this script receives SIGTERM
cleanup() {
  kill "$BACKEND_PID" 2>/dev/null || true
  rm -f "$PIDFILE"
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Wait indefinitely
while true; do
  sleep 1
done
LAUNCHER

chmod +x "$MACOS/MeetRecorder"

# ───── PkgInfo ──────────────────────────────────────────
printf 'APPL????' > "$BUNDLE_DIR/Contents/PkgInfo"

echo "Built: $BUNDLE_DIR"
echo "Run: open '$BUNDLE_DIR'"
