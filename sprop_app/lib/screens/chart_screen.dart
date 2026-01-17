import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/chart_data_provider.dart';
import '../providers/sensor_provider.dart';
import '../widgets/temperature_chart_widget.dart';
import '../widgets/humidity_chart_widget.dart';
import '../theme/app_theme.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChartDataProvider>(context, listen: false);
      provider.fetchData();
      // Set up auto-refresh every 30 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        provider.fetchData();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historical Data'),
        actions: [
          Consumer<ChartDataProvider>(
            builder: (context, chartProvider, child) {
              return IconButton(
                icon: chartProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed:
                    chartProvider.isLoading ? null : () => chartProvider.fetchData(),
                tooltip: 'Refresh data',
              );
            },
          ),
        ],
      ),
      body: Consumer2<ChartDataProvider, SensorProvider>(
        builder: (context, chartProvider, sensorProvider, child) {
          // Check if device is offline
          final isOffline = sensorProvider.currentData == null || !sensorProvider.isConnected;
          
          if (chartProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      chartProvider.error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => chartProvider.fetchData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Charts show historical data only. Real-time data unavailable.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Time Range Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeRangeButton(
                      context,
                      '1 Day',
                      1,
                      chartProvider.selectedDays == 1,
                      chartProvider,
                    ),
                    _buildTimeRangeButton(
                      context,
                      '7 Days',
                      7,
                      chartProvider.selectedDays == 7,
                      chartProvider,
                    ),
                    _buildTimeRangeButton(
                      context,
                      '30 Days',
                      30,
                      chartProvider.selectedDays == 30,
                      chartProvider,
                    ),
                  ],
                ),
              ),
              // Last Fetched Timestamp
              if (chartProvider.lastFetched != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last updated: ${DateFormat('MM/dd HH:mm:ss').format(chartProvider.lastFetched!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // Charts - Temperature
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.thermostat,
                                color: AppTheme.tempCritical, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Temperature',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.tempCritical,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      TemperatureChartWidget(
                        data: chartProvider.data,
                        isLoading: chartProvider.isLoading,
                      ),
                      const SizedBox(height: 16),
                      // Charts - Humidity
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.water_drop,
                                color: AppTheme.humHigh, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Humidity',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.humHigh,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      HumidityChartWidget(
                        data: chartProvider.data,
                        isLoading: chartProvider.isLoading,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeRangeButton(
    BuildContext context,
    String label,
    int days,
    bool isSelected,
    ChartDataProvider provider,
  ) {
    return ElevatedButton(
      onPressed: () => provider.setSelectedDays(days),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primaryGreen : AppTheme.surface,
        foregroundColor: isSelected ? Colors.white : AppTheme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
