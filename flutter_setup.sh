#!/bin/zsh

echo "🧹 Starting complete Flutter & Xcode cache cleanup..."

# Clean Flutter build
echo "📦 Cleaning Flutter build..."
flutter clean

# Remove Flutter's build cache
echo "🗑️ Removing Flutter build cache..."
rm -rf build/
rm -rf .dart_tool/

# Get Flutter dependencies
echo "📥 Getting Flutter dependencies..."
flutter pub get

# Navigate to the iOS directory
cd ios

# Remove Podfile.lock and Pods directory
echo "🗑️ Removing Pods and Podfile.lock..."
rm -f Podfile.lock
rm -rf Pods

# Remove Xcode derived data for this project
echo "🗑️ Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Remove Xcode build folder
echo "🗑️ Removing iOS build folder..."
rm -rf build/

# Clear CocoaPods cache
echo "🗑️ Clearing CocoaPods cache..."
pod cache clean --all

# Remove Flutter generated files in iOS
echo "🗑️ Removing Flutter generated iOS files..."
rm -rf Flutter/Flutter.framework
rm -rf Flutter/App.framework
rm -rf Flutter/ephemeral/
rm -rf .symlinks/

# Remove xcworkspace and xcodeproj build artifacts
echo "🗑️ Cleaning Xcode project artifacts..."
rm -rf Runner.xcworkspace/xcuserdata/
rm -rf Runner.xcodeproj/xcuserdata/
rm -rf Runner.xcodeproj/project.xcworkspace/xcuserdata/

# Deintegrate and clean CocoaPods
echo "🔄 Deintegrating CocoaPods..."
pod deintegrate

# Update CocoaPods repo
echo "🔄 Updating CocoaPods repo..."
pod repo update

# Install CocoaPods dependencies with repo update
echo "📥 Installing CocoaPods dependencies..."
pod install --repo-update

# Navigate back to the project root
cd ..

# Precache iOS artifacts
echo "📥 Precaching Flutter iOS artifacts..."
flutter precache --ios --force

# Build iOS app for simulator (this resolves Flutter framework linking issues)
echo "🔨 Building iOS app for simulator..."
flutter build ios --simulator --debug

echo "✅ Flutter setup completed successfully!"
echo "💡 Now try running: flutter run -d <device>"