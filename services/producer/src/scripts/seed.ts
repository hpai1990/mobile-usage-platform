import { initializeDatabase, closeDatabase } from '../database/init.js';
import { insertUsageData, type MobileUsageData } from '../database/service.js';

/**
 * Seed script to populate the database with sample data
 */

// Sample data with various package types
const sampleData: MobileUsageData[] = [
  {
    device_id: 'device-001',
    usage: 1024.5,
    start_time: '2026-05-10T08:00:00.000Z',
    end_time: '2026-05-10T09:00:00.000Z',
    package_type: 'prepaid'
  },
  {
    device_id: 'device-002',
    usage: 2048.75,
    start_time: '2026-05-10T09:00:00.000Z',
    end_time: '2026-05-10T10:00:00.000Z',
    package_type: 'postpaid'
  },
  {
    device_id: 'device-003',
    usage: 512.25,
    start_time: '2026-05-10T10:00:00.000Z',
    end_time: '2026-05-10T11:00:00.000Z',
    package_type: 'unlimited'
  },
  {
    device_id: 'device-001',
    usage: 768.0,
    start_time: '2026-05-10T11:00:00.000Z',
    end_time: '2026-05-10T12:00:00.000Z',
    package_type: 'prepaid'
  },
  {
    device_id: 'device-004',
    usage: 3072.5,
    start_time: '2026-05-10T12:00:00.000Z',
    end_time: '2026-05-10T13:00:00.000Z',
    package_type: 'family-plan'
  },
  {
    device_id: 'device-005',
    usage: 1536.25,
    start_time: '2026-05-10T13:00:00.000Z',
    end_time: '2026-05-10T14:00:00.000Z',
    package_type: 'corporate'
  },
  {
    device_id: 'device-002',
    usage: 2560.0,
    start_time: '2026-05-10T14:00:00.000Z',
    end_time: '2026-05-10T15:00:00.000Z',
    package_type: 'postpaid'
  },
  {
    device_id: 'device-003',
    usage: 896.5,
    start_time: '2026-05-10T15:00:00.000Z',
    end_time: '2026-05-10T16:00:00.000Z',
    package_type: 'unlimited'
  },
  {
    device_id: 'device-006',
    usage: 1280.75,
    start_time: '2026-05-11T08:00:00.000Z',
    end_time: '2026-05-11T09:00:00.000Z',
    package_type: 'prepaid'
  },
  {
    device_id: 'device-007',
    usage: 4096.0,
    start_time: '2026-05-11T09:00:00.000Z',
    end_time: '2026-05-11T10:00:00.000Z',
    package_type: 'unlimited'
  }
];

async function seed() {
  console.log('🌱 Starting database seeding...\n');

  try {
    // Initialize database
    initializeDatabase();

    // Insert sample data
    let successCount = 0;
    let errorCount = 0;

    for (const data of sampleData) {
      try {
        const record = insertUsageData(data);
        console.log(`✅ Inserted record ${record.id}: ${data.device_id} (${data.package_type})`);
        successCount++;
      } catch (error) {
        console.error(`❌ Failed to insert data for ${data.device_id}:`, error);
        errorCount++;
      }
    }

    console.log(`\n📊 Seeding Summary:`);
    console.log(`   ✅ Successfully inserted: ${successCount} records`);
    console.log(`   ❌ Failed: ${errorCount} records`);
    console.log(`   📦 Total: ${sampleData.length} records`);

    // Close database connection
    closeDatabase();

    console.log('\n✨ Database seeding completed!\n');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error during seeding:', error);
    closeDatabase();
    process.exit(1);
  }
}

// Run the seed function
seed();

// Made with Bob
