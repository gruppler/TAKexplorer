#!/usr/bin/env python3
"""
Cloud Function for updating TAKexplorer database from playtak.com
Triggered by Cloud Scheduler on a periodic schedule
"""

import os
import requests
import tempfile
import logging
from google.cloud import storage
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DatabaseUpdater:
    def __init__(self):
        self.storage_client = storage.Client()
        self.bucket_name = os.environ.get('DB_BUCKET_NAME')
        self.bucket = self.storage_client.bucket(self.bucket_name) if self.bucket_name else None
        self.db_file = os.environ.get('PLAYTAK_DB_OBJECT', 'games_anon.db')
        self.source_url = os.environ.get('PLAYTAK_SOURCE_URL', 'https://www.playtak.com/games_anon.db')
        
    def download_playtak_data(self):
        """Download latest game data from playtak.com"""
        try:
            # Playtak.com API endpoint (adjust based on actual API)
            api_url = self.source_url
            logger.info(f"Downloading data from {api_url}")
            
            response = requests.get(api_url, timeout=300)  # 5 minute timeout
            response.raise_for_status()
            
            # Save to temporary file
            temp_dir = tempfile.gettempdir()
            temp_file = os.path.join(temp_dir, self.db_file)
            
            with open(temp_file, 'wb') as f:
                f.write(response.content)
                
            logger.info(f"Downloaded {len(response.content)} bytes to {temp_file}")
            return temp_file
            
        except Exception as e:
            logger.error(f"Error downloading from playtak.com: {e}")
            raise
    
    def upload_database(self, db_path):
        """Upload updated database to Cloud Storage"""
        try:
            if not self.bucket:
                logger.warning("No Cloud Storage bucket configured, skipping upload")
                return False
                
            blob = self.bucket.blob(self.db_file)
            blob.upload_from_filename(db_path)
            
            # Set metadata
            blob.metadata = {
                'updated_at': datetime.utcnow().isoformat(),
                'source': 'cloud-function'
            }
            blob.patch()
            
            logger.info(f"Uploaded database to Cloud Storage: gs://{self.bucket_name}/{self.db_file}")
            return True
            
        except Exception as e:
            logger.error(f"Error uploading database: {e}")
            raise

def update_takexplorer_database(request):
    """Cloud Function entry point"""
    try:
        logger.info("Starting TAKexplorer database update")
        
        updater = DatabaseUpdater()
        
        # Step 1: Download latest database from playtak.com
        db_path = updater.download_playtak_data()

        # Step 2: Upload database to Cloud Storage
        updater.upload_database(db_path)

        # Cleanup
        os.remove(db_path)
        
        result = {
            'status': 'success',
            'object': updater.db_file,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        logger.info(f"Database update completed: {result}")
        return result, 200
        
    except Exception as e:
        logger.error(f"Database update failed: {e}")
        return {
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }, 500

# For local testing
if __name__ == "__main__":
    # Mock request for testing
    class MockRequest:
        pass
    
    result, status = update_takexplorer_database(MockRequest())
    print(f"Result: {result}")
    print(f"Status: {status}")
