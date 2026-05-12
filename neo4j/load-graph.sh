#!/bin/bash

# Script to load the knowledge graph into Neo4j
# Usage: ./load-graph.sh
# Works with both Docker and Podman

set -e

# Detect container runtime (podman or docker)
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman-compose"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Neither podman nor docker found!"
    echo "Please install podman or docker first."
    exit 1
fi

echo "🔍 Using container runtime: $CONTAINER_CMD"
echo "🔍 Checking if Neo4j is running..."

# Check if Neo4j container is running
if ! $CONTAINER_CMD ps | grep -q kafka-knowledge-graph-neo4j; then
    echo "❌ Neo4j container is not running!"
    echo "Please start it first with: $COMPOSE_CMD -f docker-compose.neo4j.yml up -d"
    exit 1
fi

echo "✅ Neo4j container is running"

# Wait for Neo4j to be ready
echo "⏳ Waiting for Neo4j to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if $CONTAINER_CMD exec kafka-knowledge-graph-neo4j cypher-shell -u neo4j -p password123 "RETURN 1" > /dev/null 2>&1; then
        echo "✅ Neo4j is ready!"
        break
    fi
    attempt=$((attempt + 1))
    echo "   Attempt $attempt/$max_attempts..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Neo4j did not become ready in time"
    exit 1
fi

# Copy the init script to the container
echo "📋 Copying init-graph.cypher to Neo4j container..."
$CONTAINER_CMD cp init-graph.cypher kafka-knowledge-graph-neo4j:/tmp/init-graph.cypher

# Execute the script
echo "🚀 Loading knowledge graph data..."
$CONTAINER_CMD exec kafka-knowledge-graph-neo4j cypher-shell -u neo4j -p password123 -f /tmp/init-graph.cypher

echo ""
echo "✅ Knowledge graph loaded successfully!"
echo ""
echo "🌐 Access Neo4j Browser at: http://localhost:7474"
echo "   Username: neo4j"
echo "   Password: password123"
echo ""
echo "📊 Try these queries:"
echo "   1. View all nodes: MATCH (n) RETURN n LIMIT 25"
echo "   2. View message flow: MATCH path = (producer:Application {type: 'producer'})-[:PRODUCES_TO]->(topic:Topic)<-[:CONSUMES_FROM]-(consumer:Application {type: 'consumer'}) RETURN path"
echo "   3. View complete graph: MATCH (n) OPTIONAL MATCH (n)-[r]->(m) RETURN n, r, m LIMIT 100"
echo ""

# Made with Bob