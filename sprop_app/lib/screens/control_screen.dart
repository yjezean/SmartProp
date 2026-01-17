import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_control_provider.dart';
import '../providers/sensor_provider.dart';
import '../providers/optimization_provider.dart';
import '../models/device_status.dart';
import '../widgets/control_button.dart';
import '../theme/app_theme.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
      ),
      body: Consumer3<DeviceControlProvider, SensorProvider,
          OptimizationProvider>(
        builder: (context, deviceProvider, sensorProvider, optimizationProvider,
            child) {
          // Check if device is offline
          final isOffline =
              sensorProvider.currentData == null || !sensorProvider.isConnected;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Offline Indicator Banner
                if (isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.warning.withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warning,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device Offline',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Controls are disabled. Please ensure the device is powered on and connected.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Optimization Control
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 24,
                              color: optimizationProvider.isEnabled
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Automated Optimization',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    optimizationProvider.isEnabled
                                        ? 'Automated temperature and humidity control is active'
                                        : 'Automated control is disabled',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: optimizationProvider.isEnabled
                                    ? AppTheme.success
                                    : AppTheme.textSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                optimizationProvider.isEnabled ? 'ON' : 'OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: optimizationProvider.isLoading
                                ? null
                                : () => _showOptimizationDialog(
                                      context,
                                      optimizationProvider,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: optimizationProvider.isEnabled
                                  ? AppTheme.error
                                  : AppTheme.primaryGreen,
                              disabledBackgroundColor: AppTheme.divider,
                            ),
                            child: optimizationProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    optimizationProvider.isEnabled
                                        ? 'Turn OFF Optimization'
                                        : 'Turn ON Optimization',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Fan Control
                ControlButton(
                  label: 'Fan Control',
                  icon: Icons.ac_unit,
                  isActive: deviceProvider.isDeviceActive(DeviceType.fan),
                  isLoading: deviceProvider.getCommandState(DeviceType.fan) ==
                      DeviceCommandState.sending,
                  isEnabled: !isOffline,
                  onPressed: () => deviceProvider.toggleFan(),
                ),

                // Lid Control
                ControlButton(
                  label: 'Lid Control',
                  icon: Icons.unfold_more,
                  isActive: deviceProvider.isDeviceActive(DeviceType.lid),
                  isLoading: deviceProvider.getCommandState(DeviceType.lid) ==
                      DeviceCommandState.sending,
                  isEnabled: !isOffline,
                  onPressed: () => deviceProvider.toggleLid(),
                ),

                // Water Valve Control
                ControlButton(
                  label: 'Water Valve Control',
                  icon: Icons.water_drop,
                  isActive: deviceProvider.isDeviceActive(DeviceType.valve),
                  isLoading: deviceProvider.getCommandState(DeviceType.valve) ==
                      DeviceCommandState.sending,
                  isEnabled: !isOffline,
                  onPressed: () => deviceProvider.toggleValve(),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOptimizationDialog(
    BuildContext context,
    OptimizationProvider optimizationProvider,
  ) {
    final bool isCurrentlyEnabled = optimizationProvider.isEnabled;
    final bool willDisable = isCurrentlyEnabled;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                willDisable ? Icons.warning_amber_rounded : Icons.check_circle,
                color: willDisable ? AppTheme.warning : AppTheme.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  willDisable
                      ? 'Disable Optimization?'
                      : 'Enable Optimization?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (willDisable) ...[
                Text(
                  'Turning off optimization is not recommended.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'When optimization is disabled:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                _buildWarningItem(
                  context,
                  'Automated temperature control will stop',
                ),
                _buildWarningItem(
                  context,
                  'Automated humidity control will stop',
                ),
                _buildWarningItem(
                  context,
                  'You will need to manually control all devices',
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to disable automated optimization?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ] else ...[
                Text(
                  'Enabling optimization will activate automated control of temperature and humidity.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'The system will automatically:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                _buildInfoItem(
                  context,
                  'Control fan based on temperature and humidity',
                ),
                _buildInfoItem(
                  context,
                  'Control lid based on optimal ranges',
                ),
                _buildInfoItem(
                  context,
                  'Maintain optimal composting conditions',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await optimizationProvider.toggle();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          willDisable
                              ? 'Optimization disabled'
                              : 'Optimization enabled',
                        ),
                        backgroundColor:
                            willDisable ? AppTheme.warning : AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    willDisable ? AppTheme.warning : AppTheme.primaryGreen,
              ),
              child: Text(
                willDisable ? 'Disable' : 'Enable',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWarningItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppTheme.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
