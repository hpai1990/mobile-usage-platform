# IoT Usage Kafka Logger API

A REST API for logging mobile device usage data with SQLite database storage and plans to integrate with Kafka.

## Features

- ✅ POST endpoint to receive and store mobile usage data
- ✅ SQLite database for persistent storage
- ✅ GET endpoints to retrieve and filter usage data
- ✅ Usage statistics and analytics
- ✅ Input validation for all parameters
- ✅ TypeScript for type safety
- ✅ Express.js framework
- 🔄 Kafka integration (planned)

## Installation

```bash
npm install
```

## Database Setup

The application uses SQLite for data persistence. The database is automatically initialized on first run.

### Database Schema

**Table: `mobile_usage`**
- `id` - INTEGER PRIMARY KEY AUTOINCREMENT
- `device_id` - TEXT NOT NULL
- `usage` - REAL NOT NULL (in MB)
- `start_time` - TEXT NOT NULL (ISO 8601 format)
- `end_time` - TEXT NOT NULL (ISO 8601 format)
- `package_type` - TEXT NOT NULL (e.g., "prepaid", "postpaid", "unlimited")
- `created_at` - TEXT NOT NULL (ISO 8601 format, auto-generated)

### Seed Sample Data

To populate the database with sample data for testing:

```bash
npm run seed
```

This will insert 10 sample records with various device IDs and package types.

## Running the Server

Development mode (with auto-reload):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

The server will run on port 3000 by default (configurable via `PORT` environment variable).

## API Endpoints

### POST /mobile-usage

Submit mobile device usage data and store it in the database.

**Request Body:**
```json
{
  "device_id": "device-123",
  "usage": 1024.5,
  "start_time": "2026-05-11T10:00:00.000Z",
  "end_time": "2026-05-11T11:00:00.000Z",
  "package_type": "prepaid"
}
```

**Parameters:**
- `device_id` (string, required): Unique identifier for the mobile device
- `usage` (number, required): Usage amount in MB (must be non-negative)
- `start_time` (string, required): Start time in ISO 8601 format
- `end_time` (string, required): End time in ISO 8601 format (must be after start_time)
- `package_type` (string, required): Package type (e.g., "prepaid", "postpaid", "unlimited", "family-plan", "corporate")

**Success Response (201):**
```json
{
  "message": "Mobile usage data received and stored successfully",
  "data": {
    "id": 1,
    "device_id": "device-123",
    "usage": 1024.5,
    "start_time": "2026-05-11T10:00:00.000Z",
    "end_time": "2026-05-11T11:00:00.000Z",
    "package_type": "prepaid",
    "created_at": "2026-05-11T12:57:00.000Z"
  },
  "timestamp": "2026-05-11T12:57:00.000Z"
}
```

**Error Responses:**

400 Bad Request - Missing parameters:
```json
{
  "error": "Missing required parameters",
  "required": ["device_id", "usage", "start_time", "end_time", "package_type"],
  "received": { ... }
}
```

400 Bad Request - Invalid usage value:
```json
{
  "error": "Invalid usage value",
  "message": "Usage must be a non-negative number"
}
```

400 Bad Request - Invalid package_type:
```json
{
  "error": "Invalid package_type",
  "message": "package_type must be a non-empty string"
}
```

400 Bad Request - Invalid date format:
```json
{
  "error": "Invalid date format",
  "message": "start_time and end_time must be valid ISO 8601 date strings"
}
```

400 Bad Request - Invalid time range:
```json
{
  "error": "Invalid time range",
  "message": "end_time must be after start_time"
}
```

### GET /mobile-usage

Retrieve all usage data with optional filtering and pagination.

**Query Parameters:**
- `limit` (number, optional): Maximum number of records to return (default: 100, max: 1000)
- `offset` (number, optional): Number of records to skip (default: 0)
- `device_id` (string, optional): Filter by device ID
- `package_type` (string, optional): Filter by package type
- `start_date` (string, optional): Filter records created after this date (ISO 8601)
- `end_date` (string, optional): Filter records created before this date (ISO 8601)

**Example Request:**
```bash
curl "http://localhost:3000/mobile-usage?limit=10&device_id=device-123"
```

**Success Response (200):**
```json
{
  "data": [
    {
      "id": 1,
      "device_id": "device-123",
      "usage": 1024.5,
      "start_time": "2026-05-11T10:00:00.000Z",
      "end_time": "2026-05-11T11:00:00.000Z",
      "package_type": "prepaid",
      "created_at": "2026-05-11T12:57:00.000Z"
    }
  ],
  "pagination": {
    "limit": 10,
    "offset": 0,
    "total": 1,
    "returned": 1
  },
  "filters": {
    "device_id": "device-123",
    "package_type": null,
    "start_date": null,
    "end_date": null
  }
}
```

### GET /mobile-usage/device/:device_id

Retrieve usage data for a specific device.

**Example Request:**
```bash
curl "http://localhost:3000/mobile-usage/device/device-123?limit=50"
```

**Success Response (200):**
```json
{
  "device_id": "device-123",
  "data": [ ... ],
  "count": 2
}
```

### GET /mobile-usage/package/:package_type

Retrieve usage data for a specific package type.

**Example Request:**
```bash
curl "http://localhost:3000/mobile-usage/package/prepaid?limit=50"
```

**Success Response (200):**
```json
{
  "package_type": "prepaid",
  "data": [ ... ],
  "count": 5
}
```

### GET /mobile-usage/stats

Get usage statistics and analytics.

**Success Response (200):**
```json
{
  "statistics": {
    "total_records": 10,
    "total_usage": 18795.5,
    "unique_devices": 7,
    "package_types": [
      { "package_type": "prepaid", "count": 3 },
      { "package_type": "postpaid", "count": 2 },
      { "package_type": "unlimited", "count": 3 },
      { "package_type": "family-plan", "count": 1 },
      { "package_type": "corporate", "count": 1 }
    ]
  },
  "timestamp": "2026-05-11T12:57:00.000Z"
}
```

### DELETE /mobile-usage/:id

Delete a specific usage record by ID.

**Example Request:**
```bash
curl -X DELETE "http://localhost:3000/mobile-usage/1"
```

**Success Response (200):**
```json
{
  "message": "Record deleted successfully",
  "id": 1
}
```

**Error Response (404):**
```json
{
  "error": "Record not found",
  "message": "No record found with ID 1"
}
```

### GET /health

Health check endpoint.

**Success Response (200):**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2026-05-11T12:57:00.000Z"
}
```

## Example Usage

### Using curl

**Submit usage data:**
```bash
curl -X POST http://localhost:3000/mobile-usage \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-123",
    "usage": 1024.5,
    "start_time": "2026-05-11T10:00:00.000Z",
    "end_time": "2026-05-11T11:00:00.000Z",
    "package_type": "prepaid"
  }'
```

**Retrieve all data:**
```bash
curl "http://localhost:3000/mobile-usage?limit=10"
```

**Filter by package type:**
```bash
curl "http://localhost:3000/mobile-usage?package_type=prepaid&limit=20"
```

**Get statistics:**
```bash
curl "http://localhost:3000/mobile-usage/stats"
```

### Using JavaScript fetch

```javascript
// Submit usage data
fetch('http://localhost:3000/mobile-usage', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    device_id: 'device-123',
    usage: 1024.5,
    start_time: '2026-05-11T10:00:00.000Z',
    end_time: '2026-05-11T11:00:00.000Z',
    package_type: 'prepaid'
  })
})
.then(response => response.json())
.then(data => console.log(data));

// Retrieve data
fetch('http://localhost:3000/mobile-usage?limit=10')
  .then(response => response.json())
  .then(data => console.log(data));

// Get statistics
fetch('http://localhost:3000/mobile-usage/stats')
  .then(response => response.json())
  .then(data => console.log(data));
```

## Environment Variables

- `PORT`: Server port (default: 3000)

## Database Files

- `usage.db` - Production database (gitignored)
- `usage.db-shm` - SQLite shared memory file (gitignored)
- `usage.db-wal` - SQLite write-ahead log file (gitignored)

**Note:** The production database file is excluded from version control. Use the seed script to populate sample data for development/testing.

## Project Structure

```
iot-usage-kafka-logger/
├── src/
│   ├── database/
│   │   ├── init.ts          # Database initialization
│   │   └── service.ts       # Database CRUD operations
│   └── scripts/
│       └── seed.ts          # Database seeding script
├── index.ts                 # Main application file
├── package.json
├── tsconfig.json
├── .gitignore
└── README.md
```

## Future Enhancements

- 🔄 Kafka integration for message streaming
- 🔐 Authentication and authorization
- ⚡ Rate limiting
- 📝 Request logging middleware
- 📊 Advanced analytics and reporting
- 🔍 Full-text search capabilities
- 📤 Data export functionality

## Development

### Available Scripts

- `npm run dev` - Start development server with auto-reload
- `npm start` - Start production server
- `npm run build` - Build TypeScript to JavaScript
- `npm run seed` - Populate database with sample data

### Database Management

The database is automatically created on first run. To reset the database:

1. Stop the server
2. Delete `usage.db` file
3. Restart the server (database will be recreated)
4. Run `npm run seed` to add sample data

## License

ISC

---

**Made with Bob** 🤖