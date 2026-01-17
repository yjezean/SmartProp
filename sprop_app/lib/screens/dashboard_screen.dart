import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sensor_provider.dart';
import '../providers/device_control_provider.dart';
import '../models/device_status.dart';
import '../widgets/temperature_gauge.dart';
import '../widgets/humidity_gauge.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SProp Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings - will be handled by main navigation
            },
          ),
        ],
      ),
      body: Consumer2<SensorProvider, DeviceControlProvider>(
        builder: (context, sensorProvider, deviceProvider, child) {
          final sensorData = sensorProvider.currentData;

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh sensor data if needed
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: sensorProvider.isConnected
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.error.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sensorProvider.isConnected
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sensorProvider.isConnected
                              ? 'Connected'
                              : 'Disconnected',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: sensorProvider.isConnected
                                        ? AppTheme.success
                                        : AppTheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        if (sensorProvider.lastUpdate != null) ...[
                          const SizedBox(width: 16),
                          Text(
                            'Last: ${DateFormat('HH:mm:ss').format(sensorProvider.lastUpdate!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Gauges
                  if (sensorData != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TemperatureGauge(
                            temperature: sensorData.temperature,
                          ),
                        ),
                        Expanded(
                          child: HumidityGauge(
                            humidity: sensorData.humidity,
                          ),
                        ),
                      ],
                    ),

                    // Low Humidity Alert
                    if (sensorData.humidity < 40) ...[
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warning,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Low Humidity Alert',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.warning,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Humidity is below 40%. Please add water to maintain optimal composting conditions.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textPrimary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.water_drop,
                              color: AppTheme.warning,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 200),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sensors_off,
                            size: 48,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Device Offline',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Waiting for sensor data...',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Device Status Overview - Show regardless of sensor data
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Device Status',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              if (sensorData == null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 20,
                                  color: AppTheme.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(Offline)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.warning,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStatusRow(
                            context,
                            'Fan',
                            _getDeviceStatusText(
                                deviceProvider.getDeviceState(DeviceType.fan)),
                            deviceProvider.isDeviceActive(DeviceType.fan),
                          ),
                          _buildStatusRow(
                            context,
                            'Lid',
                            _getDeviceStatusText(
                                deviceProvider.getDeviceState(DeviceType.lid)),
                            deviceProvider.isDeviceActive(DeviceType.lid),
                          ),
                          _buildStatusRow(
                            context,
                            'Water Valve',
                            _getDeviceStatusText(deviceProvider
                                .getDeviceState(DeviceType.valve)),
                            deviceProvider.isDeviceActive(DeviceType.valve),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    String device,
    String status,
    bool isActive,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            device,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.success : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color:
                          isActive ? AppTheme.success : AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDeviceStatusText(DeviceAction action) {
    switch (action) {
      case DeviceAction.on:
        return 'ON';
      case DeviceAction.off:
        return 'OFF';
      case DeviceAction.open:
        return 'OPEN';
      case DeviceAction.close:
        return 'CLOSED';
      case DeviceAction.start:
        return 'START';
      case DeviceAction.stop:
        return 'STOP';
      case DeviceAction.running:
        return 'RUNNING';
      case DeviceAction.stopped:
        return 'STOPPED';
    }
  }
}
