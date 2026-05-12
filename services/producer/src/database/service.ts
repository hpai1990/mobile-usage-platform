import { getDatabase } from './init.js';
import type Database from 'better-sqlite3';

export interface MobileUsageData {
  device_id: string;
  usage: number;
  start_time: string;
  end_time: string;
  package_type: string;
}

export interface MobileUsageRecord extends MobileUsageData {
  id: number;
  created_at: string;
}

export interface UsageStats {
  total_records: number;
  total_usage: number;
  unique_devices: number;
  package_types: { package_type: string; count: number }[];
}

export interface QueryOptions {
  limit?: number;
  offset?: number;
  device_id?: string;
  package_type?: string;
  start_date?: string;
  end_date?: string;
}

/**
 * Insert mobile usage data into the database
 */
export function insertUsageData(data: MobileUsageData): MobileUsageRecord {
  const db = getDatabase();
  
  const stmt = db.prepare(`
    INSERT INTO mobile_usage (device_id, usage, start_time, end_time, package_type)
    VALUES (?, ?, ?, ?, ?)
  `);
  
  const info = stmt.run(
    data.device_id,
    data.usage,
    data.start_time,
    data.end_time,
    data.package_type
  );
  
  // Retrieve the inserted record
  const selectStmt = db.prepare('SELECT * FROM mobile_usage WHERE id = ?');
  const record = selectStmt.get(info.lastInsertRowid) as MobileUsageRecord;
  
  return record;
}

/**
 * Get all usage data with optional filtering and pagination
 */
export function getAllUsageData(options: QueryOptions = {}): MobileUsageRecord[] {
  const db = getDatabase();
  const { limit = 100, offset = 0, device_id, package_type, start_date, end_date } = options;
  
  let query = 'SELECT * FROM mobile_usage WHERE 1=1';
  const params: any[] = [];
  
  if (device_id) {
    query += ' AND device_id = ?';
    params.push(device_id);
  }
  
  if (package_type) {
    query += ' AND package_type = ?';
    params.push(package_type);
  }
  
  if (start_date) {
    query += ' AND created_at >= ?';
    params.push(start_date);
  }
  
  if (end_date) {
    query += ' AND created_at <= ?';
    params.push(end_date);
  }
  
  query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);
  
  const stmt = db.prepare(query);
  const records = stmt.all(...params) as MobileUsageRecord[];
  
  return records;
}

/**
 * Get usage data by device ID
 */
export function getUsageByDevice(deviceId: string, limit = 100): MobileUsageRecord[] {
  return getAllUsageData({ device_id: deviceId, limit });
}

/**
 * Get usage data by package type
 */
export function getUsageByPackageType(packageType: string, limit = 100): MobileUsageRecord[] {
  return getAllUsageData({ package_type: packageType, limit });
}

/**
 * Get usage statistics
 */
export function getUsageStats(): UsageStats {
  const db = getDatabase();
  
  // Total records and usage
  const totalStmt = db.prepare(`
    SELECT 
      COUNT(*) as total_records,
      COALESCE(SUM(usage), 0) as total_usage,
      COUNT(DISTINCT device_id) as unique_devices
    FROM mobile_usage
  `);
  const totals = totalStmt.get() as { total_records: number; total_usage: number; unique_devices: number };
  
  // Package type breakdown
  const packageStmt = db.prepare(`
    SELECT package_type, COUNT(*) as count
    FROM mobile_usage
    GROUP BY package_type
    ORDER BY count DESC
  `);
  const packageTypes = packageStmt.all() as { package_type: string; count: number }[];
  
  return {
    total_records: totals.total_records,
    total_usage: totals.total_usage,
    unique_devices: totals.unique_devices,
    package_types: packageTypes
  };
}

/**
 * Delete usage data by ID
 */
export function deleteUsageData(id: number): boolean {
  const db = getDatabase();
  
  const stmt = db.prepare('DELETE FROM mobile_usage WHERE id = ?');
  const info = stmt.run(id);
  
  return info.changes > 0;
}

/**
 * Get total count of records (for pagination)
 */
export function getTotalCount(options: QueryOptions = {}): number {
  const db = getDatabase();
  const { device_id, package_type, start_date, end_date } = options;
  
  let query = 'SELECT COUNT(*) as count FROM mobile_usage WHERE 1=1';
  const params: any[] = [];
  
  if (device_id) {
    query += ' AND device_id = ?';
    params.push(device_id);
  }
  
  if (package_type) {
    query += ' AND package_type = ?';
    params.push(package_type);
  }
  
  if (start_date) {
    query += ' AND created_at >= ?';
    params.push(start_date);
  }
  
  if (end_date) {
    query += ' AND created_at <= ?';
    params.push(end_date);
  }
  
  const stmt = db.prepare(query);
  const result = stmt.get(...params) as { count: number };
  
  return result.count;
}

// Made with Bob
