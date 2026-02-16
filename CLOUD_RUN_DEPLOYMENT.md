# TAKexplorer Cloud Run Deployment Guide

Deploy TAKexplorer on Google Cloud Run with automatic database updates from playtak.com.

## Prerequisites

1. **Google Cloud Account**: Create a free account at https://console.cloud.google.com
2. **Google Cloud SDK**: Install and initialize gcloud CLI
3. **TAKexplorer Source Code**: This repository

## Step 1: Setup Google Cloud Project

```bash
# Install Google Cloud SDK
# Follow: https://cloud.google.com/sdk/docs/install

# Initialize gcloud
gcloud init

# Create a new project (or use existing)
gcloud projects create your-project-id

# Set your project
gcloud config set project your-project-id

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
```

## Step 2: Create Cloud Storage Bucket

```bash
# Create bucket for database storage (use your project ID)
gsutil mb -l us-central1 gs://your-project-id-db

# Upload initial databases (if you have them locally)
gsutil -m cp data/*.db gs://your-project-id-db/
```

## Step 3: Deploy to Cloud Run

```bash
# Deploy from source (builds container automatically)
gcloud run deploy takexplorer \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DB_BUCKET_NAME=your-project-id-db \
  --memory 1Gi \
  --timeout 900 \
  --concurrency 80
```

Your service will be available at: `https://takexplorer-XXXXXXXXXX.us-central1.run.app`

## Step 4: Setup Periodic Database Updates

### Deploy Database Updater Function

```bash
cd database_updater_function
chmod +x deploy.sh
./deploy.sh
```

### Setup Cloud Scheduler

```bash
cd ..
chmod +x setup_scheduler.sh
./setup_scheduler.sh
```

## Step 5: Configure CORS (Optional)

Edit `server.py` to add your domains to the CORS origins:

```python
CORS(app, origins=[
    "https://ptn.ninja",
    "https://next.ptn.ninja",
    "https://dev.ptn.ninja",
    # Add your domains here
], supports_credentials=True)
```

Then redeploy:

```bash
gcloud run deploy takexplorer --source . --region us-central1
```

## Configuration Files

### Dockerfile

- Python 3.11 slim image
- Gunicorn WSGI server with 1 worker, 8 threads
- Uses `/tmp` for writable storage

### Environment Variables

| Variable         | Description                                  |
| ---------------- | -------------------------------------------- |
| `DB_BUCKET_NAME` | Cloud Storage bucket for databases           |
| `PORT`           | Server port (set automatically by Cloud Run) |

## How It Works

1. **Cold Start**: When a new instance starts, it downloads databases lazily on first request
2. **Database Updates**: Cloud Function runs daily to update `games_anon.db` in Cloud Storage
3. **Scaling**: Cloud Run scales to 0 when idle, scales up on demand

## Cost Comparison

| Service                 | Monthly Cost     |
| ----------------------- | ---------------- |
| Cloud Run (light usage) | ~$5-10           |
| Cloud Function          | Free tier        |
| Cloud Scheduler         | ~$0.10           |
| Cloud Storage           | ~$1-2            |
| **Total**               | **~$6-12/month** |

vs App Engine F4 always-on: ~$60/month

## Monitoring

```bash
# View Cloud Run logs
gcloud run services logs read takexplorer --region us-central1

# View Cloud Function logs
gcloud functions logs read takexplorer-db-updater --region us-central1

# Check service status
gcloud run services describe takexplorer --region us-central1
```

## Updating the Service

```bash
# Redeploy after code changes
gcloud run deploy takexplorer --source . --region us-central1 --memory 2Gi
```

## Troubleshooting

### Cold Start Slow

- First request downloads databases from Cloud Storage (~50-60MB per DB)
- Subsequent requests are fast
- Cloud Run keeps instances warm for ~15 minutes

### Timeout Errors

- Increase timeout: `--timeout 300` (max 60 minutes)

### Database Not Found

- Check Cloud Storage bucket exists and has databases
- Verify `DB_BUCKET_NAME` environment variable is set
- Check service account has storage permissions

## Migrating from App Engine

If you previously used App Engine:

1. App Engine cannot be fully deleted, but set `max_instances: 0` in `app.yaml` to prevent charges
2. Delete old versions: `gcloud app versions delete VERSION_ID`
3. Update any DNS/domain mappings to point to Cloud Run URL
