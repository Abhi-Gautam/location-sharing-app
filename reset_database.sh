#!/bin/bash

echo "🔄 Resetting database to fix column type mismatch..."

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Stopping any existing database connections..."
# Kill any existing connections to the database
docker exec location_sharing_postgres psql -U dev -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'location_sharing' AND pid <> pg_backend_pid();" 2>/dev/null || true

print_status "Dropping and recreating database..."
docker exec location_sharing_postgres psql -U dev -d postgres -c "DROP DATABASE IF EXISTS location_sharing;"
docker exec location_sharing_postgres psql -U dev -d postgres -c "CREATE DATABASE location_sharing;"

print_status "Running migrations..."
cd backend_rust

# Check if sqlx-cli is installed
if ! command -v sqlx &> /dev/null; then
    print_status "Installing sqlx-cli..."
    cargo install sqlx-cli --no-default-features --features native-tls,postgres
fi

# Run migrations
export DATABASE_URL="postgresql://dev:dev123@localhost:5432/location_sharing"
sqlx migrate run --source ./migrations

if [ $? -eq 0 ]; then
    print_success "Database reset completed successfully!"
    print_status "The column type mismatch should now be fixed."
    echo ""
    echo "You can now restart the API server:"
    echo "./start_api_server.sh"
else
    print_error "Migration failed. Please check the error above."
    exit 1
fi