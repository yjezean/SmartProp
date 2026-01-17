#!/usr/bin/env python3
"""
MQTT Listener Service
Subscribes to sensor data from ESP32, saves to PostgreSQL, and implements control logic
"""
import json
import logging
import threading
import time
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict
import paho.mqtt.client as mqtt
import psycopg2
import config
from sprop_calculations import get_combined_control_recommendation

# GMT+8 timezone
GMT8 = timezone(timedelta(hours=8))

# Configure logging with GMT+8 timezone
import logging.handlers

class GMT8Formatter(logging.Formatter):
    """Custom formatter that converts timestamps to GMT+8"""
    def formatTime(self, record, datefmt=None):
        dt = datetime.fromtimestamp(record.created, GMT8)
        if datefmt:
            return dt.strftime(datefmt)
        return dt.strftime('%Y-%m-%d %H:%M:%S')

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/sprop/mqtt-listener.log'),
        logging.StreamHandler()
    ]
)

# Apply GMT+8 formatter to all handlers
gmt8_formatter = GMT8Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
for handler in logging.root.handlers:
    handler.setFormatter(gmt8_formatter)

logger = logging.getLogger(__name__)

class SPropMQTTListener:
    def __init__(self):
        self.db_conn = None
        self.mqtt_client = None
        self.last_fan_state = None
        self.last_lid_state = None
        self.last_valve_state = None
        
    def connect_database(self):
        """Connect to PostgreSQL database with SSL/TLS"""
        try:
            self.db_conn = psycopg2.connect(
                host=config.DB_HOST,
                port=config.DB_PORT,
                database=config.DB_NAME,
                user=config.DB_USER,
                password=config.DB_PASSWORD,
                sslmode=config.DB_SSL_MODE
            )
            logger.info(f"Connected to PostgreSQL database with SSL mode: {config.DB_SSL_MODE}")
            return True
        except Exception as e:
            logger.error(f"Database connection error: {e}")
            return False
    
    def parse_json_message(self, message: str) -> Optional[Dict]:
        """
        Parse JSON message from ESP32
        Expected format: {"temperature": float, "humidity": float, "timestamp": "ISO8601", 
                          "lid_state": "OPEN|CLOSED", "fan_state": "ON|OFF", "valve_state": "OPEN|CLOSED"}
        Maps ESP32 field names to backend field names
        """
        try:
            data = json.loads(message)
            
            # Validate required fields
            if 'temperature' not in data or 'humidity' not in data:
                logger.warning(f"Missing required fields (temperature/humidity) in message: {message}")
                return None
            
            # Parse and normalize timestamp
            if 'timestamp' in data and data['timestamp']:
                try:
                    # Handle ISO 8601 format with 'Z' suffix (UTC)
                    timestamp_str = data['timestamp'].replace('Z', '+00:00')
                    # Parse as UTC and convert to GMT+8
                    utc_timestamp = datetime.fromisoformat(timestamp_str)
                    data['timestamp'] = utc_timestamp.astimezone(GMT8)
                except (ValueError, AttributeError) as e:
                    logger.warning(f"Invalid timestamp format, using current time: {e}")
                    data['timestamp'] = datetime.now(GMT8)
            else:
                # Fallback to current time if timestamp not provided
                data['timestamp'] = datetime.now(GMT8)
            
            # Map ESP32 field names to backend field names
            # ESP32 sends: "fan_state", "lid_state", "valve_state"
            # Backend expects: "fan_state", "lid_state", "valve_state"
            if 'fan_state' in data:
                data['fan_state'] = data['fan_state'].upper()
            if 'lid_state' in data:
                data['lid_state'] = data['lid_state'].upper()
            if 'valve_state' in data:
                data['valve_state'] = data['valve_state'].upper()
            
            return data
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            return None
        except Exception as e:
            logger.error(f"Error parsing message: {e}")
            return None
    
    def save_sensor_data(self, data: Dict):
        """Save sensor data to PostgreSQL"""
        try:
            cursor = self.db_conn.cursor()
            
            # Ensure timestamp is in GMT+8 timezone before saving
            timestamp = data['timestamp']
            if timestamp.tzinfo is None:
                # If no timezone info, assume GMT+8
                timestamp = timestamp.replace(tzinfo=GMT8)
            elif timestamp.tzinfo != GMT8:
                # Convert to GMT+8 if in different timezone
                timestamp = timestamp.astimezone(GMT8)
            
            # Validate timestamp: reject future dates more than 1 day ahead or past dates older than 1 year
            now_gmt8 = datetime.now(GMT8)
            if timestamp > now_gmt8 + timedelta(days=1):
                logger.error(f"Rejecting invalid future timestamp: {timestamp} (current: {now_gmt8})")
                return  # Don't save corrupted data
            if timestamp < now_gmt8 - timedelta(days=365):
                logger.warning(f"Timestamp is more than 1 year old: {timestamp} (current: {now_gmt8}), using current time")
                timestamp = now_gmt8  # Use current time instead
            
            cursor.execute(
                """
                INSERT INTO sensor_data (timestamp, temperature, humidity)
                VALUES (%s, %s, %s)
                """,
                (timestamp, data['temperature'], data['humidity'])
            )
            self.db_conn.commit()
            cursor.close()
            
            # Log sensor data with device states if available
            log_msg = f"Saved sensor data: Temp={data['temperature']:.2f}°C, Hum={data['humidity']:.2f}%"
            device_info = []
            if 'fan_state' in data:
                device_info.append(f"Fan={data['fan_state']}")
            if 'lid_state' in data:
                device_info.append(f"Lid={data['lid_state']}")
            if 'valve_state' in data:
                device_info.append(f"Valve={data['valve_state']}")
            if device_info:
                log_msg += f" | {', '.join(device_info)}"
            logger.info(log_msg)
        except Exception as e:
            logger.error(f"Error saving sensor data: {e}")
            self.db_conn.rollback()
    
    def handle_device_status(self, topic: str, message: str):
        """Handle device status updates from hardware"""
        try:
            status_data = json.loads(message)
            
            # Extract device type from topic (e.g., "sprop/status/fan" -> "fan")
            device_type = topic.split('/')[-1]
            status = status_data.get('status', '').upper()
            timestamp_str = status_data.get('timestamp')
            
            # Normalize status values
            # Map common status values to standard format
            status_map = {
                'RUNNING': 'ON',
                'START': 'ON',
                'STOPPED': 'OFF',
                'STOP': 'OFF',
                'OPENED': 'OPEN',
                'CLOSED': 'CLOSE',
            }
            normalized_status = status_map.get(status, status)
            
            # For lid, normalize CLOSE to CLOSED for consistency
            if device_type == 'lid' and normalized_status == 'CLOSE':
                normalized_status = 'CLOSED'
            
            # Parse timestamp
            if timestamp_str:
                try:
                    timestamp_str = timestamp_str.replace('Z', '+00:00')
                    timestamp = datetime.fromisoformat(timestamp_str).astimezone(GMT8)
                except (ValueError, AttributeError):
                    timestamp = datetime.now(GMT8)
            else:
                timestamp = datetime.now(GMT8)
            
            # Update internal state tracking
            if device_type == 'fan':
                self.last_fan_state = normalized_status
            elif device_type == 'lid':
                self.last_lid_state = normalized_status
            elif device_type == 'valve':
                self.last_valve_state = normalized_status
            
            # Log the status update
            logger.info(f"[DEVICE STATUS] {device_type}: {normalized_status} (from: {status})")
            
        except json.JSONDecodeError as e:
            logger.error(f"[DEVICE STATUS] JSON parse error: {e}, message: {message}")
        except Exception as e:
            logger.error(f"[DEVICE STATUS] Error handling status: {e}")
    
    def is_optimization_enabled(self) -> bool:
        """Check if optimization (automated control) is enabled"""
        try:
            cursor = self.db_conn.cursor()
            cursor.execute(
                """
                SELECT setting_value
                FROM system_settings
                WHERE setting_key = 'optimization_enabled'
                """
            )
            row = cursor.fetchone()
            cursor.close()
            
            if not row:
                # Default to enabled if not found
                return True
            
            return row[0].lower() == 'true'
        except Exception as e:
            logger.error(f"Error checking optimization status: {e}")
            # Default to enabled on error
            return True
    
    def check_thresholds_and_control(self, data: Dict):
        """
        Check sensor readings against optimal ranges and publish control commands.
        
        Optimal ranges for sprop system:
        - Temperature: 55-65°C (131-149°F)
        - Humidity: 50-60% water (by weight)
        """
        # Check if optimization is enabled
        if not self.is_optimization_enabled():
            logger.debug("[CONTROL] Optimization disabled - skipping automated control")
            return
        
        temp = data['temperature']
        humidity = data['humidity']
        
        # Get combined control recommendations using optimal ranges
        control = get_combined_control_recommendation(temp, humidity)
        
        # Get current device states from sensor data or last known state
        # Try multiple field names (ESP32 might send different field names)
        current_fan_state = data.get('fan_state') or data.get('relay') or data.get('fan')
        if current_fan_state:
            current_fan_state = str(current_fan_state).strip().upper()
        else:
            current_fan_state = self.last_fan_state or 'UNKNOWN'
        
        current_lid_state = data.get('lid_state') or data.get('lid')
        if current_lid_state:
            current_lid_state = str(current_lid_state).strip().upper()
        else:
            current_lid_state = self.last_lid_state or 'UNKNOWN'
        
        # Log control decision
        logger.info(f"[CONTROL] Temp: {temp:.1f}°C, Humidity: {humidity:.1f}%")
        logger.info(f"[CONTROL] Fan: {control['fan_action']} (current: {current_fan_state}) | Lid: {control['lid_action']} (current: {current_lid_state})")
        logger.info(f"[CONTROL] Reason - Temp: {control['temp_status']}, Humidity: {control['humidity_status']}")
        
        # Fan control - send command if action is required and state differs
        if control['fan_action'] == 'ON':
            if current_fan_state != 'ON':
                self.publish_command(config.MQTT_CMD_FAN_TOPIC, {"action": "ON"})
                self.last_fan_state = 'ON'
                logger.warning(f"[CONTROL] ✓ Fan ON - {control['humidity_message'] if control['humidity_status'] == 'too_high' else control['temp_message']}")
            else:
                logger.debug(f"[CONTROL] Fan already ON, skipping")
        elif control['fan_action'] == 'OFF':
            if current_fan_state == 'ON':
                self.publish_command(config.MQTT_CMD_FAN_TOPIC, {"action": "OFF"})
                self.last_fan_state = 'OFF'
                logger.info(f"[CONTROL] ✓ Fan OFF - {control['message']}")
            else:
                logger.debug(f"[CONTROL] Fan already OFF, skipping")
        
        # Lid control - send command if action is required and state differs
        if control['lid_action'] == 'OPEN':
            if current_lid_state != 'OPEN':
                self.publish_command(config.MQTT_CMD_LID_TOPIC, {"action": "OPEN"})
                self.last_lid_state = 'OPEN'
                logger.warning(f"[CONTROL] ✓ Lid OPEN - {control['message']}")
            else:
                logger.debug(f"[CONTROL] Lid already OPEN, skipping")
        elif control['lid_action'] == 'CLOSED':
            if current_lid_state == 'OPEN':
                # Hardware expects "CLOSE" not "CLOSED"
                self.publish_command(config.MQTT_CMD_LID_TOPIC, {"action": "CLOSE"})
                self.last_lid_state = 'CLOSED'
                logger.info(f"[CONTROL] ✓ Lid CLOSED - {control['message']}")
            else:
                logger.debug(f"[CONTROL] Lid already CLOSED, skipping")
    
    def publish_command(self, topic: str, payload: Dict):
        """Publish command to MQTT topic"""
        if not self.mqtt_client or not self.mqtt_client.is_connected():
            logger.error(f"[CONTROL] Cannot publish - MQTT client not connected")
            return
        
        try:
            message = json.dumps(payload)
            result = self.mqtt_client.publish(topic, message)
            if result.rc == 0:
                logger.info(f"[CONTROL] ✓ Published to {topic}: {message}")
            else:
                logger.error(f"[CONTROL] Failed to publish to {topic}: rc={result.rc}")
        except Exception as e:
            logger.error(f"[CONTROL] Error publishing to {topic}: {e}")
    
    def on_connect(self, client, userdata, flags, rc):
        """Callback when MQTT client connects"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            # Subscribe to sensor data topic
            client.subscribe(config.MQTT_SENSOR_TOPIC)
            logger.info(f"Subscribed to topic: {config.MQTT_SENSOR_TOPIC}")
            # Subscribe to device status topics
            client.subscribe(config.MQTT_STATUS_FAN_TOPIC)
            client.subscribe(config.MQTT_STATUS_LID_TOPIC)
            client.subscribe(config.MQTT_STATUS_VALVE_TOPIC)
            logger.info(f"Subscribed to device status topics: {config.MQTT_STATUS_FAN_TOPIC}, {config.MQTT_STATUS_LID_TOPIC}, {config.MQTT_STATUS_VALVE_TOPIC}")
        else:
            logger.error(f"Failed to connect to MQTT broker, return code: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Callback when MQTT message is received"""
        try:
            topic = msg.topic
            message = msg.payload.decode('utf-8')
            
            # Route device status updates to handle_device_status
            if topic.startswith('sprop/status/'):
                self.handle_device_status(topic, message)
                return
            
            # For sensor data, parse and process
            if topic == config.MQTT_SENSOR_TOPIC:
                data = self.parse_json_message(message)
                
                if data:
                    # Save to database (includes logging with device states)
                    self.save_sensor_data(data)
                    
                    # Check thresholds and control devices
                    self.check_thresholds_and_control(data)
                else:
                    logger.warning(f"Could not parse sensor data message: {message}")
            else:
                logger.debug(f"Received message on unknown topic {topic}: {message}")
                
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    def on_disconnect(self, client, userdata, rc):
        """Callback when MQTT client disconnects"""
        logger.warning(f"Disconnected from MQTT broker (rc: {rc})")
    
    def start(self):
        """Start the MQTT listener service"""
        # Connect to database
        if not self.connect_database():
            logger.error("Failed to connect to database. Exiting.")
            return
        
        # Create MQTT client
        self.mqtt_client = mqtt.Client(client_id="sprop_mqtt_listener")
        
        # Set callbacks
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_message = self.on_message
        self.mqtt_client.on_disconnect = self.on_disconnect
        
        # Set credentials if provided
        if config.MQTT_USERNAME and config.MQTT_PASSWORD:
            self.mqtt_client.username_pw_set(config.MQTT_USERNAME, config.MQTT_PASSWORD)
        
        # Configure TLS/SSL if enabled
        if config.MQTT_USE_TLS:
            import ssl
            self.mqtt_client.tls_set(
                ca_certs=config.MQTT_CA_CERTS,
                certfile=config.MQTT_CERTFILE,
                keyfile=config.MQTT_KEYFILE,
                cert_reqs=ssl.CERT_NONE,  # Allow self-signed certificates for development
                tls_version=ssl.PROTOCOL_TLS,
                ciphers=None
            )
            logger.warning("MQTT TLS/SSL enabled with certificate verification disabled (self-signed cert)")
            logger.info(f"MQTT TLS/SSL enabled (port {config.MQTT_BROKER_PORT})")
        else:
            logger.warning("MQTT TLS/SSL is disabled - using insecure connection")
        
        # Connect to MQTT broker
        try:
            self.mqtt_client.connect(config.MQTT_BROKER_HOST, config.MQTT_BROKER_PORT, 60)
            logger.info(f"Connecting to MQTT broker at {config.MQTT_BROKER_HOST}:{config.MQTT_BROKER_PORT} (TLS: {config.MQTT_USE_TLS})")
            
            # Start loop (blocks)
            self.mqtt_client.loop_forever()
            
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            self.mqtt_client.disconnect()
            if self.db_conn:
                self.db_conn.close()
        except Exception as e:
            logger.error(f"Error in MQTT loop: {e}")
            if self.db_conn:
                self.db_conn.close()

def main():
    """Main entry point"""
    # Ensure log directory exists
    import os
    os.makedirs('/var/log/sprop', exist_ok=True)
    
    listener = SPropMQTTListener()
    listener.start()

if __name__ == "__main__":
    main()
