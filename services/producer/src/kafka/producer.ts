import { Kafka, type Producer } from 'kafkajs';

let producer: Producer | null = null;
let isConnected = false;

export async function initializeKafkaProducer(): Promise<void> {
  try {
    const kafka = new Kafka({
      clientId: 'iot-usage-logger',
      brokers: [process.env.KAFKA_BROKER || 'localhost:29092'],
      retry: {
        initialRetryTime: 100,
        retries: 8
      }
    });

    producer = kafka.producer();
    
    await producer.connect();
    isConnected = true;
    console.log('✅ Kafka producer connected to:', process.env.KAFKA_BROKER || 'localhost:29092');
  } catch (error) {
    console.error('❌ Failed to initialize Kafka producer:', error);
    console.log('📝 API will continue without Kafka integration');
    producer = null;
    isConnected = false;
  }
}

export async function sendToKafka(topic: string, data: any): Promise<void> {
  if (!producer || !isConnected) {
    console.warn('⚠️  Kafka producer not available, skipping message');
    return;
  }

  try {
    await producer.send({
      topic,
      messages: [
        {
          key: data.device_id,
          value: JSON.stringify(data),
          timestamp: Date.now().toString()
        }
      ]
    });
    console.log(`📤 Sent to Kafka topic '${topic}': device=${data.device_id}, usage=${data.usage}MB`);
  } catch (error) {
    console.error('❌ Failed to send to Kafka:', error);
    // Don't throw - allow API to continue working even if Kafka fails
  }
}

export async function closeKafkaProducer(): Promise<void> {
  if (producer && isConnected) {
    try {
      await producer.disconnect();
      isConnected = false;
      console.log('🛑 Kafka producer disconnected');
    } catch (error) {
      console.error('Error disconnecting Kafka producer:', error);
    }
  }
}

export function isKafkaConnected(): boolean {
  return isConnected;
}

// Made with Bob
