#!/bin/bash
set -e

echo "=== MeetRecorder Build Script ==="

if ! command -v xcodegen &> /dev/null; then
    echo "xcodegen not found. Installing via Homebrew..."
    brew install xcodegen
fi

echo "Generating Xcode project..."
xcodegen generate

echo "Opening in Xcode..."
open MeetRecorder.xcodeproj

echo "Done. Press Cmd+R to build and run."
echo "To create a release archive: Product > Archive in Xcode."
