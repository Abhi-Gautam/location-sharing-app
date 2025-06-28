#!/bin/bash
echo "🚀 Starting Rust WebSocket Server on port 8001..."
echo "Press Ctrl+C to stop"
cd backend_rust
RUST_LOG=info cargo run --bin websocket-server
