# Testing Neo4j Knowledge Graph Locally - Podman Guide

This guide provides steps to test the Kafka messaging knowledge graph with Neo4j using **Podman**.

## Prerequisites

- Podman installed
- Podman Compose installed (`pip install podman-compose`)

## Quick Start (3 Simple Steps)

### Step 1: Start Neo4j

```bash
# Start Neo4j with Podman Compose
podman-compose -f docker-compose.neo4j.yml up -d

# Wait for Neo4j to be ready (30-60 seconds)
podman logs -f kafka-knowledge-graph-neo4j
# Wait until you see "Started."
```

### Step 2: Load the Knowledge Graph

```bash
# Run the load script (auto-detects podman)
./load-graph.sh
```

This script will:
- ✅ Detect podman automatically
- ✅ Check if Neo4j is running
- ⏳ Wait for Neo4j to be ready
- 📋 Copy the init-graph.cypher file
- 🚀 Load all the data
- ✅ Confirm success

### Step 3: Visualize in Browser

Open your browser and go to:
```
http://localhost:7474
```

**Login:**
- Username: `neo4j`
- Password: `password123`

## Verify Data Loaded

Run this query in Neo4j Browser:

```cypher
MATCH (n) RETURN labels(n) as NodeType, count(n) as Count
```

You should see ~24 nodes across different types.

## Essential Visualization Queries

### 1. Complete Message Flow (Producer → Topic → Consumer)

```cypher
MATCH path = (producer:Application {type: 'producer'})-[:PRODUCES_TO]->(topic:Topic)<-[:CONSUMES_FROM]-(consumer:Application {type: 'consumer'})
RETURN path
```

### 2. Full Data Pipeline (API → Kafka → Storage)

```cypher
MATCH path = (endpoint:Endpoint)-[:TRIGGERS_PRODUCTION]->(producer:Producer)-[:PRODUCES_TO]->(topic:Topic)<-[:CONSUMES_FROM]-(consumer:Consumer)-[:STORES_IN]->(store:DataStore)
RETURN path
```

### 3. Application Architecture

```cypher
MATCH (app:Application)
OPTIONAL MATCH (app)-[r]-(component)
WHERE component:Producer OR component:Consumer OR component:API OR component:DataStore
RETURN app, r, component
```

### 4. View Everything

```cypher
MATCH (n)
OPTIONAL MATCH (n)-[r]->(m)
RETURN n, r, m
LIMIT 100
```

## Manual Loading (Alternative Method)

If the script doesn't work, you can load manually:

### Option A: Copy-Paste in Neo4j Browser

1. Open `init-graph.cypher` in your editor
2. Copy all contents
3. Paste into Neo4j Browser query editor
4. Click Play (▶) or press Ctrl+Enter

### Option B: Command Line with Podman

```bash
# Copy file to container
podman cp init-graph.cypher kafka-knowledge-graph-neo4j:/tmp/init-graph.cypher

# Execute the script
podman exec -it kafka-knowledge-graph-neo4j cypher-shell -u neo4j -p password123 -f /tmp/init-graph.cypher
```

## Troubleshooting

### Neo4j Won't Start

```bash
# Check logs
podman logs kafka-knowledge-graph-neo4j

# If you see permission errors, remove volumes and restart
podman-compose -f docker-compose.neo4j.yml down -v
podman-compose -f docker-compose.neo4j.yml up -d
```

### Podman Compose Not Found

```bash
# Install podman-compose
pip install podman-compose

# Or using pip3
pip3 install podman-compose

# Verify installation
podman-compose --version
```

### Script Permission Denied

```bash
# Make script executable
chmod +x load-graph.sh

# Then run it
./load-graph.sh
```

### Can't Access Browser

1. Verify Neo4j is running:
   ```bash
   podman ps | grep neo4j
   ```

2. Check if port 7474 is available:
   ```bash
   # Mac/Linux
   lsof -i :7474
   
   # Or check with ss
   ss -tulpn | grep 7474
   ```

3. Try alternative URL: `http://127.0.0.1:7474`

4. Check Podman port mapping:
   ```bash
   podman port kafka-knowledge-graph-neo4j
   ```

### Data Not Loading

```bash
# Check if file exists
ls -la init-graph.cypher

# Verify Neo4j is ready
podman exec kafka-knowledge-graph-neo4j cypher-shell -u neo4j -p password123 "RETURN 1"

# Try manual loading (see above)
```

### SELinux Issues (Fedora/RHEL/CentOS)

If you encounter SELinux permission issues:

```bash
# Option 1: Add :Z flag to volumes (already done in docker-compose.neo4j.yml)
# The compose file uses named volumes which handle this automatically

# Option 2: Temporarily set SELinux to permissive (not recommended for production)
sudo setenforce 0

# Option 3: Create proper SELinux context
sudo chcon -Rt svirt_sandbox_file_t ./init-graph.cypher
```

## Useful Podman Commands

```bash
# View Neo4j logs
podman logs -f kafka-knowledge-graph-neo4j

# Stop Neo4j
podman-compose -f docker-compose.neo4j.yml stop

# Stop and remove (keeps data)
podman-compose -f docker-compose.neo4j.yml down

# Stop and remove everything (including data)
podman-compose -f docker-compose.neo4j.yml down -v

# Restart Neo4j
podman-compose -f docker-compose.neo4j.yml restart

# Check Neo4j status
podman exec kafka-knowledge-graph-neo4j cypher-shell -u neo4j -p password123 "CALL dbms.components()"

# List all containers
podman ps -a

# Inspect container
podman inspect kafka-knowledge-graph-neo4j

# Check resource usage
podman stats kafka-knowledge-graph-neo4j
```

## What's in the Graph?

The knowledge graph contains:

**Applications:**
- `iot-usage-kafka-logger` (Producer - TypeScript/Express)
- `fixium-mobile-consumer` (Consumer - Python)

**Infrastructure:**
- Kafka Cluster (local-kafka-cluster)
- Topic (mobile-usage)
- Producer & Consumer components
- Consumer Group

**Data Flow:**
- REST API endpoints
- Message schemas
- Data stores (SQLite, In-Memory)
- Processing logic (validation, aggregation, reporting)

**Dependencies:**
- express, kafkajs, better-sqlite3 (Producer)
- confluent-kafka (Consumer)

## Podman-Specific Tips

### Running Rootless

Podman runs rootless by default, which is more secure:

```bash
# Check if running rootless
podman info | grep rootless

# If you need rootful mode (not recommended)
sudo podman-compose -f docker-compose.neo4j.yml up -d
```

### Port Binding Issues

If port 7474 is already in use:

```bash
# Find what's using the port
sudo lsof -i :7474

# Or modify docker-compose.neo4j.yml to use different ports:
# Change "7474:7474" to "8474:7474" for HTTP
# Change "7687:7687" to "8687:7687" for Bolt
```

### Volume Permissions

Podman handles volumes differently than Docker:

```bash
# List volumes
podman volume ls

# Inspect a volume
podman volume inspect neo4j_data

# Remove unused volumes
podman volume prune
```

## Next Steps

1. **Explore Relationships**: Click on nodes to see connections
2. **Run Analysis Queries**: See NEO4J_QUICKSTART.md for more queries
3. **Customize Visualization**: Change colors, sizes, captions
4. **Export**: Save visualizations as PNG/SVG
5. **Extend**: Add more applications or components

## Full Documentation

For comprehensive documentation, see:
- `NEO4J_QUICKSTART.md` - Detailed guide with all queries
- `kafka-messaging-knowledge-graph-schema.json` - Complete schema definition

## Common Podman vs Docker Differences

| Feature | Docker | Podman |
|---------|--------|--------|
| Daemon | Required | Daemonless |
| Root | Runs as root | Rootless by default |
| Command | `docker` | `podman` |
| Compose | `docker-compose` | `podman-compose` |
| Socket | `/var/run/docker.sock` | `/run/user/$UID/podman/podman.sock` |

The `load-graph.sh` script automatically detects which one you have installed!

---

**Made with Bob** 🤖