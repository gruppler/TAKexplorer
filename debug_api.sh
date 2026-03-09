#!/bin/bash

# Debug script for TAKexplorer API issues

echo "=== TAKexplorer API Debugging ==="
echo "Time: $(date)"
echo ""

# Check service status
echo "1. Service Status:"
gcloud run services describe takexplorer --region us-central1 --format="table(status.conditions[0].type, status.conditions[0].status, status.latestReadyRevisionName)"
echo ""

# Check recent 504 errors
echo "2. Recent 504 Errors (last hour):"
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="takexplorer" httpRequest.status=504' --limit 5 --format="table(timestamp,httpRequest.requestUrl,httpRequest.latency)" --freshness=1h
echo ""

# Check cold starts
echo "3. Recent Cold Starts:"
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="takexplorer" textPayload:"Cloud environment detected"' --limit 5 --format="value(timestamp)" --freshness=2h
echo ""

# Check database downloads
echo "4. Recent Database Downloads:"
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="takexplorer" textPayload:"Downloaded from Cloud Storage"' --limit 5 --format="table(timestamp,textPayload)" --freshness=2h
echo ""

# Check instance count
echo "5. Instance Count:"
gcloud run services describe takexplorer --region us-central1 --format="value(status.latestReadyRevisionName)" | xargs -I {} gcloud run revisions describe {} --region us-central1 --format="table(spec.containerConcurrency, status.actualReplicas)"
echo ""

# Test health endpoint
echo "6. Testing Health Endpoint:"
SERVICE_URL=$(gcloud run services describe takexplorer --region us-central1 --format="value(status.url)")
curl -s -w "\nStatus: %{http_code}\nTime: %{time_total}s\n" "$SERVICE_URL/health" 2>/dev/null || echo "Failed to reach health endpoint"
echo ""

# Check for long-running requests (latency stored as duration string, filter by 504s as proxy)
echo "7. Long-running Requests (504s as proxy for slow requests):"
gcloud logging read 'resource.type="cloud_run_revision" resource.labels.service_name="takexplorer" httpRequest.status=504' --limit 5 --format="table(timestamp,httpRequest.requestMethod,httpRequest.requestUrl,httpRequest.latency)" --freshness=1h
echo ""

echo "=== Debug Complete ==="
