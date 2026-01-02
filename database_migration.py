#!/usr/bin/env python3
"""
Database migration helper for TAKexplorer on App Engine
Handles persistent storage using Cloud Storage
Optimized for fork-based workflow with upstream updates
"""

import os
import sqlite3
import tempfile
import logging
from google.cloud import storage
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DatabaseManager:
    def __init__(self, bucket_name=None, local_db_path="takexplorer.db"):
        self.bucket_name = bucket_name or os.environ.get('DB_BUCKET_NAME')
        self.local_db_path = local_db_path
        self.storage_client = storage.Client()
        self.bucket = None
        self.fork_mode = True  # Optimized for fork workflow
        
        if self.bucket_name:
            self.bucket = self.storage_client.bucket(self.bucket_name)
            logger.info(f"Database manager initialized with bucket: {self.bucket_name}")
        else:
            logger.warning("No Cloud Storage bucket configured, using local database only")
    
    def download_database(self):
        """Download database from Cloud Storage to local temp directory"""
        if not self.bucket:
            logger.info("No Cloud Storage bucket configured, using local database")
            return False
            
        try:
            # Use /tmp for writable storage in App Engine
            temp_dir = tempfile.gettempdir()
            local_path = os.path.join(temp_dir, self.local_db_path)
            
            blob = self.bucket.blob(self.local_db_path)
            if blob.exists():
                blob.download_to_filename(local_path)
                logger.info(f"Downloaded database to {local_path}")
                
                # Log database metadata for fork tracking
                metadata = blob.metadata or {}
                if metadata:
                    logger.info(f"Database metadata: {metadata}")
                
                return local_path
            else:
                logger.info(f"No database found in Cloud Storage at {self.local_db_path}")
                return None
        except Exception as e:
            logger.error(f"Error downloading database: {e}")
            return False
    
    def upload_database(self, local_path=None, metadata=None):
        """Upload local database to Cloud Storage with fork metadata"""
        if not self.bucket:
            logger.info("No Cloud Storage bucket configured, skipping upload")
            return False
            
        try:
            source_path = local_path or os.path.join(tempfile.gettempdir(), self.local_db_path)
            
            if os.path.exists(source_path):
                blob = self.bucket.blob(self.local_db_path)
                
                # Prepare metadata for fork tracking
                upload_metadata = {
                    'updated_at': datetime.utcnow().isoformat(),
                    'source': 'app-engine',
                    'fork_mode': str(self.fork_mode),
                    'file_size': str(os.path.getsize(source_path))
                }
                
                # Add any additional metadata
                if metadata:
                    upload_metadata.update(metadata)
                
                blob.metadata = upload_metadata
                blob.upload_from_filename(source_path)
                
                logger.info(f"Uploaded database to Cloud Storage with metadata: {upload_metadata}")
                return True
            else:
                logger.warning(f"Local database not found at {source_path}")
                return False
        except Exception as e:
            logger.error(f"Error uploading database: {e}")
            return False
    
    def get_database_path(self):
        """Get the path to the database file with fallback logic"""
        # Try to download from Cloud Storage first
        downloaded_path = self.download_database()
        if downloaded_path and os.path.exists(downloaded_path):
            return downloaded_path
            
        # Fall back to local temp directory
        temp_path = os.path.join(tempfile.gettempdir(), self.local_db_path)
        logger.info(f"Using local database path: {temp_path}")
        return temp_path
    
    def backup_database(self):
        """Create a backup of the current database"""
        if not self.bucket:
            logger.warning("No Cloud Storage bucket, cannot create backup")
            return False
            
        try:
            # Create backup filename with timestamp
            timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
            backup_name = f"backup_{timestamp}_{self.local_db_path}"
            
            current_db_path = self.get_database_path()
            if os.path.exists(current_db_path):
                backup_blob = self.bucket.blob(backup_name)
                backup_blob.upload_from_filename(current_db_path)
                
                backup_metadata = {
                    'backup_at': datetime.utcnow().isoformat(),
                    'original_file': self.local_db_path,
                    'backup_type': 'fork_workflow'
                }
                backup_blob.metadata = backup_metadata
                backup_blob.patch()
                
                logger.info(f"Created database backup: {backup_name}")
                return backup_name
            else:
                logger.warning("No database file found to backup")
                return False
        except Exception as e:
            logger.error(f"Error creating backup: {e}")
            return False
    
    def get_database_info(self):
        """Get information about the current database"""
        info = {
            'bucket_name': self.bucket_name,
            'local_path': self.get_database_path(),
            'fork_mode': self.fork_mode,
            'file_exists': False,
            'file_size': 0,
            'cloud_metadata': {}
        }
        
        # Check local file
        if os.path.exists(info['local_path']):
            info['file_exists'] = True
            info['file_size'] = os.path.getsize(info['local_path'])
        
        # Check Cloud Storage metadata
        if self.bucket:
            try:
                blob = self.bucket.blob(self.local_db_path)
                if blob.exists():
                    info['cloud_metadata'] = blob.metadata or {}
                    info['cloud_updated'] = blob.updated.isoformat() if blob.updated else None
            except Exception as e:
                logger.warning(f"Could not fetch cloud metadata: {e}")
        
        return info

# Example usage in your Flask app:
"""
from database_migration import DatabaseManager

# Initialize database manager
db_manager = DatabaseManager()

# Get database path for SQLite connection
db_path = db_manager.get_database_path()
conn = sqlite3.connect(db_path)

# When shutting down or after major changes:
db_manager.upload_database(db_path, metadata={'manual_upload': True})

# Create backup before major changes:
backup_name = db_manager.backup_database()
"""
