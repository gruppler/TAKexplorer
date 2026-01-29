FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create data directory
RUN mkdir -p /tmp/takexplorer_data

# Cloud Run uses PORT environment variable
ENV PORT=8080

# Use gunicorn with appropriate settings for Cloud Run
# - Single worker to minimize memory
# - Multiple threads for concurrency
# - Timeout of 0 for long-running requests (Cloud Run handles timeouts)
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 wsgi:app
