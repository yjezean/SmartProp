#!/usr/bin/env python3
"""
FastAPI Application
Provides HTTP API endpoints for the Flutter mobile app
"""
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, timezone, timedelta
# GMT+8 timezone
GMT8 = timezone(timedelta(hours=8))
import psycopg2
from psycopg2.extras import RealDictCursor
import pandas as pd
import numpy as np
import config
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/sprop/api.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="SProp Monitoring API",
    description="API for IoT SProp Monitoring System",
    version="1.0.0"
)

# Configure CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection helper
def get_db_connection():
    """Create and return a database connection with SSL/TLS"""
    return psycopg2.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        database=config.DB_NAME,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        sslmode=config.DB_SSL_MODE
    )

# Pydantic models for API requests/responses
class SensorDataPoint(BaseModel):
    timestamp: datetime
    temperature: float
    humidity: float

class SensorDataResponse(BaseModel):
    data: List[SensorDataPoint]


# API Endpoints
@app.get("/")
async def root():
    """Root endpoint - API information"""
    return {
        "name": "SProp Monitoring API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/api/v1/sensor-data", response_model=SensorDataResponse)
async def get_sensor_data(
    days: int = Query(7, ge=1, le=365, description="Number of days of data to retrieve")
):
    """
    Get historical sensor data
    Returns temperature and humidity data for the specified number of days
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Query sensor data
        # Note: Database timestamps are stored as UTC but actually contain GMT+8 values
        # So we need to treat them as GMT+8 when querying
        
        # Calculate date range in GMT+8
        # Add 1 minute buffer to end_date to ensure we capture the very latest data
        end_date_gmt8 = datetime.now(GMT8) + timedelta(minutes=1)
        start_date_gmt8 = end_date_gmt8 - timedelta(days=days)
        
        # Convert to UTC for database query (database thinks it's UTC but it's actually GMT+8)
        # Since data is stored as GMT+8 values in UTC fields, we subtract 8 hours to match
        end_date_utc = end_date_gmt8.astimezone(timezone.utc) - timedelta(hours=8)
        start_date_utc = start_date_gmt8.astimezone(timezone.utc) - timedelta(hours=8)
        
        # Try date-filtered query
        # Exclude obviously invalid timestamps (future dates more than 1 day ahead)
        cursor.execute(
            """
            SELECT timestamp, temperature, humidity
            FROM sensor_data
            WHERE timestamp >= %s 
              AND timestamp <= %s
              AND timestamp <= NOW() + INTERVAL '1 day'
            ORDER BY timestamp ASC
            """,
            (start_date_utc, end_date_utc)
        )
        
        rows = cursor.fetchall()
        
        # Always ensure we have the absolute latest record, even if it's slightly outside the range
        # This handles race conditions where data arrives during query execution
        # Exclude obviously invalid timestamps (future dates more than 1 day ahead)
        cursor.execute(
            """
            SELECT timestamp, temperature, humidity
            FROM sensor_data
            WHERE timestamp <= NOW() + INTERVAL '1 day'
            ORDER BY timestamp DESC
            LIMIT 1
            """
        )
        latest_row = cursor.fetchone()
        
        # If we got data from date filter, check if latest record is already included
        if len(rows) > 0 and latest_row:
            # Check if latest record is already in our results
            latest_timestamp = latest_row['timestamp']
            if not any(row['timestamp'] == latest_timestamp for row in rows):
                # Latest record not in results, add it
                rows.append(latest_row)
                logger.info(f"Added latest record ({latest_timestamp}) to results")
        
        # If no data found with date filter, get latest records regardless of date
        if len(rows) == 0:
            logger.warning(f"No data found for last {days} days. Using fallback: latest records.")
            # Get latest records (limit based on days: roughly 1 record per 5 seconds = ~17k per day)
            limit = min(days * 17280, 10000)  # Max 10k records
            cursor.execute(
                """
                SELECT timestamp, temperature, humidity
                FROM sensor_data
                WHERE timestamp <= NOW() + INTERVAL '1 day'
                ORDER BY timestamp DESC
                LIMIT %s
                """,
                (limit,)
            )
            rows = cursor.fetchall()
            # Reverse to get chronological order
            rows = list(reversed(rows))
            logger.info(f"Fallback query returned {len(rows)} latest records")
        
        # Sort by timestamp to ensure chronological order
        rows = sorted(rows, key=lambda x: x['timestamp'])
        
        cursor.close()
        conn.close()
        
        # Convert to list of SensorDataPoint
        # Database timestamps are stored as UTC but actually contain GMT+8 time values
        # Fix: Convert to real UTC (subtract 8h), return as UTC
        # Frontend will automatically convert UTC to local timezone (GMT+8) = correct display
        data = []
        for row in rows:
            timestamp = row['timestamp']
            
            # The timestamp is stored as UTC but the time value is actually GMT+8
            # Example: Database has 19:11:36+00, but 19:11 is actually GMT+8 time
            # Real UTC time should be: 19:11 - 8 = 11:11 UTC
            # Return as UTC: 11:11:36+00:00
            # Frontend (GMT+8) will convert: 11:11 UTC + 8 = 19:11 GMT+8 (correct!)
            if timestamp.tzinfo is None:
                # If no timezone, assume UTC
                timestamp = timestamp.replace(tzinfo=timezone.utc)
            
            # Convert from "fake UTC" (which is actually GMT+8) to real UTC
            if timestamp.tzinfo == timezone.utc:
                # Subtract 8 hours to get actual UTC time
                # This converts the GMT+8 time value to real UTC
                timestamp = timestamp - timedelta(hours=8)
                # Keep as UTC - frontend will convert to local timezone automatically
            else:
                # Already in different timezone, convert to UTC
                timestamp = timestamp.astimezone(timezone.utc)
            
            data.append(SensorDataPoint(
                timestamp=timestamp,
                temperature=float(row['temperature']),
                humidity=float(row['humidity'])
            ))
        
        logger.info(f"Retrieved {len(data)} sensor data points for last {days} days")
        return SensorDataResponse(data=data)
        
    except Exception as e:
        logger.error(f"Error retrieving sensor data: {e}")
        import traceback
        logger.error(traceback.format_exc())
        # Ensure connection is closed on error
        try:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Error retrieving sensor data: {str(e)}")

# Optimization Settings Endpoints

class OptimizationStatus(BaseModel):
    enabled: bool

@app.get("/api/v1/optimization/status", response_model=OptimizationStatus)
async def get_optimization_status():
    """
    Get current optimization (automated control) status
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute(
            """
            SELECT setting_value
            FROM system_settings
            WHERE setting_key = 'optimization_enabled'
            """
        )
        
        row = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not row:
            # Default to enabled if not found
            return OptimizationStatus(enabled=True)
        
        enabled = row['setting_value'].lower() == 'true'
        return OptimizationStatus(enabled=enabled)
        
    except Exception as e:
        logger.error(f"Error retrieving optimization status: {e}")
        # Default to enabled on error
        return OptimizationStatus(enabled=True)

@app.put("/api/v1/optimization/status", response_model=OptimizationStatus)
async def set_optimization_status(status: OptimizationStatus):
    """
    Set optimization (automated control) status
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            """
            INSERT INTO system_settings (setting_key, setting_value, description, updated_at)
            VALUES ('optimization_enabled', %s, 'Automated temperature and humidity control optimization', CURRENT_TIMESTAMP)
            ON CONFLICT (setting_key) 
            DO UPDATE SET 
                setting_value = EXCLUDED.setting_value,
                updated_at = CURRENT_TIMESTAMP
            """,
            (str(status.enabled).lower(),)
        )
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Optimization status updated to: {status.enabled}")
        return status
        
    except Exception as e:
        logger.error(f"Error updating optimization status: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating optimization status: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    
    # Configure SSL if certificates are provided
    ssl_keyfile = config.API_SSL_KEYFILE if config.API_SSL_KEYFILE else None
    ssl_certfile = config.API_SSL_CERTFILE if config.API_SSL_CERTFILE else None
    
    if ssl_keyfile and ssl_certfile:
        logger.info(f"Starting HTTPS server on {config.API_HOST}:{config.API_PORT}")
        uvicorn.run(
            "main:app",
            host=config.API_HOST,
            port=config.API_PORT,
            log_level="info",
            ssl_keyfile=ssl_keyfile,
            ssl_certfile=ssl_certfile
        )
    else:
        logger.warning("SSL certificates not configured - starting HTTP server (not recommended for production)")
        uvicorn.run(
            "main:app",
            host=config.API_HOST,
            port=config.API_PORT,
            log_level="info"
        )

