# Mobile Usage Platform - Quick Start Guide

Get the Mobile Usage Platform up and running in 5 minutes!

## Prerequisites

### Required Software
- **Podman**: Container runtime
- **podman-compose**: Container orchestration
- **curl**: For testing API endpoints

### Installation Check

```bash
# Check Podman
podman --version
# Expected: podman version 4.0.0 or higher

# Check podman-compose
podman-compose --version
# Expected: podman-compose version 1.0.0 or higher

# Check curl
curl --version
# Expected: curl 7.x or higher
```

### System Requirements
- **RAM**: 4GB minimum, 8GB recommended
- **Disk**: 2GB free space
- **Ports**: 3000, 9092, 29092, 2181 must be available

## Step 1: Clone the Repository

```bash
cd ~/projects
git clone <repository-url> mobile-usage-platform
cd mobile-usage-platform
```

## Step 2: Start All Services

```bash
# Start all services in detached mode
podman-compose up -d
```

**Expected Output**:
```
Creating network "mobile-usage-network" with the default driver
Creating volume "mobile-usage-platform_producer-db" with default driver
Creating zookeeper ... done
Creating kafka ... done
Creating mobile-usage-producer ... done
Creating mobile-usage-consumer ... done
```

**Wait Time**: ~30-60 seconds for all services to be healthy

## Step 3: Verify Services

```bash
# Check all services are running
podman-compose ps
```

**Expected Output**:
```
NAME                    STATUS              PORTS
zookeeper               Up (healthy)        2181/tcp
kafka                   Up (healthy)        9092/tcp, 29092/tcp
mobile-usage-producer   Up (healthy)        0.0.0.0:3000->3000/tcp
mobile-usage-consumer   Up                  
```

## Step 4: Test the Producer API

### Health Check

```bash
curl http://localhost:3000/health
```

**Expected Response**:
```json
{
  "status": "healthy",
  "database": "connected",
  "kafka": "connected",
  "timestamp": "2026-05-12T12:00:00.000Z"
}
```

### Submit Usage Data

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-001",
    "usage": 150.5,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }'
```

**Expected Response**:
```json
{
  "message": "Mobile usage data received and stored successfully",
  "data": {
    "id": 1,
    "device_id": "device-001",
    "usage": 150.5,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid",
    "created_at": "2026-05-12T12:00:00.000Z"
  },
  "timestamp": "2026-05-12T12:00:00.000Z"
}
```

### Query Usage Data

```bash
curl http://localhost:3000/mobile-usage?limit=10
```

## Step 5: View Consumer Billing Reports

```bash
# View consumer logs (billing reports appear every 10 seconds)
podman-compose logs -f consumer
```

**Expected Output** (after ~10 seconds):
```
================================================================================
BILLING REPORT
================================================================================
Report Time: 2026-05-12T12:00:10.000Z

OVERALL STATISTICS:
  Total Events Processed: 1
  Total Usage: 150.50 MB
  Total Cost: $15.05
  Unique Devices: 1

TOP DEVICES BY COST:
  1. Device device-001: 150.50 MB, $15.05, 1 events
================================================================================
```

Press `Ctrl+C` to stop viewing logs.

## Step 6: Send More Test Data

```bash
# Send multiple usage records
for i in {1..5}; do
  curl -X POST http://localhost:3000/mobile-usage \
    -H "Content-Type: application/json" \
    -d "{
      \"device_id\": \"device-00$i\",
      \"usage\": $((100 + i * 50)),
      \"start_time\": \"2026-05-12T10:00:00Z\",
      \"end_time\": \"2026-05-12T10:05:00Z\",
      \"package_type\": \"prepaid\"
    }"
  echo ""
done
```

## Step 7: View Statistics

```bash
# Get usage statistics
curl http://localhost:3000/mobile-usage/stats
```

**Expected Response**:
```json
{
  "statistics": {
    "total_records": 6,
    "total_usage": 1050.50,
    "unique_devices": 6,
    "package_types": [
      { "package_type": "prepaid", "count": 6 }
    ]
  },
  "timestamp": "2026-05-12T12:00:00.000Z"
}
```

## Common Commands

### View Logs

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

### Restart Services

```bash
# Restart all
podman-compose restart

# Restart specific service
podman-compose restart producer
```

### Stop Services

```bash
# Stop all services
podman-compose down

# Stop and remove volumes (WARNING: deletes all data)
podman-compose down -v
```

### Rebuild Services

```bash
# Rebuild all services
podman-compose build

# Rebuild specific service
podman-compose build producer

# Rebuild without cache
podman-compose build --no-cache
```

## Troubleshooting

### Services Won't Start

**Problem**: Services fail to start or show unhealthy status

**Solution**:
```bash
# Check logs
podman-compose logs

# Check specific service
podman-compose logs kafka

# Restart services
podman-compose down
podman-compose up -d
```

### Port Already in Use

**Problem**: Error about port 3000, 9092, or 2181 already in use

**Solution**:
```bash
# Find process using port
lsof -i :3000
lsof -i :9092

# Kill process or change port in docker-compose.yml
```

### Kafka Connection Failed

**Problem**: Producer can't connect to Kafka

**Solution**:
```bash
# Wait for Kafka to be healthy (can take 30-60 seconds)
podman-compose ps

# Check Kafka health
podman exec kafka kafka-broker-api-versions \
  --bootstrap-server localhost:9092

# Restart if needed
podman-compose restart kafka
podman-compose restart producer
```

### Consumer Not Processing Messages

**Problem**: No billing reports appearing

**Solution**:
```bash
# Check consumer logs
podman-compose logs consumer

# Verify Kafka topic exists
podman exec kafka kafka-topics \
  --bootstrap-server localhost:9092 \
  --list

# Check consumer group
podman exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe --group mobile-billing-consumer
```

### Database Issues

**Problem**: Producer can't write to database

**Solution**:
```bash
# Check volume
podman volume inspect mobile-usage-platform_producer-db

# Reset database (WARNING: deletes all data)
podman-compose down -v
podman-compose up -d
```

## Next Steps

Now that you have the platform running:

1. **Explore the API**: Try different endpoints
   - Query by device: `GET /mobile-usage/device/device-001`
   - Query by package: `GET /mobile-usage/package/prepaid`
   - Get statistics: `GET /mobile-usage/stats`

2. **Read the Documentation**:
   - [Architecture](ARCHITECTURE.md) - System design details
   - [Testing Guide](TESTING.md) - Comprehensive testing
   - [Producer README](../services/producer/README.md) - API details
   - [Consumer README](../services/consumer/README.md) - Consumer details

3. **Customize Configuration**:
   - Edit `docker-compose.yml` for environment variables
   - Modify service configurations in respective directories

4. **Monitor the System**:
   - Watch logs: `podman-compose logs -f`
   - Check health: `curl http://localhost:3000/health`
   - View metrics: `podman stats`

## Quick Reference

| Task | Command |
|------|---------|
| Start all | `podman-compose up -d` |
| Stop all | `podman-compose down` |
| View logs | `podman-compose logs -f` |
| Check status | `podman-compose ps` |
| Restart | `podman-compose restart` |
| Rebuild | `podman-compose build` |
| Health check | `curl http://localhost:3000/health` |
| Submit data | `curl -X POST http://localhost:3000/mobile-usage -H "Content-Type: application/json" -d '{...}'` |
| View stats | `curl http://localhost:3000/mobile-usage/stats` |

## Support

If you encounter issues:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review logs: `podman-compose logs`
3. Check [ARCHITECTURE.md](ARCHITECTURE.md) for system details
4. Open an issue in the repository

---

**Congratulations!** 🎉 You now have a fully functional Mobile Usage Platform running locally.