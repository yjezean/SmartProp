enum DeviceType {
  fan,
  lid,
  valve,
}

enum DeviceAction {
  on,
  off,
  open,
  close,
  start,
  stop,
  running,
  stopped,
}

class DeviceStatus {
  final DeviceType device;
  final DeviceAction action;
  final DateTime timestamp;

  DeviceStatus({
    required this.device,
    required this.action,
    required this.timestamp,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    // Parse timestamp and convert from UTC to local time (GMT+8)
    final utcTimestamp = DateTime.parse(json['timestamp']);
    final localTimestamp = utcTimestamp.toLocal();

    return DeviceStatus(
      device: _parseDeviceType(json['device'] as String),
      action: parseDeviceAction(json['status'] as String),
      timestamp: localTimestamp,
    );
  }

  static DeviceType _parseDeviceType(String device) {
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

  static DeviceAction parseDeviceAction(String status) {
    switch (status.toUpperCase()) {
      case 'ON':
        return DeviceAction.on;
      case 'OFF':
        return DeviceAction.off;
      case 'OPEN':
        return DeviceAction.open;
      case 'CLOSED':
      case 'CLOSE':
        return DeviceAction.close;
      case 'START':
        return DeviceAction.start;
      case 'STOP':
      case 'STOPPED':
        return DeviceAction.stopped;
      case 'RUNNING':
        return DeviceAction.running;
      default:
        return DeviceAction.off;
    }
  }

  String get statusText {
    switch (action) {
      case DeviceAction.on:
      case DeviceAction.running:
        return 'ON';
      case DeviceAction.off:
      case DeviceAction.stopped:
        return 'OFF';
      case DeviceAction.open:
        return 'OPEN';
      case DeviceAction.close:
        return 'CLOSED';
      case DeviceAction.start:
        return 'START';
      case DeviceAction.stop:
        return 'STOP';
    }
  }

  bool get isActive {
    return action == DeviceAction.on ||
        action == DeviceAction.open ||
        action == DeviceAction.running ||
        action == DeviceAction.start;
  }
}
