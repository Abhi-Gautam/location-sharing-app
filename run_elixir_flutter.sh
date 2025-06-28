#!/bin/bash

# Location Sharing - Elixir Backend + Flutter Setup Script
# Run this script from the project root directory

set -e  # Exit on any error

echo "🚀 Starting Location Sharing with Elixir Backend + Flutter..."
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
if [[ ! -d "backend_elixir" || ! -d "mobile_app" ]]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v elixir &> /dev/null; then
    print_error "Elixir not found. Please install Elixir from https://elixir-lang.org/install.html"
    exit 1
fi

if ! command -v mix &> /dev/null; then
    print_error "Mix not found. Mix should come with Elixir installation"
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

# Check Elixir version
elixir_version=$(elixir --version | grep "Elixir" | awk '{print $2}')
print_success "Found Elixir version: $elixir_version"

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
if check_port 4000; then ports_in_use+=(4000); fi

if [[ ${#ports_in_use[@]} -gt 0 ]]; then
    print_warning "The following ports are in use: ${ports_in_use[*]}"
    echo "Do you want to continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_error "Aborted by user"
        exit 1
    fi
fi

# Start infrastructure (we can reuse the same Docker setup)
print_status "Starting Docker infrastructure (PostgreSQL & Redis only)..."

# Use the Docker setup from Rust backend (they share the same infrastructure)
if [[ -f "backend_rust/docker-compose.yml" ]]; then
    cd backend_rust
    # Only start infrastructure services
    if docker-compose up -d postgres redis; then
        print_success "Docker infrastructure started successfully"
    else
        print_error "Failed to start Docker infrastructure"
        exit 1
    fi
    cd ..
else
    print_error "Docker compose file not found. Please ensure backend_rust/docker-compose.yml exists"
    exit 1
fi

# Wait for services to be ready
print_status "Waiting for database and Redis to be ready..."
sleep 5

# Setup Elixir backend
print_status "Setting up Elixir backend..."
cd backend_elixir

# Install Hex and Rebar if not present
if ! mix local.hex --if-missing --force; then
    print_error "Failed to install Hex"
    exit 1
fi

if ! mix local.rebar --if-missing --force; then
    print_error "Failed to install Rebar"
    exit 1
fi

# Install dependencies
print_status "Installing Elixir dependencies..."
if mix deps.get; then
    print_success "Elixir dependencies installed"
else
    print_error "Failed to install Elixir dependencies"
    exit 1
fi

# Setup database
print_status "Setting up database..."
if mix ecto.setup; then
    print_success "Database setup completed"
else
    print_warning "Database setup had issues, but continuing..."
    # Try creating and migrating separately
    mix ecto.create || print_warning "Database might already exist"
    mix ecto.migrate || print_warning "Migration had issues"
fi

# Compile the project
print_status "Compiling Elixir project..."
if mix compile; then
    print_success "Elixir project compiled successfully"
else
    print_error "Failed to compile Elixir project"
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

# Create or update Flutter config for Elixir backend
print_status "Creating Flutter configuration for Elixir backend..."
cat > lib/config/app_config.dart << 'EOF'
class AppConfig {
  static const String baseUrl = 'http://localhost:4000/api';
  static const String wsUrl = 'ws://localhost:4000/socket';
  static const String environment = 'development';
  static const String backendType = 'elixir';
}
EOF
print_success "Flutter configuration created/updated for Elixir"

cd ..

# Create terminal script for services
print_status "Creating service startup scripts..."

# Create Elixir Phoenix server script
cat > start_elixir_server.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Elixir Phoenix Server on port 4000..."
echo "Phoenix LiveDashboard will be available at: http://localhost:4000/dashboard"
echo "Press Ctrl+C to stop"
cd backend_elixir
mix phx.server
EOF

# Create Flutter script (same as Rust version but with different messaging)
cat > start_flutter_app_elixir.sh << 'EOF'
#!/bin/bash
echo "🚀 Starting Flutter Mobile App (configured for Elixir backend)..."
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

chmod +x start_elixir_server.sh start_flutter_app_elixir.sh

print_success "Setup completed successfully!"
echo ""
echo "=================================================="
echo "🎉 Elixir Backend + Flutter Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Start Elixir Server: ./start_elixir_server.sh"
echo "2. Start Flutter App:   ./start_flutter_app_elixir.sh"
echo ""
echo "Or run in separate terminals:"
echo ""
echo "Terminal 1: ./start_elixir_server.sh"
echo "Terminal 2: ./start_flutter_app_elixir.sh"
echo ""
echo "Services will be available at:"
echo "- Phoenix Server: http://localhost:4000"
echo "- Phoenix LiveDashboard: http://localhost:4000/dashboard"
echo "- API Endpoints: http://localhost:4000/api/*"
echo "- WebSocket: ws://localhost:4000/socket"
echo ""
echo "Development URLs:"
echo "- Health Check: curl http://localhost:4000/api/health"
echo "- Phoenix LiveReload: Automatic on file changes"
echo ""
echo "To stop services:"
echo "- Press Ctrl+C in Phoenix server terminal"
echo "- Stop Docker infrastructure: cd backend_rust && docker-compose down"
echo ""
echo "Optional database tools:"
echo "- Redis GUI: cd backend_rust && docker-compose --profile tools up redis-commander"
echo "- pgAdmin: cd backend_rust && docker-compose --profile tools up pgadmin"
echo ""
echo "Useful Elixir commands:"
echo "- Interactive shell: cd backend_elixir && iex -S mix phx.server"
echo "- Run tests: cd backend_elixir && mix test"
echo "- Database console: cd backend_elixir && mix ecto.reset"
echo ""
print_success "Happy coding with Elixir + Phoenix! 🚀"