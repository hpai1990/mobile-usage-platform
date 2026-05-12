# Mobile Usage Platform - Testing Guide

Comprehensive testing guide for the Mobile Usage Platform.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Unit Testing](#unit-testing)
- [Integration Testing](#integration-testing)
- [End-to-End Testing](#end-to-end-testing)
- [Performance Testing](#performance-testing)
- [Troubleshooting Tests](#troubleshooting-tests)

## Prerequisites

### Required Tools

```bash
# Verify installations
podman --version
podman-compose --version
curl --version
jq --version  # Optional, for JSON parsing
```

### Start the Platform

```bash
cd mobile-usage-platform
podman-compose up -d

# Wait for services to be healthy (~30-60 seconds)
podman-compose ps
```

## Integration Testing

### Test 1: Health Check

**Purpose**: Verify all services are running and healthy

```bash
# Test producer health
curl http://localhost:3000/health | jq

# Expected: status=healthy, database=connected, kafka=connected
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

### Test 2: Submit Single Usage Record

**Purpose**: Test basic data submission

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-001",
    "usage": 150.5,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }' | jq
```

**Validation**:
- Status code: 201
- Response contains `id`, `device_id`, `usage`, timestamps
- Check producer logs: `podman-compose logs producer | tail -20`
- Check consumer logs: `podman-compose logs consumer | tail -20`

### Test 3: Query Usage Data

**Purpose**: Test data retrieval

```bash
# Get all records
curl http://localhost:3000/mobile-usage?limit=10 | jq

# Get by device
curl http://localhost:3000/mobile-usage/device/test-device-001 | jq

# Get statistics
curl http://localhost:3000/mobile-usage/stats | jq
```

### Test 4: Input Validation

**Purpose**: Test error handling

```bash
# Missing required field
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-001",
    "usage": 150.5
  }' | jq

# Expected: 400 error with missing parameters message

# Invalid usage value
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-001",
    "usage": -100,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }' | jq

# Expected: 400 error about negative usage

# Invalid time range
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-device-001",
    "usage": 100,
    "start_time": "2026-05-12T11:00:00Z",
    "end_time": "2026-05-12T10:00:00Z",
    "package_type": "prepaid"
  }' | jq

# Expected: 400 error about end_time before start_time
```

### Test 5: Kafka Message Flow

**Purpose**: Verify end-to-end message flow

```bash
# 1. Submit data
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "kafka-test-001",
    "usage": 200.0,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "postpaid"
  }'

# 2. Check producer logs for Kafka publish
podman-compose logs producer | grep "Sent to Kafka"

# 3. Wait 10 seconds for billing report
sleep 10

# 4. Check consumer logs for billing report
podman-compose logs consumer | grep "kafka-test-001"
```

**Expected**:
- Producer logs show: "Sent to Kafka topic 'mobile-usage'"
- Consumer logs show device in billing report with $20.00 cost

## End-to-End Testing

### Test 6: Multiple Devices

**Purpose**: Test concurrent device tracking

```bash
# Create test script
cat > test_multiple_devices.sh << 'EOF'
#!/bin/bash
for i in {1..10}; do
  curl -X POST http://localhost:3000/mobile-usage \
    -H "Content-Type: application/json" \
    -d "{
      \"device_id\": \"device-$(printf %03d $i)\",
      \"usage\": $((100 + i * 50)),
      \"start_time\": \"2026-05-12T10:00:00Z\",
      \"end_time\": \"2026-05-12T10:05:00Z\",
      \"package_type\": \"prepaid\"
    }" &
done
wait
echo "All requests sent"
EOF

chmod +x test_multiple_devices.sh
./test_multiple_devices.sh

# Wait for billing report
sleep 10

# Check results
curl http://localhost:3000/mobile-usage/stats | jq
podman-compose logs consumer | tail -30
```

**Validation**:
- All 10 devices appear in statistics
- Consumer shows 10 unique devices
- Total usage and cost calculated correctly

### Test 7: Package Type Filtering

**Purpose**: Test filtering by package type

```bash
# Submit different package types
for type in prepaid postpaid unlimited; do
  curl -X POST http://localhost:3000/mobile-usage \
    -H "Content-Type: application/json" \
    -d "{
      \"device_id\": \"device-$type\",
      \"usage\": 100,
      \"start_time\": \"2026-05-12T10:00:00Z\",
      \"end_time\": \"2026-05-12T10:05:00Z\",
      \"package_type\": \"$type\"
    }"
done

# Query by package type
curl "http://localhost:3000/mobile-usage/package/prepaid" | jq
curl "http://localhost:3000/mobile-usage/package/postpaid" | jq
curl "http://localhost:3000/mobile-usage/package/unlimited" | jq
```

### Test 8: Pagination

**Purpose**: Test pagination functionality

```bash
# Submit 25 records
for i in {1..25}; do
  curl -X POST http://localhost:3000/mobile-usage \
    -H "Content-Type: application/json" \
    -d "{
      \"device_id\": \"pagination-test-$i\",
      \"usage\": 100,
      \"start_time\": \"2026-05-12T10:00:00Z\",
      \"end_time\": \"2026-05-12T10:05:00Z\",
      \"package_type\": \"prepaid\"
    }" > /dev/null 2>&1
done

# Test pagination
curl "http://localhost:3000/mobile-usage?limit=10&offset=0" | jq '.pagination'
curl "http://localhost:3000/mobile-usage?limit=10&offset=10" | jq '.pagination'
curl "http://localhost:3000/mobile-usage?limit=10&offset=20" | jq '.pagination'
```

**Validation**:
- First page: 10 records, offset 0
- Second page: 10 records, offset 10
- Third page: 5 records, offset 20

### Test 9: Delete Record

**Purpose**: Test record deletion

```bash
# Submit a record
RESPONSE=$(curl -s -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "delete-test",
    "usage": 100,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }')

# Extract ID
ID=$(echo $RESPONSE | jq -r '.data.id')
echo "Created record with ID: $ID"

# Delete the record
curl -X DELETE "http://localhost:3000/mobile-usage/$ID" | jq

# Verify deletion
curl "http://localhost:3000/mobile-usage/device/delete-test" | jq
# Expected: empty data array
```

## Performance Testing

### Test 10: Load Test

**Purpose**: Test system under load

```bash
# Create load test script
cat > load_test.sh << 'EOF'
#!/bin/bash
REQUESTS=100
CONCURRENT=10

echo "Starting load test: $REQUESTS requests, $CONCURRENT concurrent"
START=$(date +%s)

for batch in $(seq 1 $((REQUESTS / CONCURRENT))); do
  for i in $(seq 1 $CONCURRENT); do
    curl -s -X POST http://localhost:3000/mobile-usage \
      -H "Content-Type: application/json" \
      -d "{
        \"device_id\": \"load-test-$((batch * CONCURRENT + i))\",
        \"usage\": 100,
        \"start_time\": \"2026-05-12T10:00:00Z\",
        \"end_time\": \"2026-05-12T10:05:00Z\",
        \"package_type\": \"prepaid\"
      }" > /dev/null &
  done
  wait
done

END=$(date +%s)
DURATION=$((END - START))
echo "Completed $REQUESTS requests in $DURATION seconds"
echo "Throughput: $((REQUESTS / DURATION)) requests/second"
EOF

chmod +x load_test.sh
./load_test.sh

# Check statistics
curl http://localhost:3000/mobile-usage/stats | jq
```

**Expected Performance**:
- Throughput: >100 requests/second
- No errors
- All messages processed by consumer

### Test 11: Consumer Lag Test

**Purpose**: Test consumer keeps up with producer

```bash
# Send burst of messages
for i in {1..100}; do
  curl -s -X POST http://localhost:3000/mobile-usage \
    -H "Content-Type: application/json" \
    -d "{
      \"device_id\": \"lag-test-$i\",
      \"usage\": 100,
      \"start_time\": \"2026-05-12T10:00:00Z\",
      \"end_time\": \"2026-05-12T10:05:00Z\",
      \"package_type\": \"prepaid\"
    }" > /dev/null &
done
wait

# Check consumer group lag
podman exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe --group mobile-billing-consumer

# Expected: LAG should be 0 or very low
```

## Failure Testing

### Test 12: Kafka Failure Recovery

**Purpose**: Test system behavior when Kafka is unavailable

```bash
# Stop Kafka
podman-compose stop kafka

# Try to submit data (should still work, but Kafka message skipped)
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "kafka-down-test",
    "usage": 100,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }' | jq

# Check producer logs for warning
podman-compose logs producer | grep "Kafka producer not available"

# Restart Kafka
podman-compose start kafka

# Wait for reconnection
sleep 30

# Submit new data (should work normally)
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "kafka-recovered-test",
    "usage": 100,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }' | jq
```

### Test 13: Consumer Restart

**Purpose**: Test consumer recovery after restart

```bash
# Note current event count
podman-compose logs consumer | grep "Total Events Processed"

# Restart consumer
podman-compose restart consumer

# Wait for consumer to reconnect
sleep 10

# Submit new data
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "consumer-restart-test",
    "usage": 100,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }'

# Check consumer processes new messages
sleep 10
podman-compose logs consumer | tail -30
```

## Automated Test Suite

### Complete Test Script

```bash
cat > run_all_tests.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Mobile Usage Platform Test Suite ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}✓ $1${NC}"
}

fail() {
  echo -e "${RED}✗ $1${NC}"
  exit 1
}

# Test 1: Health Check
echo "Test 1: Health Check"
HEALTH=$(curl -s http://localhost:3000/health)
if echo "$HEALTH" | jq -e '.status == "healthy"' > /dev/null; then
  pass "Health check passed"
else
  fail "Health check failed"
fi

# Test 2: Submit Data
echo "Test 2: Submit Usage Data"
RESPONSE=$(curl -s -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "test-001",
    "usage": 100,
    "start_time": "2026-05-12T10:00:00Z",
    "end_time": "2026-05-12T10:05:00Z",
    "package_type": "prepaid"
  }')
if echo "$RESPONSE" | jq -e '.data.id' > /dev/null; then
  pass "Data submission passed"
else
  fail "Data submission failed"
fi

# Test 3: Query Data
echo "Test 3: Query Usage Data"
QUERY=$(curl -s "http://localhost:3000/mobile-usage?limit=1")
if echo "$QUERY" | jq -e '.data | length > 0' > /dev/null; then
  pass "Data query passed"
else
  fail "Data query failed"
fi

# Test 4: Statistics
echo "Test 4: Get Statistics"
STATS=$(curl -s http://localhost:3000/mobile-usage/stats)
if echo "$STATS" | jq -e '.statistics.total_records' > /dev/null; then
  pass "Statistics passed"
else
  fail "Statistics failed"
fi

# Test 5: Input Validation
echo "Test 5: Input Validation"
ERROR=$(curl -s -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{"device_id": "test"}')
if echo "$ERROR" | jq -e '.error' > /dev/null; then
  pass "Input validation passed"
else
  fail "Input validation failed"
fi

echo ""
echo "=== All Tests Passed ==="
EOF

chmod +x run_all_tests.sh
./run_all_tests.sh
```

## Troubleshooting Tests

### Common Issues

**Issue**: Tests fail with connection refused
```bash
# Solution: Ensure services are running
podman-compose ps
podman-compose up -d
```

**Issue**: Consumer not processing messages
```bash
# Solution: Check Kafka and consumer logs
podman-compose logs kafka
podman-compose logs consumer
podman-compose restart consumer
```

**Issue**: Database errors
```bash
# Solution: Reset database
podman-compose down -v
podman-compose up -d
```

## Continuous Testing

### Watch Mode

```bash
# Monitor logs while testing
podman-compose logs -f &

# Run tests
./run_all_tests.sh

# Stop log monitoring
fg  # Then Ctrl+C
```

### Cleanup After Tests

```bash
# Stop all services
podman-compose down

# Remove volumes (deletes all data)
podman-compose down -v

# Remove test scripts
rm -f test_*.sh load_test.sh run_all_tests.sh
```

---

**Last Updated**: 2026-05-12  
**Version**: 1.0.0