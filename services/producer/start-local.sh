#!/bin/bash
# Start IoT Usage Logger locally with correct Kafka configuration

echo "🚀 Starting IoT Usage Logger (Producer)"
echo "========================================"
echo ""

# Set Kafka broker to localhost:29092 (host-accessible port)
export KAFKA_BROKER=localhost:29092
export PORT=3000

echo "Configuration:"
echo "  KAFKA_BROKER: $KAFKA_BROKER"
echo "  PORT: $PORT"
echo ""

# Check if Kafka is accessible
echo "🔍 Checking Kafka connectivity..."
if nc -z localhost 29092 2>/dev/null; then
    echo "✅ Kafka is accessible at localhost:29092"
else
    echo "❌ Cannot connect to Kafka at localhost:29092"
    echo ""
    echo "Make sure Kafka is running:"
    echo "  podman-compose up -d"
    echo ""
    exit 1
fi

echo ""
echo "📦 Installing dependencies (if needed)..."
npm install

echo ""
echo "🎯 Starting application..."
echo ""
npm run dev

# Made with Bob
