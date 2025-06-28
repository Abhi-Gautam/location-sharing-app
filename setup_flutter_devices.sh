#!/bin/bash

echo "📱 Setting up Flutter iOS and Android devices..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Checking Flutter setup..."
flutter doctor

echo ""
echo "=========================================="
echo "📱 Device Setup Options"
echo "=========================================="
echo ""
echo "Choose what to set up:"
echo "1) iOS Simulator"
echo "2) Android Emulator" 
echo "3) Both iOS and Android"
echo "4) Check current devices only"
echo ""
read -p "Enter choice (1-4): " choice

case $choice in
    1|3)
        echo ""
        print_status "Setting up iOS Simulator..."
        
        # Check if Xcode is installed
        if ! command -v xcode-select &> /dev/null; then
            print_error "Xcode not found. Please install Xcode from the App Store."
            echo "After installing Xcode, run: xcode-select --install"
            exit 1
        fi
        
        print_success "Xcode found!"
        
        # Check if CocoaPods is installed
        if ! command -v pod &> /dev/null; then
            print_status "Installing CocoaPods..."
            sudo gem install cocoapods
            pod setup
        fi
        
        print_success "CocoaPods ready!"
        
        # Setup iOS in Flutter project
        print_status "Setting up iOS for Flutter project..."
        cd mobile_app/ios
        pod install
        cd ../..
        
        # Launch iOS Simulator
        print_status "Opening iOS Simulator..."
        open -a Simulator
        
        print_success "iOS Simulator should now be opening!"
        print_warning "In Simulator app, go to Device > iOS > iPhone 15 (or your preferred model)"
        
        if [ "$choice" = "1" ]; then
            echo ""
            print_status "iOS setup complete! Run 'flutter devices' to see available devices."
        fi
        ;;
esac

case $choice in
    2|3)
        echo ""
        print_status "Setting up Android Emulator..."
        
        # Check if Android Studio is installed
        if [ ! -d "/Applications/Android Studio.app" ] && [ ! -d "$HOME/Applications/Android Studio.app" ]; then
            print_warning "Android Studio not found at standard location."
            echo ""
            echo "Please install Android Studio:"
            echo "1. Download from: https://developer.android.com/studio"
            echo "2. Or install via Homebrew: brew install --cask android-studio"
            echo ""
            echo "After installation:"
            echo "1. Open Android Studio"
            echo "2. Go through the setup wizard"
            echo "3. Install Android SDK (API 34 recommended)"
            echo "4. Go to Tools > AVD Manager"
            echo "5. Create a new Virtual Device (e.g., Pixel 7)"
            echo "6. Download a system image (e.g., API 34 arm64)"
            echo "7. Finish creating the emulator"
            echo ""
            read -p "Press Enter after you've completed Android Studio setup..."
        fi
        
        # Check for Android SDK
        if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
            print_warning "Android SDK environment variables not set."
            echo ""
            echo "Please add these to your ~/.zshrc or ~/.bash_profile:"
            echo 'export ANDROID_HOME=$HOME/Library/Android/sdk'
            echo 'export PATH=$PATH:$ANDROID_HOME/emulator'
            echo 'export PATH=$PATH:$ANDROID_HOME/tools'
            echo 'export PATH=$PATH:$ANDROID_HOME/tools/bin'
            echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools'
            echo ""
            echo "Then run: source ~/.zshrc"
            echo ""
            read -p "Press Enter after you've updated your environment variables..."
        fi
        
        # List available emulators
        print_status "Checking for available Android emulators..."
        flutter emulators
        
        echo ""
        print_status "If no emulators are listed above:"
        echo "1. Open Android Studio"
        echo "2. Go to Tools > AVD Manager"
        echo "3. Click 'Create Virtual Device'"
        echo "4. Choose a device (e.g., Pixel 7)"
        echo "5. Download and select a system image"
        echo "6. Click Finish"
        echo ""
        
        read -p "Do you want to try launching an existing emulator? (y/N): " launch_emulator
        if [[ "$launch_emulator" =~ ^[Yy]$ ]]; then
            print_status "Available emulators:"
            flutter emulators
            echo ""
            read -p "Enter emulator name to launch (or press Enter to skip): " emulator_name
            if [ ! -z "$emulator_name" ]; then
                print_status "Launching $emulator_name..."
                flutter emulators --launch "$emulator_name"
            fi
        fi
        ;;
esac

case $choice in
    4)
        print_status "Current Flutter device setup:"
        flutter devices
        echo ""
        print_status "Available emulators:"
        flutter emulators
        ;;
esac

echo ""
print_status "Final device check:"
flutter devices

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Run 'flutter devices' to see available devices"
echo "2. If iOS Simulator is available, you can use option 1 in the Flutter app"
echo "3. If Android emulator is running, you can use option 2 in the Flutter app"
echo "4. Chrome browser is always available as option 3"
echo ""
echo "Troubleshooting:"
echo "- For iOS: Ensure Xcode is installed and Simulator app is open"
echo "- For Android: Ensure Android Studio is installed and an emulator is created/running"
echo "- Run 'flutter doctor' to check for any remaining issues"
echo ""
print_success "Happy Flutter development! 🚀"