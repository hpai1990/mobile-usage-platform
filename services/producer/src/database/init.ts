import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Database file path (in project root)
const DB_PATH = path.join(__dirname, '../../usage.db');

/**
 * Initialize the SQLite database and create tables if they don't exist
 */
export function initializeDatabase(): Database.Database {
  const db = new Database(DB_PATH);
  
  // Enable foreign keys
  db.pragma('foreign_keys = ON');
  
  // Create mobile_usage table
  db.exec(`
    CREATE TABLE IF NOT EXISTS mobile_usage (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id TEXT NOT NULL,
      usage REAL NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      package_type TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      CHECK (usage >= 0)
    )
  `);
  
  // Create indexes for better query performance
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_device_id ON mobile_usage(device_id);
    CREATE INDEX IF NOT EXISTS idx_package_type ON mobile_usage(package_type);
    CREATE INDEX IF NOT EXISTS idx_created_at ON mobile_usage(created_at);
  `);
  
  console.log('✅ Database initialized successfully');
  console.log(`📁 Database location: ${DB_PATH}`);
  
  return db;
}

/**
 * Get database instance (singleton pattern)
 */
let dbInstance: Database.Database | null = null;

export function getDatabase(): Database.Database {
  if (!dbInstance) {
    dbInstance = initializeDatabase();
  }
  return dbInstance;
}

/**
 * Close database connection
 */
export function closeDatabase(): void {
  if (dbInstance) {
    dbInstance.close();
    dbInstance = null;
    console.log('🔒 Database connection closed');
  }
}

// Made with Bob
