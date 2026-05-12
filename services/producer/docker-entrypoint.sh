#!/bin/bash
set -e

echo "🚀 Starting IoT Usage Kafka Logger..."

# Note: Database will be automatically initialized on first run
# Seeding can be done manually if needed: npm run seed

# Start the application
echo "🎯 Starting application..."
exec npm start

# Made with Bob
