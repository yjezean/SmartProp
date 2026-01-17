import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/sensor_data.dart';
import '../models/device_status.dart';
import 'config_service.dart';

class MqttService {
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>?
      _updatesSubscription;
  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();
  final StreamController<DeviceStatus> _deviceStatusController =
      StreamController<DeviceStatus>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;

  // Streams
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<DeviceStatus> get deviceStatusStream => _deviceStatusController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      final brokerUrl = await ConfigService.getMqttBrokerUrl();
      debugPrint('[MQTT] Attempting connection to: $brokerUrl');

      // Parse URL (format: ssl://host:port or tcp://host:port)
      final uri = Uri.parse(brokerUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : 8883;
      final useTls = uri.scheme == 'ssl' || uri.scheme == 'tls' || port == 8883;

      debugPrint('[MQTT] Parsed - Host: $host, Port: $port, TLS: $useTls');

      _client = MqttServerClient.withPort(
          host, 'sprop_flutter_${DateTime.now().millisecondsSinceEpoch}', port);
      _client!.logging(on: true); // Enable logging for debugging
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = true;

      // Configure TLS/SSL if using secure connection
      if (useTls) {
        _client!.secure = true;
        _client!.onBadCertificate = (dynamic certificate) {
          // For self-signed certificates, you may need to return true
          // In production, validate the certificate properly
          return true; // Accept certificate (change to false for production with proper CA)
        };
      }

      // Set MQTT credentials if configured
      final username = await ConfigService.getMqttUsername();
      final password = await ConfigService.getMqttPassword();

      debugPrint(
          '[MQTT] Username: ${username.isNotEmpty ? "${username.substring(0, username.length > 3 ? 3 : username.length)}..." : "EMPTY"}');
      debugPrint('[MQTT] Password: ${password.isNotEmpty ? "***" : "EMPTY"}');

      // Check if credentials are required but missing
      if (username.isEmpty || password.isEmpty) {
        debugPrint('[MQTT] ERROR: Username or password is empty!');
        throw Exception(
            'MQTT username and password are required. Please configure them in Settings.');
      }

      // Protocol already set above
      debugPrint('[MQTT] Protocol: MQTT 3.1.1');

      // Set up message handlers
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.pongCallback = _pong;

      // Add error callback for debugging
      _client!.onAutoReconnect = () {
        debugPrint('[MQTT] Auto-reconnecting...');
      };

      // Connect first - match hardware connection style exactly
      // Hardware uses: mqttClient.connect(clientId, username, password)
      // Hardware does NOT set will message, so we won't either
      final clientId = 'sprop_flutter_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[MQTT] Client ID: $clientId');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean(); // Clean session - matches hardware
      // NOTE: Hardware does NOT set will message, so we don't either

      // Add authentication (credentials already validated above)
      connMessage.authenticateAs(username, password);

      debugPrint('[MQTT] Connection message prepared:');
      debugPrint('[MQTT]   - Client ID: $clientId');
      debugPrint(
          '[MQTT]   - Username: ${username.isNotEmpty ? "SET" : "EMPTY"}');
      debugPrint(
          '[MQTT]   - Password: ${password.isNotEmpty ? "SET" : "EMPTY"}');
      debugPrint('[MQTT]   - Clean session: true');
      debugPrint('[MQTT]   - Will message: false (matches hardware)');

      _client!.connectionMessage = connMessage;

      debugPrint('[MQTT] Attempting to connect...');
      try {
        // Connect and wait for response
        await _client!.connect();
        debugPrint('[MQTT] Connect() call completed');

        // Wait for server response (CONNACK message)
        // The server should respond within a few seconds
        bool connected = false;
        for (int i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          final status = _client!.connectionStatus;

          if (status != null) {
            debugPrint(
                '[MQTT] Status check $i: State=${status.state}, ReturnCode=${status.returnCode}');

            if (status.state == MqttConnectionState.connected) {
              connected = true;
              debugPrint('[MQTT] ✓ Connection accepted by server!');
              break;
            }

            // Check if we got a rejection
            if (status.returnCode != null) {
              if (status.returnCode ==
                  MqttConnectReturnCode.connectionAccepted) {
                connected = true;
                debugPrint('[MQTT] ✓ Connection accepted!');
                break;
              } else {
                final errorMsg = _getReturnCodeMessage(status.returnCode!);
                debugPrint('[MQTT] ✗ Connection rejected: $errorMsg');
                throw Exception('MQTT connection rejected: $errorMsg');
              }
            }

            // Check if connection was closed
            if (status.state == MqttConnectionState.disconnected ||
                status.state == MqttConnectionState.disconnecting) {
              debugPrint('[MQTT] ✗ Connection closed by server');
              debugPrint(
                  '[MQTT] Disconnection origin: ${status.disconnectionOrigin}');
              throw Exception(
                  'MQTT connection closed by server. Check username and password.');
            }
          }
        }

        if (!connected) {
          final status = _client!.connectionStatus;
          if (status != null && status.returnCode != null) {
            final errorMsg = _getReturnCodeMessage(status.returnCode!);
            throw Exception('MQTT connection rejected: $errorMsg');
          } else {
            throw Exception(
                'MQTT connection timeout - server did not respond. This usually means wrong username/password.');
          }
        }
      } catch (e) {
        final status = _client!.connectionStatus;
        if (status != null) {
          debugPrint('[MQTT] Connection error - State: ${status.state}');
          debugPrint('[MQTT] Return code: ${status.returnCode}');
          debugPrint(
              '[MQTT] Disconnection origin: ${status.disconnectionOrigin}');
        }
        rethrow;
      }

      // Set up message callback AFTER connection
      _updatesSubscription = _client!.updates
          ?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        if (c == null || c.isEmpty) return;
        for (final message in c) {
          final recMess = message.payload as MqttPublishMessage?;
          if (recMess == null) continue;
          final topic = message.topic;
          final payload =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          _handleMessage(topic, payload);
        }
      });
    } catch (e, stackTrace) {
      _isConnected = false;
      _connectionController.add(false);
      debugPrint('[MQTT] Connection failed with error: $e');
      debugPrint('[MQTT] Stack trace: $stackTrace');
      if (_client != null) {
        debugPrint(
            '[MQTT] Client connection state: ${_client!.connectionStatus}');
      }
      throw Exception('MQTT connection error: $e');
    }
  }

  void _onConnected() {
    debugPrint('[MQTT] Connected successfully!');
    _isConnected = true;
    _connectionController.add(true);
    _subscribeToTopics();
  }

  void _onDisconnected() {
    debugPrint('[MQTT] Disconnected callback triggered');
    if (_client != null) {
      final status = _client!.connectionStatus;
      if (status != null) {
        debugPrint('[MQTT] Disconnection state: ${status.state}');
        debugPrint('[MQTT] Return code: ${status.returnCode}');
        debugPrint(
            '[MQTT] Disconnection origin: ${status.disconnectionOrigin}');
        if (status.returnCode != null) {
          final errorMsg = _getReturnCodeMessage(status.returnCode!);
          debugPrint('[MQTT] Connection rejected: $errorMsg');
        }
      }
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  String _getReturnCodeMessage(MqttConnectReturnCode? code) {
    if (code == null) return 'No return code';

    // Check the actual return code value
    if (code == MqttConnectReturnCode.connectionAccepted) {
      return 'Connection accepted';
    }

    // The library uses integer values, so we check the value
    final codeValue = code.toString();
    if (codeValue.contains('unacceptableProtocolVersion') ||
        codeValue.contains('1')) {
      return 'Unacceptable protocol version';
    } else if (codeValue.contains('identifierRejected') ||
        codeValue.contains('2')) {
      return 'Identifier rejected';
    } else if (codeValue.contains('serverUnavailable') ||
        codeValue.contains('3')) {
      return 'Server unavailable';
    } else if (codeValue.contains('badUserNameOrPassword') ||
        codeValue.contains('4')) {
      return 'Bad username or password - CHECK YOUR CREDENTIALS!';
    } else if (codeValue.contains('notAuthorized') || codeValue.contains('5')) {
      return 'Not authorized';
    } else {
      return 'Unknown error: $codeValue';
    }
  }

  void _onSubscribed(String topic) {
    // Subscription successful
  }

  void _pong() {
    // Pong received
  }

  void _subscribeToTopics() {
    debugPrint('[MQTT] Subscribing to topics...');
    _client!.subscribe('sprop/sensor/data', MqttQos.atLeastOnce);
    _client!.subscribe('sprop/status/fan', MqttQos.atLeastOnce);
    _client!.subscribe('sprop/status/lid', MqttQos.atLeastOnce);
    _client!.subscribe('sprop/status/valve', MqttQos.atLeastOnce);
    debugPrint('[MQTT] Subscription requests sent');
  }

  void _handleMessage(String topic, String payload) {
    try {
      if (topic == 'sprop/sensor/data') {
        final jsonData = json.decode(payload) as Map<String, dynamic>;
        final sensorData = SensorData.fromJson(jsonData);
        _sensorDataController.add(sensorData);
      } else if (topic.startsWith('sprop/status/')) {
        final deviceType = topic.split('/').last;
        final jsonData = json.decode(payload) as Map<String, dynamic>;

        // Create DeviceStatus from the message
        final statusString =
            jsonData['status'] as String? ?? jsonData['action'] as String?;
        if (statusString == null) {
          debugPrint(
              '[MQTT] Error: No status/action in payload for $deviceType');
          return;
        }

        final timestampString = jsonData['timestamp'] as String?;
        DateTime localTimestamp;
        if (timestampString != null) {
          try {
            final utcTimestamp = DateTime.parse(timestampString);
            localTimestamp = utcTimestamp.toLocal();
          } catch (e) {
            localTimestamp = DateTime.now();
          }
        } else {
          localTimestamp = DateTime.now();
        }

        final status = DeviceStatus(
          device: _parseDeviceType(deviceType),
          action: DeviceStatus.parseDeviceAction(statusString),
          timestamp: localTimestamp,
        );

        _deviceStatusController.add(status);
        debugPrint('[MQTT] Status: $deviceType -> ${status.action}');
      }
    } catch (e) {
      debugPrint('[MQTT] Error handling message on $topic: $e');
    }
  }

  DeviceType _parseDeviceType(String device) {
    switch (device.toLowerCase()) {
      case 'fan':
        return DeviceType.fan;
      case 'lid':
        return DeviceType.lid;
      case 'valve':
        return DeviceType.valve;
      default:
        return DeviceType.fan;
    }
  }

  // Publish command to device
  Future<void> publishCommand(String device, String action) async {
    if (!_isConnected || _client == null) {
      throw Exception('MQTT not connected');
    }

    try {
      final topic = 'sprop/cmd/$device';
      final payload = json.encode({'action': action.toUpperCase()});
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    } catch (e) {
      throw Exception('Error publishing command: $e');
    }
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    _updatesSubscription?.cancel();
    disconnect();
    _sensorDataController.close();
    _deviceStatusController.close();
    _connectionController.close();
  }
}
