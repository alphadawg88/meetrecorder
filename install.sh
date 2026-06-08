#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"
BIN_DIR="$HOME_DIR/bin"
APP_DIR="$HOME_DIR/Applications"

echo "=== MeetRecorder Installer ==="
echo "Project root: $SCRIPT_DIR"

# 1. Compile Swift helpers
echo "Compiling set-default-output..."
swiftc -framework CoreAudio -o "$SCRIPT_DIR/src/swift/set-default-output" "$SCRIPT_DIR/src/swift/set-default-output.swift"

echo "Compiling menu bar app..."
swiftc -framework AppKit -o /tmp/MeetRecorderMenuBar "$SCRIPT_DIR/src/swift/MeetRecorderMenuBar.swift"

# 2. Build .app bundle
APP="$APP_DIR/MeetRecorderMenuBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp /tmp/MeetRecorderMenuBar "$APP/Contents/MacOS/MeetRecorderMenuBar"
chmod +x "$APP/Contents/MacOS/MeetRecorderMenuBar"
cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MeetRecorderMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.alfredwong.meetrecorder</string>
    <key>CFBundleName</key>
    <string>MeetRecorder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
</dict>
</plist>
EOF
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "App bundle installed to: $APP"

# 3. Symlink CLI wrappers into ~/bin
mkdir -p "$BIN_DIR"
for script in meetrecord meetstop meettoggle meetlast meetlist; do
    src="$SCRIPT_DIR/bin/$script"
    dst="$BIN_DIR/$script"
    if [ -L "$dst" ]; then
        rm "$dst"
    fi
    if [ ! -e "$dst" ]; then
        ln -s "$src" "$dst"
        echo "Linked $dst -> $src"
    else
        echo "Warning: $dst already exists (not overwriting)"
    fi
done

# 4. Check Python deps
echo "Checking Python dependencies..."
python3 -c "import sounddevice, soundfile, numpy, whisper" 2>/dev/null || {
    echo "Installing Python dependencies..."
    pip3 install sounddevice soundfile numpy openai-whisper
}

# 5. Check Background Music
if pgrep -x "Background Music" > /dev/null; then
    echo "Background Music is running."
else
    echo "WARNING: Background Music is not running. Launch it before recording."
fi

echo ""
echo "Installation complete."
echo "Add to PATH if needed: export PATH=\"\$HOME/bin:\$PATH\""
echo "Launch the app: open \"$APP\""
echo "Or use CLI: meetrecord --name test"
