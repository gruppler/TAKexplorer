#!/bin/bash

# Setup Cloud Scheduler to trigger database updates via Cloud Run endpoint

set -euo pipefail

# Configuration
PROJECT_ID=$(gcloud config get-value project)
SERVICE_NAME="takexplorer"
REGION="us-central1"
SCHEDULER_NAME="takexplorer-db-update-schedule"
SCHEDULE="0 17 * * *"  # Daily at 17:00 UTC (matches original scheduler time)
TIMEZONE="UTC"

echo "Setting up Cloud Scheduler for TAKexplorer database updates..."
echo "Project: $PROJECT_ID"
echo "Scheduler: $SCHEDULER_NAME"
echo "Schedule: $SCHEDULE"

# Get the Cloud Run service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format='value(status.url)' 2>/dev/null)

if [ -z "$SERVICE_URL" ]; then
    echo "Error: Could not get Cloud Run service URL. Make sure the service is deployed first."
    exit 1
fi

UPDATE_ENDPOINT="${SERVICE_URL}/api/v1/update-databases"
echo "Update endpoint: $UPDATE_ENDPOINT"

# Enable Cloud Scheduler API
echo "Enabling Cloud Scheduler API..."
gcloud services enable cloudscheduler.googleapis.com

# Delete existing job if it exists (to allow updates)
gcloud scheduler jobs delete $SCHEDULER_NAME --location="$REGION" --quiet 2>/dev/null || true

# Create the scheduler job
echo "Creating scheduler job..."
gcloud scheduler jobs create http $SCHEDULER_NAME \
    --location="$REGION" \
    --schedule="$SCHEDULE" \
    --time-zone="$TIMEZONE" \
    --http-method=POST \
    --uri="$UPDATE_ENDPOINT" \
    --description="Update TAKexplorer openings databases from playtak.com" \
    --oidc-service-account-email="${PROJECT_ID}@appspot.gserviceaccount.com" \
    --oidc-token-audience="$SERVICE_URL" \
    --attempt-deadline=900s

echo "Scheduler job created!"
echo ""
echo "To test the scheduler job manually:"
echo "gcloud scheduler jobs run $SCHEDULER_NAME --location=$REGION"
echo ""
echo "To view scheduler job details:"
echo "gcloud scheduler jobs describe $SCHEDULER_NAME --location=$REGION"
echo ""
echo "To view recent executions:"
echo "gcloud logging read 'resource.type=cloud_scheduler_job AND resource.labels.job_id=$SCHEDULER_NAME' --limit=5"
