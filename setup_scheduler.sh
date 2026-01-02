#!/bin/bash

# Setup Cloud Scheduler to trigger database updates

set -euo pipefail

# Configuration
PROJECT_ID=$(gcloud config get-value project)
FUNCTION_NAME="takexplorer-db-updater"
REGION="us-central1"
SCHEDULER_NAME="takexplorer-db-update-schedule"
SCHEDULE="0 2 * * *"  # Daily at 2 AM UTC
TIMEZONE="UTC"

echo "Setting up Cloud Scheduler for TAKexplorer database updates..."
echo "Project: $PROJECT_ID"
echo "Scheduler: $SCHEDULER_NAME"
echo "Schedule: $SCHEDULE"

# Get the Cloud Function URL
FUNCTION_URL=$(gcloud functions describe "$FUNCTION_NAME" --gen2 --region="$REGION" --format='value(serviceConfig.uri)' 2>/dev/null)

if [ -z "$FUNCTION_URL" ]; then
    FUNCTION_URL=$(gcloud functions describe "$FUNCTION_NAME" --region="$REGION" --format='value(httpsTrigger.url)' 2>/dev/null)
fi

if [ -z "$FUNCTION_URL" ]; then
    echo "Error: Could not get function URL. Make sure the function is deployed first."
    exit 1
fi

echo "Function URL: $FUNCTION_URL"

# Enable Cloud Scheduler API
echo "Enabling Cloud Scheduler API..."
gcloud services enable cloudscheduler.googleapis.com

# Create the scheduler job
echo "Creating scheduler job..."
gcloud scheduler jobs create http $SCHEDULER_NAME \
    --schedule="$SCHEDULE" \
    --time-zone="$TIMEZONE" \
    --http-method=POST \
    --uri="$FUNCTION_URL" \
    --description="Update TAKexplorer database from playtak.com" \
    --oidc-service-account-email="${PROJECT_ID}@appspot.gserviceaccount.com" \
    --oidc-token-audience="$FUNCTION_URL"

echo "Scheduler job created!"
echo ""
echo "To test the scheduler job manually:"
echo "gcloud scheduler jobs run $SCHEDULER_NAME"
echo ""
echo "To view scheduler job details:"
echo "gcloud scheduler jobs describe $SCHEDULER_NAME"
echo ""
echo "To view job execution history:"
echo "gcloud scheduler jobs describe $SCHEDULER_NAME --format='yaml(status.lastAttemptTime)'"
