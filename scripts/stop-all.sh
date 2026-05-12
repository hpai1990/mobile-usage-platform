#!/bin/bash
# Stop all Mobile Usage Platform services

set -e

echo "🛑 Stopping Mobile Usage Platform..."
echo ""

# Stop all services
podman-compose down

echo ""
echo "✅ All services stopped successfully!"
echo ""
echo "💡 To remove volumes (deletes all data):"
echo "   podman-compose down -v"
echo ""

# Made with Bob
