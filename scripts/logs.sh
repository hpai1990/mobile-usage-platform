#!/bin/bash
# View logs for Mobile Usage Platform services

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "📋 Viewing logs for all services..."
    echo "   Press Ctrl+C to stop"
    echo ""
    podman-compose logs -f
else
    echo "📋 Viewing logs for $SERVICE..."
    echo "   Press Ctrl+C to stop"
    echo ""
    podman-compose logs -f "$SERVICE"
fi

# Made with Bob
