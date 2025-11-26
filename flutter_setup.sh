#!/bin/zsh

# Clean Flutter build
flutter clean

# Get Flutter dependencies
flutter pub get

# Navigate to the iOS directory
cd ios

# Remove Podfile.lock and Pods directory
rm Podfile.lock
rm -rf Pods

# Install CocoaPods dependencies with repo update
pod install --repo-update

# Navigate back to the project root
cd ..

echo "Flutter setup completed successfully!"