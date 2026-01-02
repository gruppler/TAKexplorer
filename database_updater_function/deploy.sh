#!/bin/bash

# Deploy Cloud Function for database updates

# Configuration
PROJECT_ID=$(gcloud config get-value project)
FUNCTION_NAME="takexplorer-db-updater"
REGION="us-central1"
BUCKET_NAME="${PROJECT_ID}-takexplorer-db"

echo "Deploying TAKexplorer database updater function..."
echo "Project: $PROJECT_ID"
echo "Function: $FUNCTION_NAME"
echo "Region: $REGION"

# Create Cloud Storage bucket for database (if it doesn't exist)
if ! gsutil ls "gs://$BUCKET_NAME" &>/dev/null; then
    echo "Creating Cloud Storage bucket: $BUCKET_NAME"
    gsutil mb "gs://$BUCKET_NAME"
    gsutil uniformbucketlevelaccess set on "gs://$BUCKET_NAME"
fi

# Deploy Cloud Function
gcloud functions deploy $FUNCTION_NAME \
    --runtime=python311 \
    --region=$REGION \
    --source=. \
    --entry-point=update_takexplorer_database \
    --trigger-http \
    --allow-unauthenticated \
    --set-env-vars=DB_BUCKET_NAME=$BUCKET_NAME \
    --timeout=540 \
    --memory=1024MB

echo "Function deployed!"

FUNCTION_URL=$(gcloud functions describe "$FUNCTION_NAME" --gen2 --region="$REGION" --format='value(serviceConfig.uri)' 2>/dev/null)
if [ -z "$FUNCTION_URL" ]; then
    FUNCTION_URL=$(gcloud functions describe "$FUNCTION_NAME" --region="$REGION" --format='value(httpsTrigger.url)' 2>/dev/null)
fi

echo "Function URL: ${FUNCTION_URL}"
