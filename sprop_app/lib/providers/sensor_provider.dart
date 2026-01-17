import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';

class SensorProvider with ChangeNotifier {
  final MqttService _mqttService;
  StreamSubscription<SensorData>? _sensorSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  SensorData? _currentData;
  bool _isConnected = false;
  DateTime? _lastUpdate;

  SensorProvider(this._mqttService) {
    _initialize();
  }

  SensorData? get currentData => _currentData;
  bool get isConnected => _isConnected;
  DateTime? get lastUpdate => _lastUpdate;

  void _initialize() {
    // Listen to sensor data stream
    _sensorSubscription = _mqttService.sensorDataStream.listen(
      (data) {
        _currentData = data;
        _lastUpdate = DateTime.now();
        notifyListeners();
      },
      onError: (error) {
        // Handle error
      },
    );

    // Listen to connection status
    _connectionSubscription = _mqttService.connectionStream.listen(
      (connected) {
        _isConnected = connected;
        notifyListeners();
      },
    );

    _isConnected = _mqttService.isConnected;
  }

  Future<void> connect() async {
    try {
      await _mqttService.connect();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

