#!/bin/bash

# Setup IAM permissions for Cloud Scheduler and Cloud Function

set -euo pipefail

# Configuration
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
FUNCTION_NAME="takexplorer-db-updater"
SCHEDULER_NAME="takexplorer-db-update-schedule"

echo "Setting up IAM permissions for TAKexplorer database updater..."
echo "Project: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"

APP_ENGINE_SA="${PROJECT_ID}@appspot.gserviceaccount.com"

echo "App Engine Service Account (used by Scheduler OIDC): $APP_ENGINE_SA"

FUNCTION_RUNTIME_SA=$(gcloud functions describe "$FUNCTION_NAME" --gen2 --region=us-central1 --format='value(serviceConfig.serviceAccountEmail)' 2>/dev/null || true)
if [ -n "$FUNCTION_RUNTIME_SA" ]; then
    echo "Function Runtime Service Account: $FUNCTION_RUNTIME_SA"
fi

# Grant the Scheduler's OIDC service account permission to invoke the function.
# For Cloud Functions Gen2, invocation permission is managed on the underlying Cloud Run service.
echo "Granting Cloud Run Invoker permission to Scheduler caller identity..."

RUN_SERVICE_FULL_NAME=$(gcloud functions describe "$FUNCTION_NAME" --gen2 --region=us-central1 --format='value(serviceConfig.service)' 2>/dev/null || true)
if [ -n "$RUN_SERVICE_FULL_NAME" ]; then
    RUN_SERVICE_NAME=$(basename "$RUN_SERVICE_FULL_NAME")
    gcloud run services add-iam-policy-binding "$RUN_SERVICE_NAME" \
        --region=us-central1 \
        --member="serviceAccount:$APP_ENGINE_SA" \
        --role="roles/run.invoker"
else
    gcloud functions add-iam-policy-binding "$FUNCTION_NAME" \
        --region=us-central1 \
        --member="serviceAccount:$APP_ENGINE_SA" \
        --role="roles/cloudfunctions.invoker"
fi

# Grant App Engine service account Cloud Storage permissions
echo "Granting Cloud Storage permissions to App Engine service account..."
gsutil iam ch "serviceAccount:$APP_ENGINE_SA:objectAdmin" "gs://${PROJECT_ID}-takexplorer-db"

if [ -n "${FUNCTION_RUNTIME_SA:-}" ]; then
    echo "Granting Cloud Storage permissions to Cloud Function runtime service account..."
    gsutil iam ch "serviceAccount:${FUNCTION_RUNTIME_SA}:objectAdmin" "gs://${PROJECT_ID}-takexplorer-db"
fi

echo "IAM permissions configured!"
echo ""
echo "Summary of permissions:"
echo "- Cloud Scheduler can invoke the database updater function"
echo "- App Engine can read/write the database in Cloud Storage"
echo "- Invocation is granted to the service account configured in the scheduler job"
