# TAKexplorer App Engine Deployment Guide

Deploy TAKexplorer on Google Cloud App Engine with automatic database updates from playtak.com.

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
gcloud services enable appengine.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

## Step 2: Prepare TAKexplorer for App Engine

1. **Clone TAKexplorer**:

```bash
git clone https://github.com/gruppler/TAKexplorer.git
cd TAKexplorer
```

2. **Add App Engine configuration**:

   - `app.yaml` - App Engine configuration (included)
   - `requirements.txt` - Dependencies (included)
   - `main.py` - App Engine entry point (included)
   - `database_migration.py` - Cloud Storage integration (included)

3. **Verify main application file**:
   - The `main.py` automatically detects the original TAKexplorer app
   - Supports `server.py`, `app.py`, `main.py`, or `wsgi.py` entry points

## Step 3: Handle Database Persistence

**Important**: App Engine has ephemeral filesystem. **Cloud Storage is strongly recommended** for TAKexplorer.

### Recommended: Cloud Storage

**Why Cloud Storage for TAKexplorer:**

- Database lives independently of your repository
- No merge conflicts when pulling upstream updates
- Shared across all branches of your fork
- Database survives code changes and redeploys

**Setup:**

1. Database stored in Cloud Storage bucket
2. Download to `/tmp` on app startup
3. Upload back when database is modified
4. Cloud Function handles periodic updates

## Step 4: Deploy to App Engine

```bash
# Deploy the application
gcloud app deploy

# Promote to traffic (if prompted)
# Deploy may take 5-10 minutes first time
```

## Step 5: Verify Deployment

```bash
# Browse to your app
gcloud app browse

# Or visit: https://your-project-id.uc.r.appspot.com
```

## Step 6: Setup Periodic Database Updates

TAKexplorer needs to periodically download and process game data from playtak.com. Here's how to set up automated updates using Cloud Scheduler and Cloud Functions.

### Deploy Database Updater Function

```bash
# Navigate to the function directory
cd database_updater_function

# Make deploy script executable
chmod +x deploy.sh

# Deploy the Cloud Function
./deploy.sh
```

### Setup Cloud Scheduler

```bash
# Navigate back to project root
cd ..

# Make scheduler setup script executable
chmod +x setup_scheduler.sh

# Create the scheduled job
./setup_scheduler.sh
```

### Configure IAM Permissions

```bash
# Make permissions script executable
chmod +x setup_permissions.sh

# Setup required permissions
./setup_permissions.sh
```

### Test the Database Update

```bash
# Test the function manually
gcloud functions call takexplorer-db-updater --region=us-central1

# Or test the scheduler job
gcloud scheduler jobs run takexplorer-db-update-schedule
```

### Monitor Database Updates

```bash
# View function logs
gcloud functions logs read takexplorer-db-updater --region=us-central1 --limit=50

# View scheduler job status
gcloud scheduler jobs describe takexplorer-db-update-schedule
```

## Step 7: Monitor and Debug

```bash
# View logs
gcloud app logs tail -s default

# Check app status
gcloud app describe
```

## Configuration Files

### app.yaml

- Runtime: Python 3.11
- Instance class: F2 (2GB RAM)
- Automatic scaling with 0-2 instances

### requirements.txt

- Flask web framework
- Waitress WSGI server
- Gunicorn (App Engine requirement)
- Google Cloud Storage for database persistence

### main.py

- App Engine entry point
- Automatic detection of TAKexplorer app
- Database management endpoints
- Fork-aware configuration

### database_migration.py

- Cloud Storage integration
- Database backup functionality
- Fork metadata tracking

## Troubleshooting

### Common Issues:

1. **Import errors**: Ensure all dependencies are in requirements.txt
2. **Database connection errors**: Check Cloud Storage bucket permissions
3. **Timeout errors**: Increase instance class or optimize code
4. **Memory errors**: Upgrade to F4 instance class

### Debug Commands:

```bash
# View detailed logs
gcloud app logs tail -s default --severity=ERROR

# SSH into instance for debugging
gcloud app instances ssh

# Test database connection
curl https://your-app-url/admin/database-info
```

## Cost Considerations

- **Free tier**: App Engine provides generous free tier
- **Instance hours**: F2 instances cost ~$0.08/hour
- **Storage**: Minimal for database file
- **Cloud Function**: Free tier covers most usage
- **Scheduler**: ~$0.10 per month
- **Total**: Typically <$5/month for moderate usage

## Next Steps

1. **Set up custom domain**: Configure domain mapping
2. **Add SSL certificate**: Enable HTTPS
3. **Set up monitoring**: Cloud Monitoring integration
4. **Configure CI/CD**: Cloud Build automated deployments

## Production Recommendations

1. **Use Cloud Storage**: For persistent database storage
2. **Add monitoring**: Error tracking and performance metrics
3. **Implement caching**: Redis or Memorystore
4. **Set up alerts**: For uptime and performance
5. **Configure scaling**: Based on traffic patterns
