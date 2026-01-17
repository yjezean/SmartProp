import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/device_status.dart';
import '../services/mqtt_service.dart';

enum DeviceCommandState {
  idle,
  sending,
  success,
  error,
}

class DeviceControlProvider with ChangeNotifier {
  final MqttService _mqttService;
  StreamSubscription<DeviceStatus>? _statusSubscription;

  final Map<DeviceType, DeviceAction> _deviceStates = {
    DeviceType.fan: DeviceAction.off,
    DeviceType.lid: DeviceAction.close,
    DeviceType.valve: DeviceAction.close,
  };

  final Map<DeviceType, DeviceCommandState> _commandStates = {
    DeviceType.fan: DeviceCommandState.idle,
    DeviceType.lid: DeviceCommandState.idle,
    DeviceType.valve: DeviceCommandState.idle,
  };

  DeviceControlProvider(this._mqttService) {
    _initialize();
  }

  void _initialize() {
    // Listen to device status updates
    _statusSubscription = _mqttService.deviceStatusStream.listen(
      (status) {
        final oldState = _deviceStates[status.device];
        _deviceStates[status.device] = status.action;
        if (oldState != status.action) {
          debugPrint(
              '[DEVICE] ${status.device}: $oldState -> ${status.action}');
        }
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[DEVICE] Error: $error');
      },
    );
  }

  DeviceAction getDeviceState(DeviceType device) {
    return _deviceStates[device] ?? DeviceAction.off;
  }

  DeviceCommandState getCommandState(DeviceType device) {
    return _commandStates[device] ?? DeviceCommandState.idle;
  }

  bool isDeviceActive(DeviceType device) {
    final action = getDeviceState(device);
    switch (device) {
      case DeviceType.fan:
        return action == DeviceAction.on;
      case DeviceType.lid:
        return action == DeviceAction.open;
      case DeviceType.valve:
        return action == DeviceAction.open;
    }
  }

  Future<void> sendCommand(DeviceType device, String action) async {
    if (!_mqttService.isConnected) {
      _commandStates[device] = DeviceCommandState.error;
      notifyListeners();
      return;
    }

    _commandStates[device] = DeviceCommandState.sending;
    notifyListeners();

    try {
      final deviceName = device.name; // 'fan', 'lid', 'valve'
      await _mqttService.publishCommand(deviceName, action);

      // Don't wait - status updates come from hardware via MQTT stream
      _commandStates[device] = DeviceCommandState.success;
      notifyListeners();

      // Reset to idle after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        _commandStates[device] = DeviceCommandState.idle;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[DEVICE] Command error: $device -> $action: $e');
      _commandStates[device] = DeviceCommandState.error;
      notifyListeners();

      // Reset to idle after error
      Future.delayed(const Duration(seconds: 2), () {
        _commandStates[device] = DeviceCommandState.idle;
        notifyListeners();
      });
    }
  }

  Future<void> toggleFan() async {
    final isOn = _deviceStates[DeviceType.fan] == DeviceAction.on;
    await sendCommand(DeviceType.fan, isOn ? 'OFF' : 'ON');
  }

  Future<void> toggleLid() async {
    final currentAction = _deviceStates[DeviceType.lid] ?? DeviceAction.close;
    final isOpen = currentAction == DeviceAction.open;
    await sendCommand(DeviceType.lid, isOpen ? 'CLOSE' : 'OPEN');
  }

  Future<void> toggleValve() async {
    final currentAction = _deviceStates[DeviceType.valve] ?? DeviceAction.close;
    final isOpen = currentAction == DeviceAction.open;
    await sendCommand(DeviceType.valve, isOpen ? 'CLOSE' : 'OPEN');
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}
