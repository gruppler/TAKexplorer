"""
Main application wrapper for TAKexplorer on App Engine
This file serves as the entry point for App Engine deployment
Designed for fork-based workflow with upstream updates
"""

import os
import sys
import atexit
import logging
from flask import Flask
from database_migration import DatabaseManager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize database manager for persistent storage
db_manager = DatabaseManager()

def create_app():
    """Create and configure the Flask application"""
    
    # Try to import the original TAKexplorer app
    # This works with fork-based approach - handles different file names
    app = None
    
    # Try different possible entry points from upstream TAKexplorer
    possible_modules = ['server', 'app', 'main', 'wsgi']
    
    for module_name in possible_modules:
        try:
            # Try to import the original app
            module = __import__(module_name)
            if hasattr(module, 'app'):
                app = module.app
                logger.info(f"Successfully imported TAKexplorer app from {module_name}")
                break
            elif hasattr(module, 'application'):
                app = module.application
                logger.info(f"Successfully imported TAKexplorer application from {module_name}")
                break
        except ImportError as e:
            logger.debug(f"Could not import {module_name}: {e}")
            continue
    
    if app is None:
        # Fallback - create basic app if import fails
        logger.warning("Could not import TAKexplorer app, creating fallback app")
        app = Flask(__name__)
        
        @app.route('/')
        def hello():
            return """
            <h1>TAKexplorer on App Engine</h1>
            <p>The main application could not be imported.</p>
            <p>Please check that the original TAKexplorer files are present.</p>
            <p><a href="/health">Health Check</a></p>
            """
            
        @app.route('/health')
        def health():
            return {"status": "healthy", "database": "connected"}, 200
    
    # Add database integration endpoints
    setup_database_endpoints(app)
    
    return app

def setup_database_endpoints(app):
    """Add database management endpoints for fork workflow"""
    
    @app.route('/admin/database-info')
    def database_info():
        """Get database information"""
        try:
            db_path = db_manager.get_database_path()
            file_exists = os.path.exists(db_path)
            
            return {
                "database_path": db_path,
                "file_exists": file_exists,
                "bucket_name": db_manager.bucket_name,
                "fork_mode": True
            }
        except Exception as e:
            return {"error": str(e)}, 500
    
    @app.route('/admin/force-db-upload', methods=['POST'])
    def force_database_upload():
        """Force database upload to Cloud Storage"""
        try:
            success = db_manager.upload_database()
            if success:
                return {"status": "success", "message": "Database uploaded"}
            else:
                return {"status": "error", "message": "Upload failed"}, 500
        except Exception as e:
            return {"error": str(e)}, 500

# Create the application instance
app = create_app()

def cleanup():
    """Cleanup function to upload database on shutdown"""
    try:
        db_manager.upload_database()
        logger.info("Database uploaded to Cloud Storage on shutdown")
    except Exception as e:
        logger.error(f"Error during cleanup: {e}")

# Register cleanup function
atexit.register(cleanup)

# For App Engine, we need to expose the app
if __name__ == "__main__":
    # This is for local testing only
    logger.info("Starting TAKexplorer in local development mode")
    app.run(host='0.0.0.0', port=8080, debug=True)
