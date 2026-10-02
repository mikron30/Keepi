#!/bin/zsh
set -e

PROJECT_PATH="${1:-$HOME/Keepi}"
cd "$PROJECT_PATH"

echo ""
echo "Keepi iPhone - production build"

if [[ ! -f lib/firebase_options.dart ]]; then
  echo "Missing lib/firebase_options.dart."
  echo "Run flutterfire configure --platforms=ios,web,android first."
  exit 3
fi

flutter pub get
dart run tool/generate_native_icons.dart

FIREBASE_DEFINES="$(dart run tool/print_firebase_defines.dart ios | tr '\n' ' ')"
if [[ -z "$FIREBASE_DEFINES" ]]; then
  echo "Could not read iOS Firebase configuration."
  exit 4
fi

echo "Building signed IPA using the Apple signing configured in Xcode..."
eval flutter build ipa --release $FIREBASE_DEFINES

echo ""
echo "iPhone build complete."
echo "IPA output: $PROJECT_PATH/build/ios/ipa/"
