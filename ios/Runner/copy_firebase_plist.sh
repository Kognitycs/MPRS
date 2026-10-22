#!/bin/sh
# Copies the flavor-specific Firebase plist before compile.
set -e
FIREBASE_DIR="${PROJECT_DIR}/Runner/Firebase/${FIREBASE_CONFIG_DIR}"
SOURCE="${FIREBASE_DIR}/GoogleService-Info.plist"
DEST="${PROJECT_DIR}/Runner/GoogleService-Info.plist"

if [ ! -f "$SOURCE" ]; then
  echo "error: Missing Firebase plist at $SOURCE"
  exit 1
fi

cp "$SOURCE" "$DEST"
echo "Firebase: copied $SOURCE -> $DEST"
