FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for confluent-kafka
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    librdkafka-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY consumer/ ./consumer/

# Make the consumer script executable
RUN chmod +x consumer/billing_consumer.py

# Run the consumer
CMD ["python", "-u", "consumer/billing_consumer.py"]

# Made with Bob
