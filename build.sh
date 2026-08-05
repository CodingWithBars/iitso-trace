#!/bin/bash

echo "Starting Vercel Build..."

# Install Flutter
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter repository..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter Doctor:"
flutter doctor -v

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter Web..."
# Using --release for optimized build
flutter build web --release

echo "Build complete."
