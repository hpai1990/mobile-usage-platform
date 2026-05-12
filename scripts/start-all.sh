#!/bin/bash
# Start all Mobile Usage Platform services with Podman Compose

set -e

echo "🚀 Starting Mobile Usage Platform..."
echo ""

# Start all services
podman-compose up -d

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 5

# Check service status
echo ""
echo "📊 Service Status:"
podman-compose ps

echo ""
echo "✅ Services started successfully!"
echo ""
echo "📚 Quick Links:"
echo "  - API Health: http://localhost:3000/health"
echo "  - API Docs: http://localhost:3000/mobile-usage"
echo "  - View Logs: podman-compose logs -f"
echo ""
echo "🧪 Test the API:"
echo "  curl http://localhost:3000/health"
echo ""
echo "📝 View billing reports:"
echo "  podman-compose logs -f consumer"
echo ""

# Made with Bob
