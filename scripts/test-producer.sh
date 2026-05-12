#!/bin/bash
# Test the Mobile Usage Platform producer API

set -e

echo "🧪 Testing Mobile Usage Platform Producer API"
echo ""

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq not found. Install it for better output formatting."
    echo "   On macOS: brew install jq"
    echo ""
fi

# Test 1: Health Check
echo "1️⃣  Testing Health Check..."
curl -s http://localhost:3000/health | jq 2>/dev/null || curl -s http://localhost:3000/health
echo ""
echo ""

# Test 2: Submit Usage Data
echo "2️⃣  Submitting Test Usage Data..."
curl -s -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-001",
    "usage": 150.5,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }' | jq 2>/dev/null || curl -s -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-001",
    "usage": 150.5,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }'
echo ""
echo ""

# Test 3: Query Usage Data
echo "3️⃣  Querying Usage Data..."
curl -s "http://localhost:3000/mobile-usage?limit=5" | jq 2>/dev/null || curl -s "http://localhost:3000/mobile-usage?limit=5"
echo ""
echo ""

# Test 4: Get Statistics
echo "4️⃣  Getting Usage Statistics..."
curl -s http://localhost:3000/mobile-usage/stats | jq 2>/dev/null || curl -s http://localhost:3000/mobile-usage/stats
echo ""
echo ""

echo "✅ All tests completed!"
echo ""
echo "💡 View consumer billing reports:"
echo "   podman-compose logs -f consumer"
echo ""

# Made with Bob
