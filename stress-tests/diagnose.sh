#!/bin/bash

echo "🔍 Quick WebSocket Diagnosis"
echo ""

echo "1️⃣ Testing API endpoints..."
echo "Rust API health:"
curl -s http://localhost:8000/health | jq -r '.status // "ERROR"'

echo "Elixir API health:"
curl -s http://localhost:4000/health | jq -r '.status // "ERROR"'

echo ""
echo "2️⃣ Testing WebSocket upgrade manually..."
echo "Rust WebSocket (should show upgrade headers):"
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  http://localhost:8001/ws?token=test 2>/dev/null | head -10

echo ""
echo "3️⃣ Current service status:"
docker-compose -f docker-compose.test.yml ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"