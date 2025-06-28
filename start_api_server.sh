#!/bin/bash
echo "🚀 Starting Rust API Server on port 8000..."
echo "Press Ctrl+C to stop"
cd backend_rust
RUST_LOG=info cargo run --bin api-server
