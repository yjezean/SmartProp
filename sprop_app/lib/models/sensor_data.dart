class SensorData {
  final double temperature;
  final double humidity;
  final DateTime timestamp;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    // Parse timestamp and convert from UTC to local time (GMT+8)
    final utcTimestamp = DateTime.parse(json['timestamp']);
    final localTimestamp = utcTimestamp.toLocal();
    
    return SensorData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      timestamp: localTimestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

