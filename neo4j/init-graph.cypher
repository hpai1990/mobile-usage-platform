// Kafka Messaging Knowledge Graph - Initialization Script
// Based on iot-usage-kafka-logger and fixium-mobile-consumer applications

// Clear existing data (optional - comment out if you want to preserve existing data)
MATCH (n) DETACH DELETE n;

// ============================================================================
// CREATE KAFKA CLUSTER
// ============================================================================
CREATE (cluster:KafkaCluster {
  id: 'cluster-001',
  name: 'local-kafka-cluster',
  version: '7.5.0',
  bootstrap_servers: ['kafka:9092', 'localhost:29092'],
  environment: 'development',
  replication_factor: 1,
  num_partitions: 1
});

// ============================================================================
// CREATE APPLICATIONS
// ============================================================================
CREATE (producer_app:Application {
  id: 'app-001',
  name: 'iot-usage-kafka-logger',
  type: 'producer',
  language: 'TypeScript',
  framework: 'Express.js',
  version: '1.0.0',
  description: 'IoT Usage Kafka Logger API - REST API for logging mobile device usage data with SQLite storage',
  repository_url: 'https://github.com/purva2412/iot-usage-kafka-logger',
  deployment_type: 'docker'
});

CREATE (consumer_app:Application {
  id: 'app-002',
  name: 'fixium-mobile-consumer',
  type: 'consumer',
  language: 'Python',
  framework: 'confluent-kafka',
  version: '1.0.0',
  description: 'Mobile Data Usage Billing Consumer - Processes usage events and generates billing information',
  deployment_type: 'docker'
});

// ============================================================================
// CREATE TOPICS
// ============================================================================
CREATE (topic:Topic {
  id: 'topic-001',
  name: 'mobile-usage',
  description: 'Mobile device usage data events stream',
  partitions: 1,
  replication_factor: 1,
  retention_ms: 604800000,
  cleanup_policy: 'delete',
  auto_create: true
});

// ============================================================================
// CREATE MESSAGE SCHEMAS
// ============================================================================
CREATE (msg_schema:Message {
  id: 'msg-001',
  schema_name: 'MobileUsageEvent',
  schema_version: '1.0',
  format: 'json',
  key_field: 'device_id',
  timestamp_field: 'end_time',
  schema: '{
    "type": "object",
    "properties": {
      "device_id": {"type": "string", "description": "Unique device identifier"},
      "usage": {"type": "number", "description": "Data usage in MB"},
      "start_time": {"type": "string", "format": "date-time"},
      "end_time": {"type": "string", "format": "date-time"}
    },
    "required": ["device_id", "usage", "start_time", "end_time"]
  }'
});

CREATE (db_schema:Message {
  id: 'msg-002',
  schema_name: 'MobileUsageRecord',
  schema_version: '1.0',
  format: 'json',
  key_field: 'id',
  timestamp_field: 'created_at',
  schema: '{
    "type": "object",
    "properties": {
      "id": {"type": "integer"},
      "device_id": {"type": "string"},
      "usage": {"type": "number"},
      "start_time": {"type": "string"},
      "end_time": {"type": "string"},
      "package_type": {"type": "string"},
      "created_at": {"type": "string"}
    }
  }'
});

// ============================================================================
// CREATE PRODUCER COMPONENT
// ============================================================================
CREATE (producer:Producer {
  id: 'producer-001',
  client_id: 'iot-usage-logger',
  library: 'kafkajs',
  library_version: '2.2.4',
  acks: 'all',
  compression_type: 'none',
  retry_config: '{
    "retries": 8,
    "initial_retry_time": 100
  }'
});

// ============================================================================
// CREATE CONSUMER COMPONENT
// ============================================================================
CREATE (consumer:Consumer {
  id: 'consumer-001',
  group_id: 'mobile-billing-consumer',
  library: 'confluent-kafka',
  library_version: '2.3.0',
  auto_offset_reset: 'earliest',
  enable_auto_commit: true,
  max_poll_records: 500,
  session_timeout_ms: 10000
});

// ============================================================================
// CREATE CONSUMER GROUP
// ============================================================================
CREATE (consumer_group:ConsumerGroup {
  id: 'cg-001',
  name: 'mobile-billing-consumer',
  state: 'stable',
  protocol_type: 'consumer',
  members_count: 1
});

// ============================================================================
// CREATE DATA STORES
// ============================================================================
CREATE (sqlite_db:DataStore {
  id: 'ds-001',
  name: 'usage-database',
  type: 'relational',
  technology: 'SQLite',
  purpose: 'persistence',
  file_path: 'usage.db',
  tables: ['mobile_usage']
});

CREATE (memory_store:DataStore {
  id: 'ds-002',
  name: 'billing-aggregator',
  type: 'in-memory',
  technology: 'Python Dictionary',
  purpose: 'state-store',
  description: 'In-memory aggregation of billing data per device'
});

// ============================================================================
// CREATE API
// ============================================================================
CREATE (rest_api:API {
  id: 'api-001',
  name: 'Mobile Usage API',
  type: 'rest',
  base_url: 'http://localhost:3000',
  version: '1.0',
  authentication: 'none'
});

// ============================================================================
// CREATE ENDPOINTS
// ============================================================================
CREATE (post_endpoint:Endpoint {
  id: 'endpoint-001',
  path: '/mobile-usage',
  method: 'POST',
  description: 'Submit mobile device usage data',
  request_schema: '{
    "device_id": "string",
    "usage": "number",
    "start_time": "string",
    "end_time": "string",
    "package_type": "string"
  }',
  response_schema: '{
    "message": "string",
    "data": "object",
    "timestamp": "string"
  }'
});

CREATE (get_endpoint:Endpoint {
  id: 'endpoint-002',
  path: '/mobile-usage',
  method: 'GET',
  description: 'Retrieve all usage data with filtering and pagination',
  response_schema: '{
    "data": "array",
    "pagination": "object",
    "filters": "object"
  }'
});

CREATE (health_endpoint:Endpoint {
  id: 'endpoint-003',
  path: '/health',
  method: 'GET',
  description: 'Health check endpoint',
  response_schema: '{
    "status": "string",
    "database": "string",
    "kafka": "string",
    "timestamp": "string"
  }'
});

CREATE (stats_endpoint:Endpoint {
  id: 'endpoint-004',
  path: '/mobile-usage/stats',
  method: 'GET',
  description: 'Get usage statistics',
  response_schema: '{
    "statistics": "object",
    "timestamp": "string"
  }'
});

// ============================================================================
// CREATE PROCESSING LOGIC
// ============================================================================
CREATE (validation_logic:ProcessingLogic {
  id: 'logic-001',
  name: 'input-validation',
  type: 'validation',
  description: 'Validates incoming usage data (required fields, data types, date ranges)',
  implementation: 'index.ts:33-78'
});

CREATE (billing_logic:ProcessingLogic {
  id: 'logic-002',
  name: 'billing-aggregation',
  type: 'aggregation',
  description: 'Aggregates usage data per device and calculates billing at $0.10 per MB',
  implementation: 'billing_consumer.py:BillingAggregator'
});

CREATE (reporting_logic:ProcessingLogic {
  id: 'logic-003',
  name: 'billing-reporting',
  type: 'transformation',
  description: 'Generates billing reports every 10 seconds with device-level breakdown',
  implementation: 'billing_consumer.py:report_billing_info'
});

// ============================================================================
// CREATE DEPENDENCIES
// ============================================================================
CREATE (dep1:Dependency {
  id: 'dep-001',
  name: 'express',
  version: '4.18.2',
  type: 'framework',
  purpose: 'Web server framework for REST API'
});

CREATE (dep2:Dependency {
  id: 'dep-002',
  name: 'kafkajs',
  version: '2.2.4',
  type: 'library',
  purpose: 'Kafka client for Node.js'
});

CREATE (dep3:Dependency {
  id: 'dep-003',
  name: 'better-sqlite3',
  version: '12.9.0',
  type: 'library',
  purpose: 'SQLite database driver'
});

CREATE (dep4:Dependency {
  id: 'dep-004',
  name: 'confluent-kafka',
  version: '2.3.0',
  type: 'library',
  purpose: 'Kafka client for Python'
});

CREATE (dep5:Dependency {
  id: 'dep-005',
  name: 'typescript',
  version: '5.3.3',
  type: 'tool',
  purpose: 'Type safety and compilation'
});

// ============================================================================
// CREATE RELATIONSHIPS
// ============================================================================

// Cluster relationships
MATCH (t:Topic {id: 'topic-001'}), (c:KafkaCluster {id: 'cluster-001'})
CREATE (t)-[:BELONGS_TO_CLUSTER {created_at: '2026-05-11T00:00:00Z'}]->(c);

MATCH (app:Application {id: 'app-001'}), (c:KafkaCluster {id: 'cluster-001'})
CREATE (app)-[:CONNECTS_TO_CLUSTER {
  connection_type: 'producer',
  security_protocol: 'PLAINTEXT'
}]->(c);

MATCH (app:Application {id: 'app-002'}), (c:KafkaCluster {id: 'cluster-001'})
CREATE (app)-[:CONNECTS_TO_CLUSTER {
  connection_type: 'consumer',
  security_protocol: 'PLAINTEXT'
}]->(c);

// Producer relationships
MATCH (app:Application {id: 'app-001'}), (p:Producer {id: 'producer-001'})
CREATE (app)-[:HAS_PRODUCER {is_primary: true}]->(p);

MATCH (app:Application {id: 'app-001'}), (t:Topic {id: 'topic-001'})
CREATE (app)-[:PRODUCES_TO {
  message_type: 'MobileUsageEvent',
  rate: 'on-demand',
  trigger: 'HTTP POST request'
}]->(t);

MATCH (p:Producer {id: 'producer-001'}), (t:Topic {id: 'topic-001'})
CREATE (p)-[:PRODUCES_TO]->(t);

// Consumer relationships
MATCH (app:Application {id: 'app-002'}), (c:Consumer {id: 'consumer-001'})
CREATE (app)-[:HAS_CONSUMER {is_primary: true}]->(c);

MATCH (app:Application {id: 'app-002'}), (t:Topic {id: 'topic-001'})
CREATE (app)-[:CONSUMES_FROM {
  message_type: 'MobileUsageEvent',
  processing_type: 'real-time',
  offset_strategy: 'earliest'
}]->(t);

MATCH (c:Consumer {id: 'consumer-001'}), (t:Topic {id: 'topic-001'})
CREATE (c)-[:CONSUMES_FROM]->(t);

// Consumer group relationships
MATCH (c:Consumer {id: 'consumer-001'}), (cg:ConsumerGroup {id: 'cg-001'})
CREATE (c)-[:MEMBER_OF_GROUP {partition_assignment: [0]}]->(cg);

MATCH (cg:ConsumerGroup {id: 'cg-001'}), (t:Topic {id: 'topic-001'})
CREATE (cg)-[:SUBSCRIBES_TO {subscription_pattern: 'mobile-usage'}]->(t);

// Message schema relationships
MATCH (t:Topic {id: 'topic-001'}), (m:Message {id: 'msg-001'})
CREATE (t)-[:USES_MESSAGE_SCHEMA {schema_evolution: 'backward'}]->(m);

MATCH (p:Producer {id: 'producer-001'}), (m:Message {id: 'msg-001'})
CREATE (p)-[:USES_MESSAGE_SCHEMA]->(m);

MATCH (c:Consumer {id: 'consumer-001'}), (m:Message {id: 'msg-001'})
CREATE (c)-[:USES_MESSAGE_SCHEMA]->(m);

// Data store relationships
MATCH (app:Application {id: 'app-001'}), (ds:DataStore {id: 'ds-001'})
CREATE (app)-[:STORES_IN {
  operation_type: 'read-write',
  data_type: 'mobile_usage_records'
}]->(ds);

MATCH (app:Application {id: 'app-002'}), (ds:DataStore {id: 'ds-002'})
CREATE (app)-[:STORES_IN {
  operation_type: 'write',
  data_type: 'billing_aggregates'
}]->(ds);

// API relationships
MATCH (app:Application {id: 'app-001'}), (api:API {id: 'api-001'})
CREATE (app)-[:EXPOSES_API {port: 3000}]->(api);

MATCH (api:API {id: 'api-001'}), (e:Endpoint {id: 'endpoint-001'})
CREATE (api)-[:HAS_ENDPOINT {is_public: true}]->(e);

MATCH (api:API {id: 'api-001'}), (e:Endpoint {id: 'endpoint-002'})
CREATE (api)-[:HAS_ENDPOINT {is_public: true}]->(e);

MATCH (api:API {id: 'api-001'}), (e:Endpoint {id: 'endpoint-003'})
CREATE (api)-[:HAS_ENDPOINT {is_public: true}]->(e);

MATCH (api:API {id: 'api-001'}), (e:Endpoint {id: 'endpoint-004'})
CREATE (api)-[:HAS_ENDPOINT {is_public: true}]->(e);

// Endpoint to producer relationship
MATCH (e:Endpoint {id: 'endpoint-001'}), (p:Producer {id: 'producer-001'})
CREATE (e)-[:TRIGGERS_PRODUCTION {sync_async: 'asynchronous'}]->(p);

// Processing logic relationships
MATCH (e:Endpoint {id: 'endpoint-001'}), (l:ProcessingLogic {id: 'logic-001'})
CREATE (e)-[:APPLIES_LOGIC {order: 1}]->(l);

MATCH (c:Consumer {id: 'consumer-001'}), (l:ProcessingLogic {id: 'logic-002'})
CREATE (c)-[:APPLIES_LOGIC {order: 1}]->(l);

MATCH (c:Consumer {id: 'consumer-001'}), (l:ProcessingLogic {id: 'logic-003'})
CREATE (c)-[:APPLIES_LOGIC {order: 2}]->(l);

// Dependency relationships
MATCH (app:Application {id: 'app-001'}), (d:Dependency {id: 'dep-001'})
CREATE (app)-[:DEPENDS_ON {dependency_type: 'runtime'}]->(d);

MATCH (app:Application {id: 'app-001'}), (d:Dependency {id: 'dep-002'})
CREATE (app)-[:DEPENDS_ON {dependency_type: 'runtime'}]->(d);

MATCH (app:Application {id: 'app-001'}), (d:Dependency {id: 'dep-003'})
CREATE (app)-[:DEPENDS_ON {dependency_type: 'runtime'}]->(d);

MATCH (app:Application {id: 'app-001'}), (d:Dependency {id: 'dep-005'})
CREATE (app)-[:DEPENDS_ON {dependency_type: 'development'}]->(d);

MATCH (app:Application {id: 'app-002'}), (d:Dependency {id: 'dep-004'})
CREATE (app)-[:DEPENDS_ON {dependency_type: 'runtime'}]->(d);

// Application communication
MATCH (producer:Application {id: 'app-001'}), (consumer:Application {id: 'app-002'})
CREATE (producer)-[:COMMUNICATES_WITH {
  protocol: 'kafka',
  direction: 'unidirectional',
  via_topic: 'mobile-usage'
}]->(consumer);

// ============================================================================
// CREATE INDEXES FOR PERFORMANCE
// ============================================================================
CREATE INDEX app_name_idx IF NOT EXISTS FOR (a:Application) ON (a.name);
CREATE INDEX topic_name_idx IF NOT EXISTS FOR (t:Topic) ON (t.name);
CREATE INDEX consumer_group_name_idx IF NOT EXISTS FOR (cg:ConsumerGroup) ON (cg.name);

// Made with Bob