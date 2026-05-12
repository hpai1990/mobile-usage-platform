import express from 'express';
import type { Request, Response } from 'express';
import { initializeDatabase, closeDatabase } from './src/database/init.js';
import {
  insertUsageData,
  getAllUsageData,
  getUsageByDevice,
  getUsageByPackageType,
  getUsageStats,
  deleteUsageData,
  getTotalCount,
  type MobileUsageData,
  type QueryOptions
} from './src/database/service.js';
import { initializeKafkaProducer, sendToKafka, closeKafkaProducer, isKafkaConnected } from './src/kafka/producer.js';

const app = express();
const PORT = process.env.PORT || 3000;

// Initialize database on startup
initializeDatabase();

// Initialize Kafka producer
initializeKafkaProducer().catch(err => {
  console.error('⚠️  Failed to initialize Kafka producer:', err);
  console.log('📝 API will continue without Kafka integration');
});

// Middleware to parse JSON bodies
app.use(express.json());

// POST endpoint for /mobile-usage
app.post('/mobile-usage', async (req: Request, res: Response) => {
  try {
    const { device_id, usage, start_time, end_time, package_type }: MobileUsageData = req.body;

    // Validate required parameters
    if (!device_id || usage === undefined || !start_time || !end_time || !package_type) {
      return res.status(400).json({
        error: 'Missing required parameters',
        required: ['device_id', 'usage', 'start_time', 'end_time', 'package_type'],
        received: req.body
      });
    }

    // Validate usage is a number
    if (typeof usage !== 'number' || usage < 0) {
      return res.status(400).json({
        error: 'Invalid usage value',
        message: 'Usage must be a non-negative number'
      });
    }

    // Validate package_type is a non-empty string
    if (typeof package_type !== 'string' || package_type.trim() === '') {
      return res.status(400).json({
        error: 'Invalid package_type',
        message: 'package_type must be a non-empty string'
      });
    }

    // Validate date formats
    const startDate = new Date(start_time);
    const endDate = new Date(end_time);

    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      return res.status(400).json({
        error: 'Invalid date format',
        message: 'start_time and end_time must be valid ISO 8601 date strings'
      });
    }

    if (endDate <= startDate) {
      return res.status(400).json({
        error: 'Invalid time range',
        message: 'end_time must be after start_time'
      });
    }

    // Prepare usage data
    const usageData: MobileUsageData = {
      device_id,
      usage,
      start_time,
      end_time,
      package_type: package_type.trim()
    };

    // Save to database
    const savedRecord = insertUsageData(usageData);

    console.log('✅ Saved mobile usage data:', savedRecord);

    // Send data to Kafka topic
    await sendToKafka('mobile-usage', {
      device_id: usageData.device_id,
      usage: usageData.usage,
      start_time: usageData.start_time,
      end_time: usageData.end_time
    });

    // Return success response
    return res.status(201).json({
      message: 'Mobile usage data received and stored successfully',
      data: savedRecord,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error processing mobile usage data:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to process mobile usage data'
    });
  }
});

// GET endpoint to retrieve all usage data with filtering and pagination
app.get('/mobile-usage', (req: Request, res: Response) => {
  try {
    const {
      limit = '100',
      offset = '0',
      device_id,
      package_type,
      start_date,
      end_date
    } = req.query;

    // Parse and validate pagination parameters
    const parsedLimit = Math.min(parseInt(limit as string, 10) || 100, 1000);
    const parsedOffset = parseInt(offset as string, 10) || 0;

    if (parsedLimit < 1 || parsedOffset < 0) {
      return res.status(400).json({
        error: 'Invalid pagination parameters',
        message: 'limit must be >= 1 and offset must be >= 0'
      });
    }

    // Build query options
    const options: QueryOptions = {
      limit: parsedLimit,
      offset: parsedOffset
    };

    if (device_id) options.device_id = device_id as string;
    if (package_type) options.package_type = package_type as string;
    if (start_date) options.start_date = start_date as string;
    if (end_date) options.end_date = end_date as string;

    // Get data and total count
    const records = getAllUsageData(options);
    const totalCount = getTotalCount(options);

    return res.status(200).json({
      data: records,
      pagination: {
        limit: parsedLimit,
        offset: parsedOffset,
        total: totalCount,
        returned: records.length
      },
      filters: {
        device_id: device_id || null,
        package_type: package_type || null,
        start_date: start_date || null,
        end_date: end_date || null
      }
    });

  } catch (error) {
    console.error('Error retrieving usage data:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to retrieve usage data'
    });
  }
});

// GET endpoint to retrieve usage data by device ID
app.get('/mobile-usage/device/:device_id', (req: Request, res: Response) => {
  try {
    const { device_id } = req.params;
    
    if (!device_id) {
      return res.status(400).json({
        error: 'Missing device_id parameter'
      });
    }
    
    const { limit = '100' } = req.query;

    const parsedLimit = Math.min(parseInt(limit as string, 10) || 100, 1000);

    const records = getUsageByDevice(device_id, parsedLimit);

    return res.status(200).json({
      device_id,
      data: records,
      count: records.length
    });

  } catch (error) {
    console.error('Error retrieving usage data by device:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to retrieve usage data by device'
    });
  }
});

// GET endpoint to retrieve usage data by package type
app.get('/mobile-usage/package/:package_type', (req: Request, res: Response) => {
  try {
    const { package_type } = req.params;
    
    if (!package_type) {
      return res.status(400).json({
        error: 'Missing package_type parameter'
      });
    }
    
    const { limit = '100' } = req.query;

    const parsedLimit = Math.min(parseInt(limit as string, 10) || 100, 1000);

    const records = getUsageByPackageType(package_type, parsedLimit);

    return res.status(200).json({
      package_type,
      data: records,
      count: records.length
    });

  } catch (error) {
    console.error('Error retrieving usage data by package type:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to retrieve usage data by package type'
    });
  }
});

// GET endpoint to retrieve usage statistics
app.get('/mobile-usage/stats', (req: Request, res: Response) => {
  try {
    const stats = getUsageStats();

    return res.status(200).json({
      statistics: stats,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error retrieving usage statistics:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to retrieve usage statistics'
    });
  }
});

// DELETE endpoint to remove a usage record
app.delete('/mobile-usage/:id', (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    
    if (!id) {
      return res.status(400).json({
        error: 'Missing id parameter'
      });
    }
    
    const recordId = parseInt(id, 10);

    if (isNaN(recordId) || recordId < 1) {
      return res.status(400).json({
        error: 'Invalid ID',
        message: 'ID must be a positive integer'
      });
    }

    const deleted = deleteUsageData(recordId);

    if (!deleted) {
      return res.status(404).json({
        error: 'Record not found',
        message: `No record found with ID ${recordId}`
      });
    }

    return res.status(200).json({
      message: 'Record deleted successfully',
      id: recordId
    });

  } catch (error) {
    console.error('Error deleting usage data:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to delete usage data'
    });
  }
});

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({
    status: 'healthy',
    database: 'connected',
    kafka: isKafkaConnected() ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  await closeKafkaProducer();
  closeDatabase();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n🛑 Shutting down gracefully...');
  await closeKafkaProducer();
  closeDatabase();
  process.exit(0);
});

// Start the server
app.listen(PORT, () => {
  console.log(`🚀 Server is running on port ${PORT}`);
  console.log(`📱 POST /mobile-usage - Submit usage data`);
  console.log(`📊 GET /mobile-usage - Retrieve all usage data (with filters)`);
  console.log(`🔍 GET /mobile-usage/device/:device_id - Get usage by device`);
  console.log(`📦 GET /mobile-usage/package/:package_type - Get usage by package type`);
  console.log(`📈 GET /mobile-usage/stats - Get usage statistics`);
  console.log(`🗑️  DELETE /mobile-usage/:id - Delete a usage record`);
  console.log(`💚 GET /health - Health check`);
});

// Made with Bob
