import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class HumidityChartWidget extends StatelessWidget {
  final List<SensorData> data;
  final bool isLoading;

  const HumidityChartWidget({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (data.isEmpty) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Text(
            'No data available',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
      );
    }

    return Container(
      height: 250,
      margin: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.divider,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _getXAxisInterval(),
                getTitlesWidget: (value, meta) {
                  if (data.isEmpty) return const Text('');
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const Text('');
                  final date = data[index].timestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd HH:mm').format(date),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Humidity (%)',
                style: TextStyle(fontSize: 12, color: AppTheme.humHigh),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 55,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: AppTheme.humHigh,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppTheme.divider),
          ),
          minX: 0,
          maxX: data.isEmpty ? 1 : (data.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: _getHumiditySpots(),
              isCurved: true,
              color: AppTheme.humHigh,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.humHigh.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                if (touchedSpots.isEmpty || touchedSpots[0].x.toInt() < 0)
                  return [];
                final index = touchedSpots[0].x.toInt();
                if (index >= data.length) return [];
                final sensorData = data[index];
                final timestamp =
                    DateFormat('MM/dd HH:mm:ss').format(sensorData.timestamp);

                return [
                  LineTooltipItem(
                    '$timestamp\n${sensorData.humidity.toStringAsFixed(1)}%',
                    const TextStyle(
                      color: AppTheme.humHigh,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ];
              },
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              tooltipRoundedRadius: 8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _getHumiditySpots() {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.humidity);
    }).toList();
  }

  double _getXAxisInterval() {
    if (data.length <= 10) return 1;
    if (data.length <= 50) return data.length / 10;
    return data.length / 5;
  }
}
