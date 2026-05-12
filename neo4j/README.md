# Neo4j Knowledge Graph Integration (Optional)

This directory contains optional Neo4j graph database integration for visualizing and analyzing the Mobile Usage Platform's data relationships.

## Contents

- `docker-compose.neo4j.yml` - Podman/Docker Compose file for Neo4j
- `init-graph.cypher` - Cypher script to initialize graph schema
- `kafka-messaging-knowledge-graph-schema.json` - Graph schema definition
- `load-graph.sh` - Script to load data into Neo4j (auto-detects Podman/Docker)
- `NEO4J_QUICKSTART.md` - Quick start guide
- `TESTING_NEO4J.md` - Testing guide

## Purpose

The Neo4j integration provides graph-based visualization and analysis of:
- Kafka message flows
- Producer-Consumer relationships
- Topic structures
- Data lineage

## Important Notes

⚠️ **This is an OPTIONAL feature**

The main Mobile Usage Platform (`docker-compose.yml` in root) works perfectly without Neo4j. This integration is for advanced visualization and analysis only.

## Quick Start

### 1. Start Neo4j

```bash
cd neo4j
podman-compose -f docker-compose.neo4j.yml up -d
```

### 2. Load Graph Data

```bash
./load-graph.sh
```

The script automatically detects whether you're using Podman or Docker.

### 3. Access Neo4j Browser

Open http://localhost:7474 in your browser

- Username: `neo4j`
- Password: `password123`

## Integration with Main Platform

To run Neo4j alongside the main platform:

```bash
# Terminal 1: Start main platform
cd /path/to/mobile-usage-platform
podman-compose up -d

# Terminal 2: Start Neo4j
cd neo4j
podman-compose -f docker-compose.neo4j.yml up -d
```

Both will run on separate networks and can coexist.

## Stopping Neo4j

```bash
cd neo4j
podman-compose -f docker-compose.neo4j.yml down

# To remove data volumes
podman-compose -f docker-compose.neo4j.yml down -v
```

## Documentation

- [NEO4J_QUICKSTART.md](NEO4J_QUICKSTART.md) - Detailed setup guide
- [TESTING_NEO4J.md](TESTING_NEO4J.md) - Testing procedures

---

**Status**: Optional Feature  
**Last Updated**: 2026-05-12  
**Podman Compatible**: ✅ Yes