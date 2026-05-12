# Neo4j Knowledge Graph - Quick Start Guide

This guide will help you visualize and explore the Kafka messaging knowledge graph using Neo4j locally.

## Prerequisites

- Docker or Podman installed
- Docker Compose or Podman Compose installed
- Web browser (Chrome, Firefox, Safari, or Edge)

## Step 1: Start Neo4j

```bash
# Start Neo4j using Podman Compose (recommended)
podman-compose -f docker-compose.neo4j.yml up -d

# Or using Docker Compose
docker-compose -f docker-compose.neo4j.yml up -d
```

**Wait 30-60 seconds** for Neo4j to fully start up.

## Step 2: Verify Neo4j is Running

```bash
# Check container status
podman ps | grep neo4j

# Check logs
podman logs kafka-knowledge-graph-neo4j

# You should see: "Started."
```

## Step 3: Access Neo4j Browser

Open your web browser and navigate to:

```
http://localhost:7474
```

### Login Credentials

- **Username**: `neo4j`
- **Password**: `password123`
- **Connect URL**: `neo4j://localhost:7687` (default)

## Step 4: Load the Knowledge Graph Data

Once logged in to Neo4j Browser:

### Option A: Copy-Paste Method (Recommended)

1. Open the file [`init-graph.cypher`](init-graph.cypher) in your editor
2. Copy the entire contents
3. In Neo4j Browser, paste into the query editor at the top
4. Click the **Play** button (▶) or press `Ctrl+Enter` (Windows/Linux) or `Cmd+Enter` (Mac)
5. Wait for execution to complete (should take 2-3 seconds)

### Option B: Using Neo4j Browser Import

1. In Neo4j Browser, run this command:

```cypher
:play file:///init-graph.cypher
```

### Option C: Using cypher-shell (Command Line)

```bash
# Copy the init script into the container
docker cp init-graph.cypher kafka-knowledge-graph-neo4j:/var/lib/neo4j/import/

# Execute the script
docker exec -it kafka-knowledge-graph-neo4j cypher-shell -u neo4j -p password123 -f /var/lib/neo4j/import/init-graph.cypher
```

## Step 5: Verify Data Loaded

Run this query in Neo4j Browser to count nodes:

```cypher
MATCH (n) RETURN labels(n) as NodeType, count(n) as Count
```

You should see approximately:
- Application: 2
- Topic: 1
- Producer: 1
- Consumer: 1
- ConsumerGroup: 1
- Message: 2
- DataStore: 2
- API: 1
- Endpoint: 4
- ProcessingLogic: 3
- Dependency: 5
- KafkaCluster: 1

**Total: ~24 nodes**

## Step 6: Explore the Graph

### Visualization Queries

#### 1. View Complete Message Flow

```cypher
MATCH path = (producer:Application {type: 'producer'})-[:PRODUCES_TO]->(topic:Topic)<-[:CONSUMES_FROM]-(consumer:Application {type: 'consumer'})
RETURN path
```

#### 2. View Application Architecture

```cypher
MATCH (app:Application)
OPTIONAL MATCH (app)-[r1]-(component)
WHERE component:Producer OR component:Consumer OR component:API OR component:DataStore
RETURN app, r1, component
```

#### 3. View Complete Data Pipeline

```cypher
MATCH path = (endpoint:Endpoint)-[:TRIGGERS_PRODUCTION]->(producer:Producer)-[:PRODUCES_TO]->(topic:Topic)<-[:CONSUMES_FROM]-(consumer:Consumer)-[:STORES_IN]->(store:DataStore)
RETURN path
```

#### 4. View All Dependencies

```cypher
MATCH (app:Application)-[:DEPENDS_ON]->(dep:Dependency)
RETURN app, dep
```

#### 5. View Processing Logic Flow

```cypher
MATCH (consumer:Consumer)-[r:APPLIES_LOGIC]->(logic:ProcessingLogic)
RETURN consumer, r, logic
ORDER BY r.order
```

#### 6. View Kafka Infrastructure

```cypher
MATCH (cluster:KafkaCluster)
OPTIONAL MATCH (cluster)<-[:BELONGS_TO_CLUSTER]-(topic:Topic)
OPTIONAL MATCH (app:Application)-[:CONNECTS_TO_CLUSTER]->(cluster)
RETURN cluster, topic, app
```

#### 7. View Everything (Full Graph)

```cypher
MATCH (n)
OPTIONAL MATCH (n)-[r]->(m)
RETURN n, r, m
LIMIT 100
```

### Analysis Queries

#### Find All Producers for a Topic

```cypher
MATCH (app:Application)-[:PRODUCES_TO]->(topic:Topic {name: 'mobile-usage'})
RETURN app.name as Producer, app.language as Language
```

#### Find All Consumers for a Topic

```cypher
MATCH (app:Application)-[:CONSUMES_FROM]->(topic:Topic {name: 'mobile-usage'})
RETURN app.name as Consumer, app.language as Language
```

#### Find Message Schema Details

```cypher
MATCH (topic:Topic {name: 'mobile-usage'})-[:USES_MESSAGE_SCHEMA]->(msg:Message)
RETURN msg.schema_name as SchemaName, 
       msg.format as Format, 
       msg.schema as Schema
```

#### Find Application Dependencies

```cypher
MATCH (app:Application {name: 'iot-usage-kafka-logger'})-[:DEPENDS_ON]->(dep:Dependency)
RETURN dep.name as Dependency, 
       dep.version as Version, 
       dep.type as Type, 
       dep.purpose as Purpose
```

#### Find Data Stores Used

```cypher
MATCH (app:Application)-[r:STORES_IN]->(ds:DataStore)
RETURN app.name as Application, 
       ds.name as DataStore, 
       ds.technology as Technology, 
       r.operation_type as Operations
```

#### Find API Endpoints

```cypher
MATCH (app:Application)-[:EXPOSES_API]->(api:API)-[:HAS_ENDPOINT]->(endpoint:Endpoint)
RETURN app.name as Application, 
       endpoint.method as Method, 
       endpoint.path as Path, 
       endpoint.description as Description
ORDER BY endpoint.path
```

## Step 7: Customize Visualization

### Change Node Colors

Click on a node type in the legend (left side) and customize:
- **Color**: Change node color
- **Size**: Adjust node size based on properties
- **Caption**: Change displayed text

### Recommended Settings

1. **Application nodes**: Blue, size 50, caption: `name`
2. **Topic nodes**: Green, size 40, caption: `name`
3. **Producer/Consumer nodes**: Orange, size 35, caption: `client_id`
4. **DataStore nodes**: Purple, size 35, caption: `name`

## Step 8: Export Visualizations

### Export as Image

1. Click the **Download** icon (⬇) in the visualization panel
2. Choose **PNG** or **SVG** format
3. Save to your desired location

### Export Data as CSV

```cypher
// Export all nodes
MATCH (n)
RETURN id(n) as NodeId, labels(n) as Labels, properties(n) as Properties

// Export all relationships
MATCH (n)-[r]->(m)
RETURN id(n) as FromNode, type(r) as RelationType, id(m) as ToNode, properties(r) as Properties
```

Click the **Download** icon and select **CSV**.

## Useful Neo4j Browser Commands

```cypher
// Clear the canvas
:clear

// Show database info
:sysinfo

// Show all node labels
CALL db.labels()

// Show all relationship types
CALL db.relationshipTypes()

// Show database schema
CALL db.schema.visualization()

// Get help
:help

// Show keyboard shortcuts
:help keys
```

## Advanced: Create Custom Queries

### Find Shortest Path Between Applications

```cypher
MATCH path = shortestPath(
  (app1:Application {name: 'iot-usage-kafka-logger'})-[*]-(app2:Application {name: 'fixium-mobile-consumer'})
)
RETURN path
```

### Find All Paths of Specific Length

```cypher
MATCH path = (app:Application)-[*2..3]-(other)
WHERE app.name = 'iot-usage-kafka-logger'
RETURN path
LIMIT 25
```

### Aggregate Statistics

```cypher
// Count nodes by type
MATCH (n)
RETURN labels(n)[0] as NodeType, count(n) as Count
ORDER BY Count DESC

// Count relationships by type
MATCH ()-[r]->()
RETURN type(r) as RelationType, count(r) as Count
ORDER BY Count DESC
```

## Troubleshooting

### Neo4j Won't Start

```bash
# Check logs
docker logs kafka-knowledge-graph-neo4j

# Restart container
docker-compose -f docker-compose.neo4j.yml restart

# Remove and recreate
docker-compose -f docker-compose.neo4j.yml down -v
docker-compose -f docker-compose.neo4j.yml up -d
```

### Can't Connect to Neo4j Browser

1. Verify Neo4j is running: `docker ps`
2. Check port 7474 is not in use: `lsof -i :7474` (Mac/Linux) or `netstat -ano | findstr :7474` (Windows)
3. Try accessing: `http://127.0.0.1:7474`
4. Check firewall settings

### Data Not Loading

1. Verify the init-graph.cypher file exists
2. Check for syntax errors in the Cypher script
3. Run queries one section at a time
4. Check Neo4j logs for errors

### Performance Issues

```cypher
// Create indexes for better performance
CREATE INDEX app_name_idx IF NOT EXISTS FOR (a:Application) ON (a.name);
CREATE INDEX topic_name_idx IF NOT EXISTS FOR (t:Topic) ON (t.name);
CREATE INDEX consumer_group_name_idx IF NOT EXISTS FOR (cg:ConsumerGroup) ON (cg.name);
```

## Stopping Neo4j

```bash
# Stop Neo4j
docker-compose -f docker-compose.neo4j.yml stop

# Stop and remove (keeps data)
docker-compose -f docker-compose.neo4j.yml down

# Stop and remove everything including data
docker-compose -f docker-compose.neo4j.yml down -v
```

## Next Steps

1. **Extend the Graph**: Add more applications, topics, or components
2. **Real-time Updates**: Create scripts to sync with actual Kafka cluster
3. **Monitoring**: Add metrics and monitoring data
4. **Documentation**: Generate documentation from the graph
5. **Analysis**: Use graph algorithms (PageRank, Community Detection, etc.)

## Resources

- [Neo4j Documentation](https://neo4j.com/docs/)
- [Cypher Query Language](https://neo4j.com/docs/cypher-manual/current/)
- [Neo4j Browser Guide](https://neo4j.com/docs/browser-manual/current/)
- [Graph Data Science Library](https://neo4j.com/docs/graph-data-science/current/)

---

**Made with Bob** 🤖