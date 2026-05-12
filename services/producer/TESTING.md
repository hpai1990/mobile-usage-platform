# Testing Guide

This guide provides step-by-step instructions to test the IoT Usage Kafka Logger API with SQLite database integration.

## Prerequisites

1. Ensure all dependencies are installed:
```bash
npm install
```

2. The database will be automatically created on first run.

## Testing Steps

### Step 1: Start the Server

```bash
npm start
```

Expected output:
```
✅ Database initialized successfully
📁 Database location: /home/purva/semicolon/iot-usage-kafka-logger/usage.db
🚀 Server is running on port 3000
📱 POST /mobile-usage - Submit usage data
📊 GET /mobile-usage - Retrieve all usage data (with filters)
🔍 GET /mobile-usage/device/:device_id - Get usage by device
📦 GET /mobile-usage/package/:package_type - Get usage by package type
📈 GET /mobile-usage/stats - Get usage statistics
🗑️  DELETE /mobile-usage/:id - Delete a usage record
💚 GET /health - Health check
```

### Step 2: Seed Sample Data (Optional)

In a new terminal:
```bash
npm run seed
```

Expected output:
```
🌱 Starting database seeding...

✅ Inserted record 1: device-001 (prepaid)
✅ Inserted record 2: device-002 (postpaid)
✅ Inserted record 3: device-003 (unlimited)
...
✅ Inserted record 10: device-007 (unlimited)

📊 Seeding Summary:
   ✅ Successfully inserted: 10 records
   ❌ Failed: 0 records
   📦 Total: 10 records

✨ Database seeding completed!
```

### Step 3: Test Health Check

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2026-05-11T13:00:00.000Z"
}
```

### Step 4: Test POST Endpoint - Submit Usage Data

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-test-001",
    "usage": 1500.75,
    "start_time": "2026-05-11T10:00:00.000Z",
    "end_time": "2026-05-11T11:00:00.000Z",
    "package_type": "prepaid"
  }'
```

Expected response (201 Created):
```json
{
  "message": "Mobile usage data received and stored successfully",
  "data": {
    "id": 11,
    "device_id": "device-test-001",
    "usage": 1500.75,
    "start_time": "2026-05-11T10:00:00.000Z",
    "end_time": "2026-05-11T11:00:00.000Z",
    "package_type": "prepaid",
    "created_at": "2026-05-11T13:00:00.000Z"
  },
  "timestamp": "2026-05-11T13:00:00.000Z"
}
```

### Step 5: Test GET Endpoint - Retrieve All Data

```bash
curl "http://localhost:3000/mobile-usage?limit=5"
```

Expected response (200 OK):
```json
{
  "data": [
    {
      "id": 11,
      "device_id": "device-test-001",
      "usage": 1500.75,
      "start_time": "2026-05-11T10:00:00.000Z",
      "end_time": "2026-05-11T11:00:00.000Z",
      "package_type": "prepaid",
      "created_at": "2026-05-11T13:00:00.000Z"
    },
    ...
  ],
  "pagination": {
    "limit": 5,
    "offset": 0,
    "total": 11,
    "returned": 5
  },
  "filters": {
    "device_id": null,
    "package_type": null,
    "start_date": null,
    "end_date": null
  }
}
```

### Step 6: Test GET with Filters - Filter by Device ID

```bash
curl "http://localhost:3000/mobile-usage?device_id=device-test-001"
```

Expected response: Only records for device-test-001

### Step 7: Test GET with Filters - Filter by Package Type

```bash
curl "http://localhost:3000/mobile-usage?package_type=prepaid&limit=10"
```

Expected response: Only records with package_type "prepaid"

### Step 8: Test GET by Device ID Endpoint

```bash
curl "http://localhost:3000/mobile-usage/device/device-test-001"
```

Expected response (200 OK):
```json
{
  "device_id": "device-test-001",
  "data": [
    {
      "id": 11,
      "device_id": "device-test-001",
      "usage": 1500.75,
      "start_time": "2026-05-11T10:00:00.000Z",
      "end_time": "2026-05-11T11:00:00.000Z",
      "package_type": "prepaid",
      "created_at": "2026-05-11T13:00:00.000Z"
    }
  ],
  "count": 1
}
```

### Step 9: Test GET by Package Type Endpoint

```bash
curl "http://localhost:3000/mobile-usage/package/prepaid"
```

Expected response: All records with package_type "prepaid"

### Step 10: Test Statistics Endpoint

```bash
curl "http://localhost:3000/mobile-usage/stats"
```

Expected response (200 OK):
```json
{
  "statistics": {
    "total_records": 11,
    "total_usage": 20296.25,
    "unique_devices": 8,
    "package_types": [
      { "package_type": "prepaid", "count": 4 },
      { "package_type": "postpaid", "count": 2 },
      { "package_type": "unlimited", "count": 3 },
      { "package_type": "family-plan", "count": 1 },
      { "package_type": "corporate", "count": 1 }
    ]
  },
  "timestamp": "2026-05-11T13:00:00.000Z"
}
```

### Step 11: Test DELETE Endpoint

```bash
curl -X DELETE "http://localhost:3000/mobile-usage/11"
```

Expected response (200 OK):
```json
{
  "message": "Record deleted successfully",
  "id": 11
}
```

Verify deletion:
```bash
curl "http://localhost:3000/mobile-usage/device/device-test-001"
```

Expected: Empty data array or no records found

### Step 12: Test Error Handling - Missing Required Field

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-test-002",
    "usage": 1000,
    "start_time": "2026-05-11T10:00:00.000Z",
    "end_time": "2026-05-11T11:00:00.000Z"
  }'
```

Expected response (400 Bad Request):
```json
{
  "error": "Missing required parameters",
  "required": ["device_id", "usage", "start_time", "end_time", "package_type"],
  "received": { ... }
}
```

### Step 13: Test Error Handling - Invalid Usage Value

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-test-002",
    "usage": -100,
    "start_time": "2026-05-11T10:00:00.000Z",
    "end_time": "2026-05-11T11:00:00.000Z",
    "package_type": "prepaid"
  }'
```

Expected response (400 Bad Request):
```json
{
  "error": "Invalid usage value",
  "message": "Usage must be a non-negative number"
}
```

### Step 14: Test Error Handling - Invalid Time Range

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-test-002",
    "usage": 1000,
    "start_time": "2026-05-11T11:00:00.000Z",
    "end_time": "2026-05-11T10:00:00.000Z",
    "package_type": "prepaid"
  }'
```

Expected response (400 Bad Request):
```json
{
  "error": "Invalid time range",
  "message": "end_time must be after start_time"
}
```

### Step 15: Test Error Handling - Empty Package Type

```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-test-002",
    "usage": 1000,
    "start_time": "2026-05-11T10:00:00.000Z",
    "end_time": "2026-05-11T11:00:00.000Z",
    "package_type": ""
  }'
```

Expected response (400 Bad Request):
```json
{
  "error": "Invalid package_type",
  "message": "package_type must be a non-empty string"
}
```

## Verification Checklist

- [ ] Server starts without errors
- [ ] Database file is created (usage.db)
- [ ] Seed script populates 10 sample records
- [ ] Health check returns healthy status
- [ ] POST endpoint accepts valid data and stores in database
- [ ] POST endpoint returns created record with ID and created_at
- [ ] GET endpoint retrieves all records with pagination
- [ ] GET endpoint filters by device_id correctly
- [ ] GET endpoint filters by package_type correctly
- [ ] GET /device/:device_id endpoint works
- [ ] GET /package/:package_type endpoint works
- [ ] GET /stats endpoint returns correct statistics
- [ ] DELETE endpoint removes records successfully
- [ ] All validation errors return appropriate 400 responses
- [ ] Missing required fields are caught
- [ ] Invalid usage values are rejected
- [ ] Invalid time ranges are rejected
- [ ] Empty package_type is rejected

## Database Verification

You can also verify the database directly using SQLite:

```bash
sqlite3 usage.db
```

Then run SQL queries:
```sql
-- View all records
SELECT * FROM mobile_usage;

-- Count records by package type
SELECT package_type, COUNT(*) as count 
FROM mobile_usage 
GROUP BY package_type;

-- View schema
.schema mobile_usage

-- Exit
.quit
```

## Clean Up

To reset the database:
1. Stop the server (Ctrl+C)
2. Delete the database file: `rm usage.db`
3. Restart the server (database will be recreated)
4. Run seed script if needed: `npm run seed`

## Notes

- The database file `usage.db` is gitignored and won't be committed
- All timestamps are in ISO 8601 UTC format
- The package_type field accepts any non-empty string value
- Error handling is comprehensive with appropriate HTTP status codes
- All database operations include proper error handling