#!/bin/bash

# Script to create the monorepo structure for mobile-usage-platform
# This combines iot-usage-kafka-logger and fixium-mobile-consumer

set -e

echo "🚀 Creating Mobile Usage Platform Monorepo"
echo "=========================================="

# Configuration
MONOREPO_NAME="mobile-usage-platform"
CURRENT_DIR=$(pwd)
IOT_REPO_PATH="$CURRENT_DIR"
CONSUMER_REPO_PATH="$CURRENT_DIR/../fixium-mobile-consumer"

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -f "index.ts" ]; then
    echo "❌ Error: Please run this script from the iot-usage-kafka-logger directory"
    exit 1
fi

# Check if consumer repo exists
if [ ! -d "$CONSUMER_REPO_PATH" ]; then
    echo "❌ Error: Consumer repository not found at $CONSUMER_REPO_PATH"
    echo "Please adjust CONSUMER_REPO_PATH in the script"
    exit 1
fi

# Create monorepo directory
MONOREPO_PATH="$CURRENT_DIR/../$MONOREPO_NAME"

if [ -d "$MONOREPO_PATH" ]; then
    echo "⚠️  Warning: $MONOREPO_NAME directory already exists"
    read -p "Do you want to remove it and continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$MONOREPO_PATH"
    else
        echo "❌ Aborted"
        exit 1
    fi
fi

echo "📁 Creating monorepo structure..."
mkdir -p "$MONOREPO_PATH"
cd "$MONOREPO_PATH"

# Create directory structure
mkdir -p services/producer
mkdir -p services/consumer
mkdir -p infrastructure/kafka
mkdir -p infrastructure/neo4j
mkdir -p docs/knowledge-graph
mkdir -p scripts
mkdir -p tests/integration
mkdir -p tests/e2e

echo "✅ Directory structure created"

# Copy producer code
echo "📦 Copying producer code..."
cp -r "$IOT_REPO_PATH"/* services/producer/ 2>/dev/null || true
# Remove monorepo-specific files from producer
rm -f services/producer/create-monorepo.sh
rm -f services/producer/MONOREPO_MIGRATION_PLAN.md

echo "✅ Producer code copied"

# Copy consumer code
echo "📦 Copying consumer code..."
cp -r "$CONSUMER_REPO_PATH"/* services/consumer/ 2>/dev/null || true

echo "✅ Consumer code copied"

# Move infrastructure files
echo "🔧 Organizing infrastructure files..."

# Move Neo4j files
if [ -f "services/producer/docker-compose.neo4j.yml" ]; then
    mv services/producer/docker-compose.neo4j.yml infrastructure/neo4j/
fi
if [ -f "services/producer/init-graph.cypher" ]; then
    mv services/producer/init-graph.cypher infrastructure/neo4j/
fi
if [ -f "services/producer/load-graph.sh" ]; then
    mv services/producer/load-graph.sh infrastructure/neo4j/
fi
if [ -f "services/producer/NEO4J_QUICKSTART.md" ]; then
    mv services/producer/NEO4J_QUICKSTART.md docs/knowledge-graph/
fi
if [ -f "services/producer/TESTING_NEO4J.md" ]; then
    mv services/producer/TESTING_NEO4J.md docs/knowledge-graph/
fi
if [ -f "services/producer/kafka-messaging-knowledge-graph-schema.json" ]; then
    mv services/producer/kafka-messaging-knowledge-graph-schema.json docs/knowledge-graph/schema.json
fi

echo "✅ Infrastructure files organized"

# Move documentation
echo "📚 Organizing documentation..."
if [ -f "services/producer/README.md" ]; then
    cp services/producer/README.md docs/PRODUCER.md
fi
if [ -f "services/consumer/README.md" ]; then
    cp services/consumer/README.md docs/CONSUMER.md
fi

echo "✅ Documentation organized"

# Create root package.json
echo "📝 Creating root package.json..."
cat > package.json << 'EOF'
{
  "name": "mobile-usage-platform",
  "version": "1.0.0",
  "description": "Mobile Usage Data Platform - Producer and Consumer Services",
  "private": true,
  "workspaces": [
    "services/producer"
  ],
  "scripts": {
    "start:producer": "cd services/producer && npm start",
    "start:consumer": "cd services/consumer && python consumer/billing_consumer.py",
    "dev:producer": "cd services/producer && npm run dev",
    "build:producer": "cd services/producer && npm run build",
    "test": "echo \"Run integration tests\"",
    "docker:up": "docker-compose up -d",
    "docker:down": "docker-compose down",
    "docker:logs": "docker-compose logs -f",
    "setup": "./scripts/setup.sh",
    "start-all": "./scripts/start-all.sh",
    "stop-all": "./scripts/stop-all.sh"
  },
  "keywords": [
    "kafka",
    "iot",
    "mobile-usage",
    "billing",
    "microservices"
  ],
  "author": "",
  "license": "ISC"
}
EOF

echo "✅ Root package.json created"

# Create unified docker-compose.yml
echo "🐳 Creating unified docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "2181"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - mobile-usage-network

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    hostname: kafka
    container_name: kafka
    depends_on:
      zookeeper:
        condition: service_healthy
    ports:
      - "9092:9092"
      - "29092:29092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:29092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'
    healthcheck:
      test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"]
      interval: 10s
      timeout: 10s
      retries: 5
    networks:
      - mobile-usage-network

  producer:
    build:
      context: ./services/producer
      dockerfile: Dockerfile
    container_name: mobile-usage-producer
    depends_on:
      kafka:
        condition: service_healthy
    ports:
      - "3000:3000"
    environment:
      PORT: 3000
      KAFKA_BROKER: kafka:9092
      NODE_ENV: production
      SEED_DATABASE: "true"
    volumes:
      - producer-data:/app
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - mobile-usage-network

  consumer:
    build:
      context: ./services/consumer
      dockerfile: Dockerfile
    container_name: mobile-usage-consumer
    depends_on:
      kafka:
        condition: service_healthy
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_TOPIC: mobile-usage
      KAFKA_GROUP_ID: mobile-billing-consumer
    restart: unless-stopped
    networks:
      - mobile-usage-network

networks:
  mobile-usage-network:
    name: mobile-usage-network
    driver: bridge

volumes:
  producer-data:
    driver: local

# Made with Bob
EOF

echo "✅ Unified docker-compose.yml created"

# Create Makefile
echo "🔨 Creating Makefile..."
cat > Makefile << 'EOF'
.PHONY: help setup start stop restart logs clean test

help:
	@echo "Mobile Usage Platform - Available Commands:"
	@echo "  make setup      - Initial setup"
	@echo "  make start      - Start all services"
	@echo "  make stop       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make logs       - View logs"
	@echo "  make clean      - Clean up containers and volumes"
	@echo "  make test       - Run tests"

setup:
	@echo "Setting up Mobile Usage Platform..."
	@./scripts/setup.sh

start:
	@echo "Starting all services..."
	@docker-compose up -d
	@echo "Services started! Producer API: http://localhost:3000"

stop:
	@echo "Stopping all services..."
	@docker-compose down

restart:
	@echo "Restarting all services..."
	@docker-compose restart

logs:
	@docker-compose logs -f

clean:
	@echo "Cleaning up..."
	@docker-compose down -v
	@echo "Cleanup complete!"

test:
	@echo "Running tests..."
	@./scripts/test-producer.sh
	@./scripts/test-consumer.sh

# Made with Bob
EOF

echo "✅ Makefile created"

# Create setup script
echo "📝 Creating setup script..."
cat > scripts/setup.sh << 'EOF'
#!/bin/bash

echo "🔧 Setting up Mobile Usage Platform..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1 || {
    echo "❌ Docker or Podman is required but not installed."
    exit 1
}

command -v docker-compose >/dev/null 2>&1 || command -v podman-compose >/dev/null 2>&1 || {
    echo "❌ Docker Compose or Podman Compose is required but not installed."
    exit 1
}

# Install producer dependencies
echo "📦 Installing producer dependencies..."
cd services/producer && npm install && cd ../..

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start services: make start"
echo "  2. View logs: make logs"
echo "  3. Test producer: curl http://localhost:3000/health"

# Made with Bob
EOF

chmod +x scripts/setup.sh

echo "✅ Setup script created"

# Create start-all script
cat > scripts/start-all.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Mobile Usage Platform..."
docker-compose up -d

echo ""
echo "✅ All services started!"
echo ""
echo "Services:"
echo "  - Producer API: http://localhost:3000"
echo "  - Kafka: localhost:29092"
echo "  - Zookeeper: localhost:2181"
echo ""
echo "View logs: docker-compose logs -f"

# Made with Bob
EOF

chmod +x scripts/start-all.sh

# Create stop-all script
cat > scripts/stop-all.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Mobile Usage Platform..."
docker-compose down

echo "✅ All services stopped!"

# Made with Bob
EOF

chmod +x scripts/stop-all.sh

# Create test scripts
cat > scripts/test-producer.sh << 'EOF'
#!/bin/bash

echo "🧪 Testing Producer API..."

# Wait for producer to be ready
echo "Waiting for producer to be ready..."
sleep 5

# Test health endpoint
echo "Testing /health endpoint..."
curl -s http://localhost:3000/health | jq .

# Test POST endpoint
echo ""
echo "Testing POST /mobile-usage endpoint..."
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-001",
    "usage": 100.5,
    "start_time": "2026-05-12T10:00:00.000Z",
    "end_time": "2026-05-12T11:00:00.000Z",
    "package_type": "prepaid"
  }' | jq .

echo ""
echo "✅ Producer tests complete!"

# Made with Bob
EOF

chmod +x scripts/test-producer.sh

cat > scripts/test-consumer.sh << 'EOF'
#!/bin/bash

echo "🧪 Testing Consumer..."

# Check if consumer is running
if docker ps | grep -q mobile-usage-consumer; then
    echo "✅ Consumer is running"
    echo "Viewing consumer logs (last 20 lines):"
    docker logs --tail 20 mobile-usage-consumer
else
    echo "❌ Consumer is not running"
    exit 1
fi

# Made with Bob
EOF

chmod +x scripts/test-consumer.sh

# Create main README
echo "📖 Creating main README..."
cat > README.md << 'EOF'
# Mobile Usage Platform

A complete platform for mobile data usage tracking and billing, consisting of a producer service (REST API) and a consumer service (billing processor).

## Architecture

```
┌─────────────┐      ┌─────────────┐      ┌──────────────────┐
│  Producer   │─────▶│   Kafka     │─────▶│  Consumer        │
│  (REST API) │      │   Topic     │      │  (Billing)       │
└─────────────┘      └─────────────┘      └──────────────────┘
       │                                            │
       ▼                                            ▼
┌─────────────┐                            ┌──────────────────┐
│   SQLite    │                            │  In-Memory       │
│   Database  │                            │  Aggregation     │
└─────────────┘                            └──────────────────┘
```

## Services

### Producer (TypeScript/Express)
- REST API for mobile usage data ingestion
- SQLite database for persistence
- Kafka producer for event streaming
- Port: 3000

### Consumer (Python)
- Kafka consumer for usage events
- Real-time billing calculation
- In-memory aggregation
- Periodic billing reports

## Quick Start

### Prerequisites
- Docker or Podman
- Docker Compose or Podman Compose
- Node.js 20+ (for local development)
- Python 3.11+ (for local development)

### Start All Services

```bash
# Setup (first time only)
make setup

# Start all services
make start

# View logs
make logs

# Stop all services
make stop
```

### Manual Start

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Testing

```bash
# Test producer
make test

# Or manually
./scripts/test-producer.sh
./scripts/test-consumer.sh
```

## API Endpoints

### Producer API (http://localhost:3000)

- `POST /mobile-usage` - Submit usage data
- `GET /mobile-usage` - Retrieve usage data
- `GET /mobile-usage/device/:device_id` - Get usage by device
- `GET /mobile-usage/stats` - Get statistics
- `GET /health` - Health check

## Documentation

- [Producer Documentation](docs/PRODUCER.md)
- [Consumer Documentation](docs/CONSUMER.md)
- [Knowledge Graph](docs/knowledge-graph/)
- [Architecture](docs/ARCHITECTURE.md)

## Development

### Producer Development

```bash
cd services/producer
npm install
npm run dev
```

### Consumer Development

```bash
cd services/consumer
pip install -r requirements.txt
python consumer/billing_consumer.py
```

## Knowledge Graph

This platform includes a Neo4j knowledge graph for system documentation and impact analysis.

See [docs/knowledge-graph/](docs/knowledge-graph/) for details.

## License

ISC

---

**Made with Bob** 🤖
EOF

echo "✅ Main README created"

# Create .gitignore
cat > .gitignore << 'EOF'
# Node
node_modules/
npm-debug.log
package-lock.json

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
ENV/

# Database
*.db
*.db-shm
*.db-wal

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Docker
.docker/

# Logs
*.log
logs/

# Environment
.env
.env.local

# Made with Bob
EOF

echo "✅ .gitignore created"

# Summary
echo ""
echo "=========================================="
echo "✅ Monorepo created successfully!"
echo "=========================================="
echo ""
echo "Location: $MONOREPO_PATH"
echo ""
echo "Next steps:"
echo "  1. cd $MONOREPO_PATH"
echo "  2. make setup"
echo "  3. make start"
echo "  4. make test"
echo ""
echo "Documentation: $MONOREPO_PATH/README.md"
echo ""

# Made with Bob