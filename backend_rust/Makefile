# Rust Backend Makefile for Location Sharing Application

.PHONY: help build test run clean docker-up docker-down migrate format lint check-fmt check-clippy ci

# Default target
help:
	@echo "Available commands:"
	@echo "  build         - Build all binaries"
	@echo "  test          - Run all tests"
	@echo "  run-api       - Run API server"
	@echo "  run-ws        - Run WebSocket server"
	@echo "  run-all       - Run both servers concurrently"
	@echo "  clean         - Clean build artifacts"
	@echo "  docker-up     - Start infrastructure with Docker"
	@echo "  docker-down   - Stop Docker containers"
	@echo "  docker-build  - Build application Docker images"
	@echo "  docker-run    - Run full application with Docker"
	@echo "  migrate       - Run database migrations"
	@echo "  format        - Format code with rustfmt"
	@echo "  lint          - Run clippy linter"
	@echo "  check-fmt     - Check code formatting"
	@echo "  check-clippy  - Check clippy warnings"
	@echo "  ci            - Run all CI checks"

# Build commands
build:
	cargo build --release

build-debug:
	cargo build

# Test commands
test:
	cargo test

test-verbose:
	cargo test -- --nocapture

# Run commands
run-api:
	cargo run --bin api-server

run-ws:
	cargo run --bin websocket-server

run-all:
	@echo "Starting API server and WebSocket server..."
	@trap 'kill %1 %2' INT; \
	cargo run --bin api-server & \
	cargo run --bin websocket-server & \
	wait

# Development environment
dev-deps:
	@command -v sqlx >/dev/null 2>&1 || cargo install sqlx-cli
	@command -v cargo-watch >/dev/null 2>&1 || cargo install cargo-watch

dev-api: dev-deps
	cargo watch -x "run --bin api-server"

dev-ws: dev-deps
	cargo watch -x "run --bin websocket-server"

# Database commands
migrate:
	sqlx migrate run --database-url $(DATABASE_URL)

migrate-revert:
	sqlx migrate revert --database-url $(DATABASE_URL)

migrate-info:
	sqlx migrate info --database-url $(DATABASE_URL)

# Docker commands
docker-up:
	docker-compose up -d postgres redis

docker-down:
	docker-compose down

docker-build:
	docker-compose build

docker-run:
	docker-compose up -d

docker-logs:
	docker-compose logs -f api-server websocket-server

docker-clean:
	docker-compose down -v
	docker system prune -f

# Code quality commands
format:
	cargo fmt

check-fmt:
	cargo fmt --check

lint:
	cargo clippy -- -D warnings

check-clippy:
	cargo clippy --all-targets --all-features -- -D warnings

check:
	cargo check --all-targets --all-features

# Environment setup
setup-env:
	@if [ ! -f .env ]; then \
		echo "Creating .env file from .env.example..."; \
		cp .env.example .env; \
		echo "Please edit .env file with your configuration"; \
	else \
		echo ".env file already exists"; \
	fi

# Database setup for development
setup-db:
	@echo "Setting up development database..."
	@if [ -z "$(DATABASE_URL)" ]; then \
		echo "ERROR: DATABASE_URL environment variable not set"; \
		echo "Please set it or source .env file"; \
		exit 1; \
	fi
	sqlx database create
	sqlx migrate run

# Clean commands
clean:
	cargo clean

clean-all: clean docker-clean
	rm -rf target/

# CI commands (run all checks)
ci: check-fmt check-clippy test
	@echo "All CI checks passed!"

# Production build
build-release:
	cargo build --release --locked

# Security audit
audit:
	@command -v cargo-audit >/dev/null 2>&1 || cargo install cargo-audit
	cargo audit

# Generate documentation
docs:
	cargo doc --no-deps --open

# Benchmarks (if any)
bench:
	cargo bench

# Coverage (requires cargo-tarpaulin)
coverage:
	@command -v cargo-tarpaulin >/dev/null 2>&1 || cargo install cargo-tarpaulin
	cargo tarpaulin --out Html

# Install development tools
install-tools:
	cargo install sqlx-cli cargo-watch cargo-audit cargo-tarpaulin

# Full development setup
setup: install-tools setup-env docker-up
	@echo "Waiting for services to start..."
	@sleep 5
	@make setup-db
	@echo "Development environment setup complete!"
	@echo "Run 'make run-all' to start both servers"

# Quick start for new developers
quickstart: setup
	@echo "🚀 Quick start complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit .env file if needed"
	@echo "2. Run 'make run-all' to start both servers"
	@echo "3. API server will be available at http://localhost:8080"
	@echo "4. WebSocket server will be available at ws://localhost:8081"
	@echo ""
	@echo "Useful commands:"
	@echo "- make test          # Run tests"
	@echo "- make docker-logs   # View application logs"
	@echo "- make help          # Show all available commands"