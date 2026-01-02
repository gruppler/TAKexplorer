# App Engine Database Scheduler Setup

This directory contains the Cloud Scheduler setup for automatic database updates from playtak.com for TAKexplorer on App Engine.

## Architecture

```
Cloud Scheduler (daily trigger)
    ↓
Cloud Function (database_updater)
    ↓
Downloads from playtak.com API
    ↓
Processes and updates SQLite database
    ↓
Stores in Cloud Storage
    ↓
Main App Engine app reads from Cloud Storage
```

## Files

- `database_updater_function/main.py` - Cloud Function code
- `database_updater_function/requirements.txt` - Function dependencies
- `database_updater_function/deploy.sh` - Deployment script
- `setup_scheduler.sh` - Creates the scheduled job
- `setup_permissions.sh` - Configures IAM permissions

## Setup Instructions

### 1. Deploy the Cloud Function

```bash
cd database_updater_function
chmod +x deploy.sh
./deploy.sh
```

### 2. Create the Scheduler Job

```bash
cd ..
chmod +x setup_scheduler.sh
./setup_scheduler.sh
```

### 3. Configure IAM Permissions

```bash
chmod +x setup_permissions.sh
./setup_permissions.sh
```

## Configuration

### Schedule
- Default: Daily at 2 AM UTC
- To change: Edit `SCHEDULE="0 2 * * *"` in `setup_scheduler.sh`

### Function Settings
- Timeout: 9 minutes (540 seconds)
- Memory: 1GB
- Region: us-central1

### Database Storage
- Bucket: `{project-id}-takexplorer-db`
- File: `takexplorer.db`

## Testing

### Manual Function Test
```bash
gcloud functions call takexplorer-db-updater --region=us-central1
```

### Scheduler Test
```bash
gcloud scheduler jobs run takexplorer-db-update-schedule
```

### View Logs
```bash
gcloud functions logs read takexplorer-db-updater --region=us-central1 --limit=50
```

## Monitoring

### Check Scheduler Status
```bash
gcloud scheduler jobs describe takexplorer-db-update-schedule
```

### View Execution History
```bash
gcloud scheduler jobs describe takexplorer-db-update-schedule --format='yaml(status.lastAttemptTime)'
```

### Function Metrics
```bash
gcloud functions metrics list
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Run `./setup_permissions.sh`
2. **Function Not Found**: Deploy function first with `./deploy.sh`
3. **Timeout**: Increase timeout in `deploy.sh`
4. **Memory Issues**: Increase memory allocation

### Debug Commands

```bash
# Check function logs
gcloud functions logs read takexplorer-db-updater --region=us-central1

# Check scheduler logs
gcloud logging read "resource.type=cloud_scheduler_job" --limit=10

# Test function locally
cd database_updater_function
python3 main.py
```

## Cost

- **Cloud Function**: Free tier covers most usage
- **Cloud Scheduler**: ~$0.10 per job per month
- **Cloud Storage**: Minimal for database file
- **Total**: Typically <$1/month

## Customization

### Change Update Frequency
Edit the schedule in `setup_scheduler.sh`:
- Hourly: `0 * * * *`
- Weekly: `0 2 * * 0`
- Custom: Use cron format

### Modify Database Logic
Edit `database_updater_function/main.py`:
- Change API endpoint
- Update database schema
- Modify processing logic

### Add Notifications
Add error handling to send alerts:
- Email via SendGrid
- Slack webhook
- Cloud Monitoring alerts

## App Engine Integration

The scheduler integrates seamlessly with the App Engine deployment:

1. **Shared Database**: Both app and function use the same Cloud Storage database
2. **Automatic Updates**: Database updates happen automatically without app restarts
3. **Fork-Friendly**: Works with fork-based workflow
4. **Scalable**: Independent scaling from main app

## Security

- **Authentication**: Uses OIDC tokens for secure scheduler-to-function communication
- **Least Privilege**: Service accounts have minimal required permissions
- **Network**: All communication stays within Google Cloud network
- **Data**: Database encrypted at rest in Cloud Storage
