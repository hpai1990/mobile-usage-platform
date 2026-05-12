# Mobile Usage Platform

A unified platform for mobile data usage tracking, logging, and billing. This monorepo combines a TypeScript/Node.js producer API with a Python Kafka consumer for real-time usage monitoring and billing calculations.

## 🏗️ Architecture

```
┌─────────────────┐      ┌─────────────┐      ┌──────────────────┐
│   REST API      │─────▶│   Kafka     │─────▶│  Billing         │
│   (Producer)    │      │   Broker    │      │  Consumer        │
│   TypeScript    │      │             │      │  Python          │
└─────────────────┘      └─────────────┘      └──────────────────┘
        │                                               │
        ▼                                               ▼
┌─────────────────┐                          ┌──────────────────┐
│   SQLite DB     │                          │  In-Memory       │
│   (Persistent)  │                          │  Aggregation     │
└─────────────────┘                          └──────────────────┘
```

## 📦 Services

### Producer (TypeScript/Node.js)
- **Location**: `services/producer/`
- **Port**: 3000
- **Purpose**: REST API for receiving and storing mobile usage data
- **Features**:
  - SQLite database for persistent storage
  - Kafka producer for real-time streaming
  - Input validation and error handling
  - Usage statistics and analytics endpoints

### Consumer (Python)
- **Location**: `services/consumer/`
- **Purpose**: Kafka consumer for billing calculations
- **Features**:
  - Real-time usage aggregation
  - Billing calculations ($0.10 per MB)
  - Periodic billing reports (every 10 seconds)
  - Device-level usage tracking

## 🚀 Quick Start

### Prerequisites
- Podman and podman-compose installed
- 8GB RAM recommended
- Ports 3000, 9092, 29092, 2181 available

### Start All Services

```bash
# Start the entire platform
podman-compose up -d

# View logs
podman-compose logs -f

# View specific service logs
podman-compose logs -f producer
podman-compose logs -f consumer
```

### Test the Platform

```bash
# Check health
curl http://localhost:3000/health

# Send test usage data
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-001",
    "usage": 150.5,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }'

# View billing reports in consumer logs
podman-compose logs -f consumer
```

### Stop All Services

```bash
podman-compose down
```

## 📚 API Endpoints

### Producer API (Port 3000)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/mobile-usage` | Submit usage data |
| GET | `/mobile-usage` | Retrieve all usage data (with filters) |
| GET | `/mobile-usage/device/:device_id` | Get usage by device |
| GET | `/mobile-usage/package/:package_type` | Get usage by package type |
| GET | `/mobile-usage/stats` | Get usage statistics |
| DELETE | `/mobile-usage/:id` | Delete a usage record |
| GET | `/health` | Health check |

### Example Request

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-123",
    "usage": 1024.5,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T11:00:00Z",
    "package_type": "prepaid"
  }'
```

## 🛠️ Development

### Project Structure

```
mobile-usage-platform/
├── services/
│   ├── producer/          # TypeScript REST API
│   │   ├── src/
│   │   ├── index.ts
│   │   ├── package.json
│   │   └── Dockerfile
│   └── consumer/          # Python Kafka consumer
│       ├── consumer/
│       ├── requirements.txt
│       └── Dockerfile
├── docs/                  # Documentation
├── scripts/               # Utility scripts
├── docker-compose.yml     # Podman orchestration
└── README.md             # This file
```

### Useful Commands

```bash
# Rebuild services
podman-compose build

# Restart a specific service
podman-compose restart producer

# Check service status
podman-compose ps

# Execute command in container
podman exec -it kafka bash

# View Kafka topics
podman exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# View consumer group status
podman exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe --group mobile-billing-consumer
```

## 📊 Monitoring

### Health Checks

```bash
# Producer health
curl http://localhost:3000/health

# Check all services
podman-compose ps

# View resource usage
podman stats
```

### Logs

```bash
# All services
podman-compose logs -f

# Specific service
podman-compose logs -f producer
podman-compose logs -f consumer
podman-compose logs -f kafka

# Last 100 lines
podman-compose logs --tail=100 consumer
```

## 🔧 Configuration

### Environment Variables

#### Producer
- `PORT`: API port (default: 3000)
- `KAFKA_BROKER`: Kafka broker address (default: kafka:9092)
- `NODE_ENV`: Environment (production/development)
- `SEED_DATABASE`: Auto-seed database (true/false)

#### Consumer
- `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker address
- `KAFKA_TOPIC`: Topic to consume (default: mobile-usage)
- `KAFKA_GROUP_ID`: Consumer group ID

### Volumes

- `producer-db`: SQLite database persistence

### Networks

- `mobile-usage-network`: Internal network for service communication

## 📖 Documentation

- [Architecture Details](docs/ARCHITECTURE.md)
- [Quick Start Guide](docs/QUICKSTART.md)
- [Testing Guide](docs/TESTING.md)
- [Producer README](services/producer/README.md)
- [Consumer README](services/consumer/README.md)

## 🐛 Troubleshooting

### Services won't start

```bash
# Check Podman status
podman ps -a

# View logs
podman-compose logs

# Rebuild from scratch
podman-compose down -v
podman-compose build --no-cache
podman-compose up -d
```

### Kafka connection issues

```bash
# Check Kafka health
podman exec kafka kafka-broker-api-versions \
  --bootstrap-server localhost:9092

# Check network
podman network inspect mobile-usage-network
```

### Database issues

```bash
# Check volume
podman volume inspect mobile-usage-platform_producer-db

# Reset database (WARNING: deletes all data)
podman-compose down -v
podman-compose up -d
```

## 🤝 Contributing

1. Make changes in the appropriate service directory
2. Test locally with `podman-compose up`
3. Update documentation if needed
4. Submit pull request

## 📝 License

ISC

## 🙏 Acknowledgments

Built with:
- Node.js & TypeScript
- Python
- Apache Kafka
- SQLite
- Podman

---

**Made with Bob** 🤖