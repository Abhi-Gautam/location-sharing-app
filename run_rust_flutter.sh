#!/bin/bash

# Location Sharing - Rust Backend + Flutter Setup Script
# Run this script from the project root directory

set -e  # Exit on any error

echo "🚀 Starting Location Sharing with Rust Backend + Flutter..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if we're in the right directory
if [[ ! -d "backend_rust" || ! -d "mobile_app" ]]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v cargo &> /dev/null; then
    print_error "Rust/Cargo not found. Please install Rust from https://rustup.rs/"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    print_error "Flutter not found. Please install Flutter from https://flutter.dev/"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker not found. Please install Docker from https://docker.com/"
    exit 1
fi

print_success "All prerequisites found!"

# Function to check if port is in use
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Check if required ports are available
print_status "Checking port availability..."
ports_in_use=()

if check_port 5432; then ports_in_use+=(5432); fi
if check_port 6379; then ports_in_use+=(6379); fi
if check_port 8000; then ports_in_use+=(8000); fi
if check_port 8001; then ports_in_use+=(8001); fi

if [[ ${#ports_in_use[@]} -gt 0 ]]; then
    print_warning "The following ports are in use: ${ports_in_use[*]}"
    echo "Do you want to continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_error "Aborted by user"
        exit 1
    fi
fi

# Start infrastructure
print_status "Starting Docker infrastructure (PostgreSQL & Redis only)..."
cd backend_rust

# Only start infrastructure services (not the Rust apps)
if docker-compose up -d postgres redis; then
    print_success "Docker infrastructure started successfully"
else
    print_error "Failed to start Docker infrastructure"
    exit 1
fi

# Wait for services to be ready
print_status "Waiting for database and Redis to be ready..."
sleep 5

# Verify Docker services
if docker-compose ps | grep -q "Up"; then
    print_success "Infrastructure services are running"
else
    print_error "Infrastructure services failed to start properly"
    docker-compose logs
    exit 1
fi

# Build Rust backend
print_status "Building Rust backend..."
if cargo build --release; then
    print_success "Rust backend built successfully"
else
    print_error "Failed to build Rust backend"
    exit 1
fi

# Setup Flutter
print_status "Setting up Flutter mobile app..."
cd ../mobile_app

if flutter pub get; then
    print_success "Flutter dependencies installed"
else
    print_error "Failed to install Flutter dependencies"
    exit 1
fi

# Create Flutter config if it doesn't exist
if [[ ! -d "lib/config" ]]; then
    mkdir -p lib/config
fi

# Create or update Flutter config for Rust backend
print_status "Creating Flutter configuration for Rust backend..."
cat > lib/config/app_config.dart << 'EOF'
class AppConfig {
  static const String baseUrl = 'http://localhost:8000/api';
  static const String wsUrl = 'ws://localhost:8001';
  static const String environment = 'development';
  static const String backendType = 'rust';
}
EOF
print_success "Flutter configuration created/updated"

cd ..

# Create terminal script for services
print_status "Creating service startup scripts..."

# Create API server script
cat > start_api_server.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Rust API Server on port 8000..."
echo "Press Ctrl+C to stop"
cd backend_rust
RUST_LOG=info cargo run --bin api-server
EOF

# Create WebSocket server script
cat > start_websocket_server.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Rust WebSocket Server on port 8001..."
echo "Press Ctrl+C to stop"
cd backend_rust
RUST_LOG=info cargo run --bin websocket-server
EOF

# Create Flutter script
cat > start_flutter_app.sh << 'EOF'
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
EOF

chmod +x start_api_server.sh start_websocket_server.sh start_flutter_app.sh

print_success "Setup completed successfully!"
echo ""
echo "=================================================="
echo "🎉 Rust Backend + Flutter Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Start API Server:      ./start_api_server.sh"
echo "2. Start WebSocket Server: ./start_websocket_server.sh"
echo "3. Start Flutter App:     ./start_flutter_app.sh"
echo ""
echo "Or run all in separate terminals:"
echo ""
echo "Terminal 1: ./start_api_server.sh"
echo "Terminal 2: ./start_websocket_server.sh"  
echo "Terminal 3: ./start_flutter_app.sh"
echo ""
echo "Services will be available at:"
echo "- API Server: http://localhost:8000 (running locally)"
echo "- WebSocket Server: ws://localhost:8001 (running locally)"
echo "- PostgreSQL: localhost:5432 (Docker)"
echo "- Redis: localhost:6379 (Docker)"
echo "- Health Check: curl http://localhost:8000/health"
echo ""
echo "To stop services:"
echo "- Press Ctrl+C in each Rust server terminal"
echo "- Stop Docker infrastructure: cd backend_rust && docker-compose down"
echo ""
echo "Optional database tools:"
echo "- Redis GUI: docker-compose --profile tools up redis-commander"
echo "- pgAdmin: docker-compose --profile tools up pgadmin"
echo ""
print_success "Happy coding! 🚀"