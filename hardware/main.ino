#include <ESP32Servo.h>
#include <DHT.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <time.h>
#include <ArduinoJson.h>
#define DHTTYPE DHT11   // DHT 11


// --- LED PINS ---
const int LED_GREEN = 18;             // Green LED pin
const int LED_RED = 19;               // Red LED for system fault


// --- SENSOR PINS ---
const int DHT_PIN = 21;               // DHT11 temperature/humidity sensor pin

// --- ACTUATOR PINS ---
const int LID_SERVO_PIN = 27;         // Servo pin for lid
const int RELAY_PIN = 25;             // Relay/DC motor pin
const int BUZZER_PIN = 23;            // Buzzer pin
const int WATER_VALVE_SERVO_PIN = 26; // Servo pin for water valve



// --- WiFi & MQTT Configuration ---
const char* WIFI_SSID = "YOUR WIFI SSID";             // Your WiFi SSID
const char* WIFI_PASSWORD = "YOUR WIFI PASSWORD";       // Your WiFi password
const char* MQTT_SERVER = "YOUR MQTT SERVER IP ADDRESS";     // Your VM instance public IP address
const char* MQTT_TOPIC = "sprop/sensor/data";     // MQTT topic for publishing sensor data
const int MQTT_PORT = 1883;                  // Non-TLS communication port
char mqttBuffer[512] = "";                   // Buffer for MQTT messages (increased for JSON)

// --- MQTT Command Topics (Subscribe) ---
const char* MQTT_CMD_FAN = "sprop/cmd/fan";
const char* MQTT_CMD_LID = "sprop/cmd/lid";
const char* MQTT_CMD_VALVE = "sprop/cmd/valve";

// --- MQTT Status Topics (Publish) ---
const char* MQTT_STATUS_FAN = "sprop/status/fan";
const char* MQTT_STATUS_LID = "sprop/status/lid";
const char* MQTT_STATUS_VALVE = "sprop/status/valve";

// --- NTP Configuration ---
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 8 * 3600;  // GMT+8 (Malaysia/Singapore)
bool timeInitialized = false;        // Track if time has been synchronized

// --- OBJECTS ---
DHT dht(DHT_PIN, DHTTYPE);
Servo lidServo;
Servo waterValveServo;
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// --- STATE VARIABLES ---
bool isLidOpen = false;     // Tracks if the lid is currently open
bool isRelayOn = false;     // Tracks if the relay/motor is currently ON
bool isWaterValveOn = false; // Tracks if the water valve is currently open
unsigned long lastDHTRead = 0;  // Last time DHT was read
const unsigned long DHT_INTERVAL = 5000; // 5 seconds in milliseconds
const int VALVE_OPEN_POSITION = 30; // Water valve open position (30 degrees)
const int VALVE_CLOSED_POSITION = 0; // Water valve closed position (0 degrees)

// --- FAULT DETECTION VARIABLES ---
bool systemFault = false;   // System fault status
unsigned long lastFaultBeep = 0;  // Last time fault beep started
unsigned long lastFaultBlink = 0; // Last time fault LED blinked
bool faultBeepState = false; // Current fault beep state (ON/OFF)
bool faultLEDState = false;  // Current fault LED state (ON/OFF)
const unsigned long FAULT_BEEP_ON = 1000;  // Fault beep ON duration (1 sec)
const unsigned long FAULT_BEEP_OFF = 3000; // Fault beep OFF duration (3 sec)
const unsigned long FAULT_BLINK_INTERVAL = 300; // Fault LED blink interval (0.3 sec)
const unsigned long ACTION_BEEP_DURATION = 100; // Action beep duration (0.1 sec)
unsigned long actionBeepStart = 0; // When action beep started
bool actionBeepActive = false;     // Is action beep currently active
unsigned long lastMQTTPublish = 0; // Last time MQTT data was published
const unsigned long MQTT_PUBLISH_INTERVAL = 5000; // Publish to MQTT every 5 seconds
bool wifiInitialized = false;      // Track if WiFi has been initialized
unsigned long lastWiFiAttempt = 0; // Last time WiFi connection was attempted
const unsigned long WIFI_RETRY_INTERVAL = 30000; // Retry WiFi every 30 seconds

void setup() {
  Serial.begin(115200);
  delay(2000); // Give serial monitor more time to connect
  
  Serial.println("\n\n=== Starting SProp Prototype ===");
  Serial.flush();
  
  // Initialize GPIO2 (LED_GREEN) as LOW first to ensure proper boot
  // GPIO2 must be LOW during boot
  pinMode(LED_GREEN, OUTPUT);
  digitalWrite(LED_GREEN, LOW);
  delay(100);
  
  // 1. Setup DHT Sensor
  Serial.println("Initializing DHT sensor...");
  Serial.print("DHT11 connected to pin: ");
  Serial.println(DHT_PIN);
  
  // DHT11 needs pull-up resistor - ESP32 internal pull-up may not be strong enough
  // Try enabling internal pull-up anyway
  pinMode(DHT_PIN, INPUT_PULLUP);
  delay(100);
  
  dht.begin();
  delay(2000); // DHT11 needs time to stabilize after power-on
  
  // Test read to verify sensor is working
  float testTemp = dht.readTemperature();
  float testHum = dht.readHumidity();
  if (isnan(testTemp) || isnan(testHum)) {
    Serial.println("WARNING: DHT11 initial read failed - check wiring!");
    Serial.println("DHT11 requires:");
    Serial.println("  - VCC to 3.3V or 5V");
    Serial.println("  - GND to GND");
    Serial.println("  - DATA to pin 21");
    Serial.println("  - 4.7k-10k pull-up resistor between DATA and VCC (if not using internal pull-up)");
  } else {
    Serial.print("DHT11 test read successful: ");
    Serial.print(testTemp);
    Serial.print("°C, ");
    Serial.print(testHum);
    Serial.println("%");
  }
  delay(100);
  
  // 2. Setup Servos
  Serial.println("Initializing servos...");
  lidServo.setPeriodHertz(50); 
  lidServo.attach(LID_SERVO_PIN, 500, 2400);
  lidServo.write(0); // Ensure lid starts CLOSED
  delay(100);
  
  waterValveServo.setPeriodHertz(50);
  waterValveServo.attach(WATER_VALVE_SERVO_PIN, 500, 2400);
  waterValveServo.write(VALVE_CLOSED_POSITION); // Start water valve at closed position
  delay(100);

  // 3. Setup LEDs
  Serial.println("Initializing LEDs...");
  pinMode(LED_RED, OUTPUT);
  
  // 4. Setup Buzzer
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW); // Ensure buzzer starts OFF
  digitalWrite(LED_RED, LOW);    // Ensure red LED starts OFF

  // 5. Setup Relay (DC Motor)
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW); // Ensure relay starts OFF

  // 6. Setup MQTT Server (WiFi will be connected in main loop)
  Serial.println("All hardware initialized successfully!");
  Serial.println("WiFi connection will be attempted in main loop...");
  Serial.flush();
  
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);  // Set MQTT message callback
  
  Serial.println("\n=== Setup Complete! ===");
  Serial.println("System ready. Starting main loop...");
  Serial.println("WiFi will connect automatically when system is stable.\n");
  Serial.flush();
}

void loop() {
  unsigned long currentTime = millis();
  
  // --- PART 1: SYSTEM HEALTH (Green LED) - Read every 5 seconds ---
  if (currentTime - lastDHTRead >= DHT_INTERVAL) {
    lastDHTRead = currentTime; // Update last read time
    
    // DHT11 needs delay between reads (minimum 2 seconds)
    delay(100); // Small delay before reading
    
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    
    // Check if sensor is reading correctly
    if (isnan(t) || isnan(h)) {
      Serial.println("Error: DHT11 not responding!");
      Serial.println("Troubleshooting DHT11:");
      Serial.println("  1. Check wiring: VCC->3.3V, GND->GND, DATA->Pin 21");
      Serial.println("  2. Add 4.7k-10k pull-up resistor between DATA and VCC");
      Serial.println("  3. Ensure sensor has stable power supply");
      Serial.println("  4. Try disconnecting and reconnecting sensor");
      digitalWrite(LED_GREEN, LOW); // OFF = Error
      systemFault = true; // Set system fault
    } else {
      digitalWrite(LED_GREEN, HIGH); // ON = OK
      systemFault = false; // Clear system fault
      Serial.print("Temperature: ");
      Serial.print(t);
      Serial.print("°C, Humidity: ");
      Serial.print(h);
      Serial.println("%");
    }
  }

  // --- PART 1.5: FAULT INDICATION (Red LED blinking & Buzzer beeping) ---
  handleFaultIndication(currentTime);

  // --- PART 1.6: ACTION BEEP HANDLING ---
  handleActionBeep(currentTime);

  // --- PART 1.7: WiFi CONNECTION (Deferred from setup) ---
  // Attempt WiFi connection in main loop instead of setup for better stability
  if (!wifiInitialized && (currentTime - lastWiFiAttempt >= WIFI_RETRY_INTERVAL || lastWiFiAttempt == 0)) {
    lastWiFiAttempt = currentTime;
    Serial.println("Attempting WiFi connection (deferred from setup)...");
    Serial.flush();
    delay(1000); // Small delay before attempt
    
    if (setup_wifi()) {
      wifiInitialized = true;
      Serial.println("WiFi successfully initialized!");
      // Initialize NTP time sync after WiFi is connected
      if (!timeInitialized) {
        configTime(gmtOffset_sec, ntpServer);
        timeInitialized = true;
        Serial.println("NTP time sync initialized");
      }
    } else {
      Serial.println("WiFi initialization failed. Will retry in 30 seconds...");
      Serial.println("System continues to work offline.");
    }
    Serial.flush();
  }

  // --- PART 1.8: MQTT CONNECTION & PUBLISHING ---
  // Only attempt MQTT if WiFi is connected
  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      reconnectMQTT();
    }
    mqttClient.loop(); // Process MQTT messages

    // Publish sensor data to MQTT every 5 seconds
    if (currentTime - lastMQTTPublish >= MQTT_PUBLISH_INTERVAL) {
      lastMQTTPublish = currentTime;
      publishSensorData();
    }
  }

}

// --- HELPER FUNCTIONS ---

void openLid() {
  lidServo.write(90);                 // Open Servo
  startActionBeep(); // Beep on servo state change
}

void closeLid() {
  lidServo.write(0);                  // Close Servo
  startActionBeep(); // Beep on servo state change
}

void turnOnRelay() {
  digitalWrite(RELAY_PIN, HIGH);  // Turn ON relay/DC motor
  startActionBeep(); // Beep on relay state change
}

void turnOffRelay() {
  digitalWrite(RELAY_PIN, LOW);   // Turn OFF relay/DC motor
  startActionBeep(); // Beep on relay state change
}

void openWaterValve() {
  waterValveServo.write(VALVE_OPEN_POSITION); // Open valve to 30 degrees
  startActionBeep(); // Beep on valve state change
}

void closeWaterValve() {
  waterValveServo.write(VALVE_CLOSED_POSITION); // Close valve to 0 degrees
  startActionBeep(); // Beep on valve state change
}

void handleFaultIndication(unsigned long currentTime) {
  if (systemFault) {
    // Blink Red LED every 0.5 seconds
    if (currentTime - lastFaultBlink >= FAULT_BLINK_INTERVAL) {
      lastFaultBlink = currentTime;
      faultLEDState = !faultLEDState;
      digitalWrite(LED_RED, faultLEDState ? HIGH : LOW);
    }
    
    // Beep pattern: 1 sec ON, 3 sec OFF (only if action beep is not active)
    if (!actionBeepActive) {
      if (!faultBeepState) {
        // Currently in OFF state
        if (currentTime - lastFaultBeep >= FAULT_BEEP_OFF) {
          // Time to start beep
          faultBeepState = true;
          lastFaultBeep = currentTime;
          digitalWrite(BUZZER_PIN, HIGH);
        }
      } else {
        // Currently in ON state
        if (currentTime - lastFaultBeep >= FAULT_BEEP_ON) {
          // Time to stop beep
          faultBeepState = false;
          lastFaultBeep = currentTime;
          digitalWrite(BUZZER_PIN, LOW);
        }
      }
    }
  } else {
    // No fault - turn off red LED and buzzer (only if action beep is not active)
    digitalWrite(LED_RED, LOW);
    if (!actionBeepActive) {
      digitalWrite(BUZZER_PIN, LOW);
    }
    faultLEDState = false;
    faultBeepState = false;
  }
}

void handleActionBeep(unsigned long currentTime) {
  if (actionBeepActive) {
    if (currentTime - actionBeepStart >= ACTION_BEEP_DURATION) {
      // Stop the beep
      digitalWrite(BUZZER_PIN, LOW);
      actionBeepActive = false;
    }
  }
}

void startActionBeep() {
  actionBeepStart = millis();
  actionBeepActive = true;
  digitalWrite(BUZZER_PIN, HIGH);
}

// --- WiFi & MQTT FUNCTIONS ---

bool setup_wifi() {
  // Return true if already connected
  if (WiFi.status() == WL_CONNECTED) {
    return true;
  }
  
  delay(500); // Longer delay to stabilize power
  Serial.println();
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  Serial.flush();

  // Reduce WiFi transmit power to minimum to reduce current draw
  WiFi.setTxPower(WIFI_POWER_11dBm); // Minimum power (11dBm)
  delay(300);
  
  // Disable WiFi power save mode for stability
  WiFi.setSleep(false);
  delay(300);
  
  // Set WiFi mode before begin
  WiFi.mode(WIFI_STA);
  delay(500);
  
  Serial.println("Starting WiFi.begin()...");
  Serial.flush();
  delay(1000); // Extra delay before begin
  
  // Begin WiFi connection - requires stable power supply
  Serial.println("Calling WiFi.begin()...");
  Serial.flush();
  delay(1000);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  // CRITICAL: Delay after begin() to allow power supply to stabilize
  Serial.println("Waiting for power supply to stabilize...");
  delay(3000); // Allow time for power supply to handle WiFi connection current draw
  
  Serial.println("Waiting for WiFi connection...");
  Serial.flush();
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    Serial.flush();
    attempts++;
    
    // Check for WiFi errors
    wl_status_t status = WiFi.status();
    if (status == WL_CONNECT_FAILED || status == WL_NO_SSID_AVAIL) {
      Serial.println();
      Serial.print("WiFi connection failed - Status: ");
      Serial.println(status);
      Serial.println("Check SSID and password");
      break;
    }
  }
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.flush();
    return true; // Success
  } else {
    Serial.print("WiFi connection failed! Final status: ");
    Serial.println(WiFi.status());
    Serial.println("System will continue without WiFi/MQTT");
    Serial.flush();
    return false; // Failed
  }
}

void reconnectMQTT() {
  // Only try to reconnect if WiFi is connected
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("MQTT: WiFi not connected, skipping MQTT connection");
    Serial.print("MQTT: WiFi status: ");
    Serial.println(WiFi.status());
    return; // Skip MQTT if WiFi is not connected
  }
  
  Serial.println("=== MQTT Connection Diagnostics ===");
  Serial.print("MQTT: WiFi Status: Connected (");
  Serial.print(WiFi.localIP());
  Serial.println(")");
  Serial.print("MQTT: Server: ");
  Serial.print(MQTT_SERVER);
  Serial.print(":");
  Serial.println(MQTT_PORT);
  Serial.print("MQTT: MAC Address: ");
  Serial.println(WiFi.macAddress());
  
  // Test network connectivity to MQTT server
  Serial.println("MQTT: Testing server reachability...");
  WiFiClient testClient;
  if (testClient.connect(MQTT_SERVER, MQTT_PORT)) {
    Serial.println("MQTT: Server is reachable (TCP connection successful)");
    testClient.stop();
  } else {
    Serial.println("MQTT: WARNING - Server is NOT reachable!");
    Serial.println("MQTT: Possible issues:");
    Serial.println("  1. Server IP address is incorrect");
    Serial.println("  2. Server is not running");
    Serial.println("  3. Firewall is blocking port 1883");
    Serial.println("  4. Network routing issue");
    return; // Don't try MQTT if server is not reachable
  }
  
  Serial.println("MQTT: Server is reachable, attempting MQTT connection...");
  
  int mqttAttempts = 0;
  while (!mqttClient.connected() && mqttAttempts < 3) {
    Serial.print("MQTT: Attempting connection (attempt ");
    Serial.print(mqttAttempts + 1);
    Serial.println("/3)...");
    
    // Generate unique client ID with MAC address
    String clientId = "ESP32SPropClient-";
    clientId += String(WiFi.macAddress());
    clientId.replace(":", ""); // Remove colons from MAC address
    
    Serial.print("MQTT: Client ID: ");
    Serial.println(clientId);
    
    // Try connecting with keepalive of 60 seconds
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println("MQTT: Connected successfully!");
      Serial.print("MQTT: Client ID: ");
      Serial.println(clientId);
      
      // Subscribe to command topics
      if (mqttClient.subscribe(MQTT_CMD_FAN)) {
        Serial.print("MQTT: Subscribed to ");
        Serial.println(MQTT_CMD_FAN);
      }
      if (mqttClient.subscribe(MQTT_CMD_LID)) {
        Serial.print("MQTT: Subscribed to ");
        Serial.println(MQTT_CMD_LID);
      }
      if (mqttClient.subscribe(MQTT_CMD_VALVE)) {
        Serial.print("MQTT: Subscribed to ");
        Serial.println(MQTT_CMD_VALVE);
      }
      
      Serial.println("MQTT: Ready to publish messages and receive commands");
      break;
    } else {
      int state = mqttClient.state();
      Serial.print("MQTT: Connection failed, rc=");
      Serial.print(state);
      Serial.print(" (");
      
      // Decode error codes
      switch(state) {
        case -4: Serial.print("MQTT_CONNECTION_TIMEOUT"); break;
        case -3: Serial.print("MQTT_CONNECTION_LOST"); break;
        case -2: Serial.print("MQTT_CONNECT_FAILED - Server rejected connection"); break;
        case -1: Serial.print("MQTT_DISCONNECTED"); break;
        case 1: Serial.print("MQTT_CONNECT_BAD_PROTOCOL"); break;
        case 2: Serial.print("MQTT_CONNECT_BAD_CLIENT_ID"); break;
        case 3: Serial.print("MQTT_CONNECT_UNAVAILABLE"); break;
        case 4: Serial.print("MQTT_CONNECT_BAD_CREDENTIALS"); break;
        case 5: Serial.print("MQTT_CONNECT_UNAUTHORIZED"); break;
        default: Serial.print("Unknown error"); break;
      }
      Serial.println(")");
      
      if (state == -2) {
        Serial.println("MQTT: Troubleshooting:");
        Serial.println("  - Verify MQTT broker is running on the server");
        Serial.println("  - Check if broker requires authentication");
        Serial.println("  - Verify broker allows connections from your network");
        Serial.println("  - Check broker logs for connection attempts");
      }
      
      Serial.print("MQTT: Retrying in 5 seconds...");
      Serial.println();
      delay(5000);
      mqttAttempts++;
    }
  }
  
  if (!mqttClient.connected()) {
    Serial.println("MQTT: Connection failed after 3 attempts - will retry later");
    Serial.println("MQTT: System will continue to work offline");
  }
  Serial.println("====================================");
}

// Function to get ISO 8601 timestamp string
String getISOTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    // If time is not available, return empty string or fallback
    return "";
  }
  
  char timestamp[25];
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(timestamp);
}

// Function to publish status updates
void publishStatus(const char* topic, const char* status) {
  if (!mqttClient.connected()) {
    return; // Skip if not connected
  }

  String timestamp = getISOTimestamp();
  DynamicJsonDocument doc(256);
  doc["status"] = status;
  
  if (timestamp.length() > 0) {
    doc["timestamp"] = timestamp;
  }

  String payload;
  serializeJson(doc, payload);
  
  mqttClient.publish(topic, payload.c_str());
  Serial.print("MQTT Status Published: ");
  Serial.print(topic);
  Serial.print(" -> ");
  Serial.println(payload);
}

// MQTT callback function to handle incoming commands
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Convert payload to string
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }

  Serial.print("MQTT Command Received: ");
  Serial.print(topic);
  Serial.print(" -> ");
  Serial.println(message);

  // Parse JSON
  DynamicJsonDocument doc(256);
  DeserializationError error = deserializeJson(doc, message);

  if (error) {
    Serial.print("MQTT: JSON parsing failed: ");
    Serial.println(error.c_str());
    return;
  }

  if (!doc.containsKey("action")) {
    Serial.println("MQTT: Missing 'action' field in command");
    return;
  }

  String action = doc["action"];
  String topicStr = String(topic);

  // Handle fan commands (relay)
  if (topicStr == MQTT_CMD_FAN) {
    if (action == "ON") {
      isRelayOn = true;
      turnOnRelay();
      publishStatus(MQTT_STATUS_FAN, "ON");
      Serial.println("MQTT: Fan turned ON");
    } else if (action == "OFF") {
      isRelayOn = false;
      turnOffRelay();
      publishStatus(MQTT_STATUS_FAN, "OFF");
      Serial.println("MQTT: Fan turned OFF");
    } else {
      Serial.print("MQTT: Invalid fan action: ");
      Serial.println(action);
    }
  }
  // Handle lid commands
  else if (topicStr == MQTT_CMD_LID) {
    if (action == "OPEN") {
      isLidOpen = true;
      openLid();
      publishStatus(MQTT_STATUS_LID, "OPEN");
      Serial.println("MQTT: Lid opened");
    } else if (action == "CLOSE") {
      isLidOpen = false;
      closeLid();
      publishStatus(MQTT_STATUS_LID, "CLOSED");
      Serial.println("MQTT: Lid closed");
    } else {
      Serial.print("MQTT: Invalid lid action: ");
      Serial.println(action);
    }
  }
  // Handle water valve commands
  else if (topicStr == MQTT_CMD_VALVE) {
    if (action == "OPEN") {
      isWaterValveOn = true;
      openWaterValve();
      publishStatus(MQTT_STATUS_VALVE, "OPEN");
      Serial.println("MQTT: Water valve opened");
    } else if (action == "CLOSE") {
      isWaterValveOn = false;
      closeWaterValve();
      publishStatus(MQTT_STATUS_VALVE, "CLOSED");
      Serial.println("MQTT: Water valve closed");
    } else {
      Serial.print("MQTT: Invalid valve action: ");
      Serial.println(action);
    }
  }
  else {
    Serial.print("MQTT: Unknown command topic: ");
    Serial.println(topic);
  }
}

void publishSensorData() {
  if (!mqttClient.connected()) {
    return; // Skip if not connected
  }

  float t = dht.readTemperature();
  float h = dht.readHumidity();
  
  if (!isnan(t) && !isnan(h)) {
    // Get ISO 8601 timestamp
    String timestamp = getISOTimestamp();
    
    // Create JSON message with all sensor data and system status
    // Format: {"temperature": 30.80, "humidity": 70.00, "timestamp": "2024-01-03T16:58:08Z", "lid_state": "CLOSED", "fan_state": "OFF", "valve_state": "CLOSED"}
    if (timestamp.length() > 0) {
      snprintf(mqttBuffer, sizeof(mqttBuffer), 
               "{\"temperature\": %.2f, \"humidity\": %.2f, \"timestamp\": \"%s\", \"lid_state\": \"%s\", \"fan_state\": \"%s\", \"valve_state\": \"%s\"}",
               t, h, timestamp.c_str(),
               isLidOpen ? "OPEN" : "CLOSED",
               isRelayOn ? "ON" : "OFF",
               isWaterValveOn ? "OPEN" : "CLOSED");
    } else {
      // Fallback if timestamp is not available
      snprintf(mqttBuffer, sizeof(mqttBuffer), 
               "{\"temperature\": %.2f, \"humidity\": %.2f, \"lid_state\": \"%s\", \"fan_state\": \"%s\", \"valve_state\": \"%s\"}",
               t, h,
               isLidOpen ? "OPEN" : "CLOSED",
               isRelayOn ? "ON" : "OFF",
               isWaterValveOn ? "OPEN" : "CLOSED");
    }
    
    // Publish single combined JSON message
    mqttClient.publish(MQTT_TOPIC, mqttBuffer);
    Serial.print("MQTT Published (JSON): ");
    Serial.println(mqttBuffer);
  } else {
    // Publish fault status as JSON
    String timestamp = getISOTimestamp();
    if (timestamp.length() > 0) {
      snprintf(mqttBuffer, sizeof(mqttBuffer), 
               "{\"error\": \"DHT11 sensor error\", \"timestamp\": \"%s\", \"lid_state\": \"%s\", \"fan_state\": \"%s\", \"valve_state\": \"%s\"}",
               timestamp.c_str(),
               isLidOpen ? "OPEN" : "CLOSED",
               isRelayOn ? "ON" : "OFF",
               isWaterValveOn ? "OPEN" : "CLOSED");
    } else {
      snprintf(mqttBuffer, sizeof(mqttBuffer), 
               "{\"error\": \"DHT11 sensor error\", \"lid_state\": \"%s\", \"fan_state\": \"%s\", \"valve_state\": \"%s\"}",
               isLidOpen ? "OPEN" : "CLOSED",
               isRelayOn ? "ON" : "OFF",
               isWaterValveOn ? "OPEN" : "CLOSED");
    }
    mqttClient.publish(MQTT_TOPIC, mqttBuffer);
    Serial.print("MQTT Published (Error JSON): ");
    Serial.println(mqttBuffer);
  }
}
