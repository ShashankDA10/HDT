#!/bin/bash

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable

export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor

echo "Getting dependencies..."
flutter pub get

echo "Building web..."
flutter build web --base-href /