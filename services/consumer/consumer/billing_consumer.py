#!/usr/bin/env python3
"""
Mobile Data Usage Billing Consumer

Consumes mobile usage events from Kafka and generates billing information.
Aggregates data in memory and logs billing info every 10 seconds.
"""

import json
import logging
import signal
import sys
import threading
import time
from collections import defaultdict
from datetime import datetime
from typing import Dict, Any

from confluent_kafka import Consumer, KafkaError, KafkaException

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class BillingAggregator:
    """Aggregates mobile usage data and calculates billing information."""
    
    # Billing rate: $0.10 per MB
    RATE_PER_MB = 0.10
    
    def __init__(self):
        self.device_usage: Dict[str, Dict[str, Any]] = defaultdict(lambda: {
            'total_usage_mb': 0.0,
            'total_cost': 0.0,
            'event_count': 0,
            'first_seen': None,
            'last_seen': None
        })
        self.lock = threading.Lock()
        self.total_events = 0
        self.total_usage_mb = 0.0
        self.total_cost = 0.0
    
    def add_usage(self, device_id: str, usage_mb: float, timestamp: str):
        """Add usage data for a device."""
        with self.lock:
            device = self.device_usage[device_id]
            
            # Update device-specific stats
            device['total_usage_mb'] += usage_mb
            device['total_cost'] = device['total_usage_mb'] * self.RATE_PER_MB
            device['event_count'] += 1
            device['last_seen'] = timestamp
            
            if device['first_seen'] is None:
                device['first_seen'] = timestamp
            
            # Update overall stats
            self.total_events += 1
            self.total_usage_mb += usage_mb
            self.total_cost = self.total_usage_mb * self.RATE_PER_MB
    
    def get_billing_report(self) -> Dict[str, Any]:
        """Generate billing report."""
        with self.lock:
            return {
                'timestamp': datetime.utcnow().isoformat(),
                'overall': {
                    'total_events': self.total_events,
                    'total_usage_mb': round(self.total_usage_mb, 2),
                    'total_cost_usd': round(self.total_cost, 2),
                    'unique_devices': len(self.device_usage)
                },
                'devices': {
                    device_id: {
                        'usage_mb': round(data['total_usage_mb'], 2),
                        'cost_usd': round(data['total_cost'], 2),
                        'events': data['event_count'],
                        'first_seen': data['first_seen'],
                        'last_seen': data['last_seen']
                    }
                    for device_id, data in sorted(
                        self.device_usage.items(),
                        key=lambda x: x[1]['total_cost'],
                        reverse=True
                    )
                }
            }


class MobileUsageConsumer:
    """Kafka consumer for mobile usage events."""
    
    def __init__(self, config: Dict[str, str], topic: str = 'mobile-usage'):
        self.config = config
        self.topic = topic
        self.consumer = None
        self.aggregator = BillingAggregator()
        self.running = False
        self.report_thread = None
    
    def setup_consumer(self):
        """Initialize Kafka consumer."""
        self.consumer = Consumer(self.config)
        self.consumer.subscribe([self.topic])
        logger.info(f"Subscribed to topic: {self.topic}")
    
    def process_message(self, msg):
        """Process a single Kafka message."""
        try:
            # Parse JSON message
            data = json.loads(msg.value().decode('utf-8'))
            
            # Extract fields
            device_id = data.get('device_id')
            usage_mb = data.get('usage', 0)
            start_time = data.get('start_time')
            end_time = data.get('end_time')
            
            # Validate required fields
            if not device_id:
                logger.warning("Message missing device_id, skipping")
                return
            
            # Add to aggregator
            self.aggregator.add_usage(device_id, usage_mb, end_time or start_time)
            
            logger.debug(
                f"Processed: device={device_id}, usage={usage_mb}MB, "
                f"time={start_time} to {end_time}"
            )
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse message as JSON: {e}")
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    def report_billing_info(self):
        """Periodically log billing information."""
        while self.running:
            time.sleep(10)  # Report every 10 seconds
            
            if not self.running:
                break
            
            report = self.aggregator.get_billing_report()
            
            # Log formatted report
            logger.info("=" * 80)
            logger.info("BILLING REPORT")
            logger.info("=" * 80)
            logger.info(f"Report Time: {report['timestamp']}")
            logger.info("")
            logger.info("OVERALL STATISTICS:")
            logger.info(f"  Total Events Processed: {report['overall']['total_events']}")
            logger.info(f"  Total Usage: {report['overall']['total_usage_mb']} MB")
            logger.info(f"  Total Cost: ${report['overall']['total_cost_usd']:.2f}")
            logger.info(f"  Unique Devices: {report['overall']['unique_devices']}")
            logger.info("")
            
            if report['devices']:
                logger.info("TOP DEVICES BY COST:")
                for i, (device_id, device_data) in enumerate(
                    list(report['devices'].items())[:10], 1
                ):
                    logger.info(
                        f"  {i}. Device {device_id}: "
                        f"{device_data['usage_mb']} MB, "
                        f"${device_data['cost_usd']:.2f}, "
                        f"{device_data['events']} events"
                    )
            logger.info("=" * 80)
    
    def start(self):
        """Start consuming messages."""
        self.setup_consumer()
        self.running = True
        
        # Start reporting thread
        self.report_thread = threading.Thread(target=self.report_billing_info)
        self.report_thread.daemon = True
        self.report_thread.start()
        
        logger.info("Consumer started. Waiting for messages...")
        
        try:
            while self.running:
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    continue
                
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        logger.debug(f"Reached end of partition: {msg.partition()}")
                    else:
                        raise KafkaException(msg.error())
                else:
                    self.process_message(msg)
                    
        except KeyboardInterrupt:
            logger.info("Interrupted by user")
        finally:
            self.stop()
    
    def stop(self):
        """Stop the consumer gracefully."""
        logger.info("Stopping consumer...")
        self.running = False
        
        if self.report_thread:
            self.report_thread.join(timeout=2)
        
        if self.consumer:
            # Print final report
            logger.info("\nFINAL BILLING REPORT:")
            report = self.aggregator.get_billing_report()
            logger.info(json.dumps(report, indent=2))
            
            self.consumer.close()
            logger.info("Consumer stopped")


def main():
    """Main entry point."""
    # Kafka consumer configuration
    config = {
        'bootstrap.servers': 'kafka:9092',
        'group.id': 'mobile-billing-consumer',
        'auto.offset.reset': 'earliest',
        'enable.auto.commit': True
    }
    
    # Topic name
    topic = 'mobile-usage'
    
    # Create and start consumer
    consumer = MobileUsageConsumer(config, topic)
    
    # Handle graceful shutdown
    def signal_handler(signum, frame):
        logger.info(f"Received signal {signum}")
        consumer.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start consuming
    consumer.start()


if __name__ == '__main__':
    main()

# Made with Bob
