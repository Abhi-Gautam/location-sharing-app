#!/bin/bash
echo "🚀 Starting Flutter Mobile App..."
echo "Available devices:"
flutter devices
echo ""
echo "Choose your device:"
echo "1) iOS Simulator"
echo "2) Android Emulator"
echo "3) Chrome Browser"
echo "4) List all devices and choose manually"
echo ""
read -p "Enter choice (1-4): " choice

cd mobile_app

case $choice in
    1)
        echo "Starting iOS Simulator..."
        flutter run -d ios
        ;;
    2)
        echo "Starting Android Emulator..."
        flutter run -d android
        ;;
    3)
        echo "Starting Chrome Browser..."
        flutter run -d chrome
        ;;
    4)
        echo "Available devices:"
        flutter devices
        echo ""
        read -p "Enter device ID: " device_id
        flutter run -d "$device_id"
        ;;
    *)
        echo "Invalid choice. Starting default device..."
        flutter run
        ;;
esac
