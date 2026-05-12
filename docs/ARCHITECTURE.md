# Mobile Usage Platform - Architecture

## Overview

The Mobile Usage Platform is a distributed system for tracking mobile data usage and calculating billing in real-time. It consists of two main services connected via Apache Kafka.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Mobile Usage Platform                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐      ┌─────────────┐      ┌──────────────────┐
│   Producer      │      │   Kafka     │      │   Consumer       │
│   Service       │─────▶│   Cluster   │─────▶│   Service        │
│                 │      │             │      │                  │
│  TypeScript/    │      │ Zookeeper + │      │  Python          │
│  Node.js        │      │ Kafka       │      │  confluent-kafka │
│  Express API    │      │             │      │                  │
└─────────────────┘      └─────────────┘      └──────────────────┘
        │                                               │
        ▼                                               ▼
┌─────────────────┐                          ┌──────────────────┐
│   SQLite DB     │                          │  In-Memory       │
│   (Persistent)  │                          │  Aggregation     │
│                 │                          │                  │
│  - usage data   │                          │  - per device    │
│  - timestamps   │                          │  - billing calc  │
│  - package info │                          │  - statistics    │
└─────────────────┘                          └──────────────────┘
```

## Components

### 1. Producer Service (TypeScript/Node.js)

**Purpose**: REST API for receiving and storing mobile usage data

**Technology Stack**:
- Node.js 20
- TypeScript
- Express.js
- SQLite (better-sqlite3)
- KafkaJS

**Responsibilities**:
- Accept HTTP POST requests with usage data
- Validate input data
- Store data in SQLite database
- Publish events to Kafka topic
- Provide query endpoints for historical data
- Generate usage statistics

**API Endpoints**:
- `POST /mobile-usage` - Submit usage data
- `GET /mobile-usage` - Query usage data (with filters)
- `GET /mobile-usage/device/:id` - Device-specific usage
- `GET /mobile-usage/package/:type` - Package-specific usage
- `GET /mobile-usage/stats` - Usage statistics
- `DELETE /mobile-usage/:id` - Delete record
- `GET /health` - Health check

**Database Schema**:
```sql
CREATE TABLE mobile_usage (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  usage REAL NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  package_type TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

### 2. Consumer Service (Python)

**Purpose**: Real-time billing calculation and aggregation

**Technology Stack**:
- Python 3.11
- confluent-kafka
- Threading for periodic reporting

**Responsibilities**:
- Consume events from Kafka topic
- Aggregate usage per device in memory
- Calculate billing ($0.10 per MB)
- Generate periodic billing reports (every 10 seconds)
- Track usage statistics

**Data Structures**:
```python
device_usage = {
    'device_id': {
        'total_usage_mb': float,
        'total_cost': float,
        'event_count': int,
        'first_seen': str,
        'last_seen': str
    }
}
```

### 3. Kafka Infrastructure

**Components**:
- **Zookeeper**: Cluster coordination
- **Kafka Broker**: Message streaming

**Topic Configuration**:
- **Name**: `mobile-usage`
- **Partitions**: 1 (single broker setup)
- **Replication Factor**: 1
- **Auto-create**: Enabled

**Message Format**:
```json
{
  "device_id": "device-123",
  "usage": 150.5,
  "start_time": "2026-05-12T10:00:00Z",
  "end_time": "2026-05-12T10:05:00Z"
}
```

## Data Flow

### 1. Usage Data Submission

```
Client → POST /mobile-usage → Producer Service
                                    ↓
                              Validate Input
                                    ↓
                              Save to SQLite
                                    ↓
                              Publish to Kafka
                                    ↓
                              Return Response
```

### 2. Real-time Processing

```
Kafka Topic → Consumer Service
                    ↓
              Parse Message
                    ↓
              Update Aggregation
                    ↓
              Calculate Billing
                    ↓
              (Every 10s) Generate Report
```

### 3. Query Flow

```
Client → GET /mobile-usage → Producer Service
                                    ↓
                              Query SQLite
                                    ↓
                              Apply Filters
                                    ↓
                              Return Results
```

## Network Architecture

### Container Network

All services run in a single Podman network: `mobile-usage-network`

**Internal Communication**:
- Producer → Kafka: `kafka:9092`
- Consumer → Kafka: `kafka:9092`
- Kafka → Zookeeper: `zookeeper:2181`

**External Access**:
- Producer API: `localhost:3000`
- Kafka (external): `localhost:29092`
- Zookeeper: `localhost:2181`

### Port Mapping

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|---------|
| Producer | 3000 | 3000 | REST API |
| Kafka | 9092 | 9092 | Internal clients |
| Kafka | 29092 | 29092 | External clients |
| Zookeeper | 2181 | 2181 | Coordination |

## Storage

### Producer Storage

**Volume**: `producer-db`
- **Type**: Podman volume
- **Mount**: `/app` in container
- **Contents**: SQLite database files
- **Persistence**: Data survives container restarts

### Consumer Storage

**Type**: In-memory only
- No persistent storage
- Data lost on restart
- Suitable for real-time aggregation
- Can be extended with database if needed

## Scalability Considerations

### Current Setup (Single Instance)

- Single Kafka broker
- Single producer instance
- Single consumer instance
- Suitable for development and small-scale production

### Scaling Options

**Horizontal Scaling**:
1. **Multiple Producers**:
   - Add load balancer
   - Share SQLite via network storage or use PostgreSQL
   - Each instance publishes to same Kafka topic

2. **Multiple Consumers**:
   - Use same consumer group ID
   - Kafka automatically distributes partitions
   - Each consumer processes subset of messages

3. **Kafka Cluster**:
   - Add more Kafka brokers
   - Increase topic partitions
   - Increase replication factor

**Vertical Scaling**:
- Increase container resources (CPU, memory)
- Optimize database queries
- Add caching layer (Redis)

## Monitoring & Observability

### Health Checks

**Producer**:
- HTTP endpoint: `GET /health`
- Checks: Database connection, Kafka connection
- Interval: 30 seconds

**Kafka**:
- Command: `kafka-broker-api-versions`
- Interval: 10 seconds

**Consumer**:
- Logs: Periodic billing reports
- Metrics: Events processed, devices tracked

### Logging

**Producer**:
- Request/response logs
- Database operations
- Kafka publish events
- Error logs

**Consumer**:
- Message consumption logs
- Billing reports (every 10 seconds)
- Aggregation statistics
- Error logs

## Security Considerations

### Current Implementation

- No authentication on REST API
- No Kafka authentication
- No encryption in transit
- Suitable for development/internal use

### Production Recommendations

1. **API Security**:
   - Add API key authentication
   - Implement rate limiting
   - Use HTTPS/TLS

2. **Kafka Security**:
   - Enable SASL authentication
   - Enable SSL/TLS encryption
   - Configure ACLs

3. **Network Security**:
   - Use private networks
   - Implement firewall rules
   - Restrict external access

4. **Data Security**:
   - Encrypt sensitive data
   - Implement data retention policies
   - Add audit logging

## Failure Handling

### Producer Failures

**Kafka Unavailable**:
- API continues to work
- Data saved to SQLite
- Kafka messages skipped with warning
- Automatic reconnection attempts

**Database Failures**:
- API returns 500 error
- Kafka messages still published
- Manual intervention required

### Consumer Failures

**Kafka Unavailable**:
- Consumer retries connection
- Exponential backoff
- Logs errors

**Processing Errors**:
- Invalid messages logged and skipped
- Consumer continues processing
- No impact on other messages

### Recovery

**Producer Recovery**:
- Restart container
- Database persists
- Kafka reconnects automatically

**Consumer Recovery**:
- Restart container
- Resumes from last committed offset
- In-memory data lost (by design)

## Performance Characteristics

### Producer

- **Throughput**: ~1000 requests/second (single instance)
- **Latency**: <50ms (p95)
- **Database**: SQLite suitable for <10k writes/second

### Consumer

- **Throughput**: ~5000 messages/second
- **Latency**: <10ms processing time
- **Memory**: ~100MB base + ~1KB per device

### Kafka

- **Throughput**: ~100k messages/second (single broker)
- **Latency**: <10ms (p99)
- **Storage**: Configurable retention

## Future Enhancements

1. **Database Migration**:
   - PostgreSQL for better concurrency
   - TimescaleDB for time-series data

2. **Caching Layer**:
   - Redis for frequently accessed data
   - Reduce database load

3. **Message Queue**:
   - Add dead letter queue
   - Retry failed messages

4. **Analytics**:
   - Real-time dashboards
   - Historical trend analysis
   - Predictive billing

5. **Microservices**:
   - Separate billing service
   - Notification service
   - Reporting service

---

**Last Updated**: 2026-05-12  
**Version**: 1.0.0