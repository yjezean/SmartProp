import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class ChartWidget extends StatelessWidget {
  final List<SensorData> data;
  final bool isLoading;

  const ChartWidget({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (data.isEmpty) {
      return SizedBox(
        height: 300,
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
      height: 300,
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
                'Temperature (°C)',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text(
                'Humidity (%)',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppTheme.divider),
          ),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: _getMinY(),
          maxY: _getMaxY(),
          lineBarsData: [
            LineChartBarData(
              spots: _getTemperatureSpots(),
              isCurved: true,
              color: AppTheme.tempCritical,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
            LineChartBarData(
              spots: _getHumiditySpots(),
              isCurved: true,
              color: AppTheme.humHigh,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
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

                return touchedSpots.map((LineBarSpot touchedSpot) {
                  String label;
                  Color color;

                  if (touchedSpot.barIndex == 0) {
                    label = '${sensorData.temperature.toStringAsFixed(1)}°C';
                    color = AppTheme.tempCritical;
                  } else {
                    label = '${sensorData.humidity.toStringAsFixed(1)}%';
                    color = AppTheme.humHigh;
                  }

                  return LineTooltipItem(
                    '$timestamp\n$label',
                    TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
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

  List<FlSpot> _getTemperatureSpots() {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.temperature);
    }).toList();
  }

  List<FlSpot> _getHumiditySpots() {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.humidity);
    }).toList();
  }

  double _getMinY() {
    if (data.isEmpty) return 0;
    final temps = data.map((d) => d.temperature).toList();
    final hums = data.map((d) => d.humidity).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final minHum = hums.reduce((a, b) => a < b ? a : b);
    return (minTemp < minHum ? minTemp : minHum) - 5;
  }

  double _getMaxY() {
    if (data.isEmpty) return 100;
    final temps = data.map((d) => d.temperature).toList();
    final hums = data.map((d) => d.humidity).toList();
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final maxHum = hums.reduce((a, b) => a > b ? a : b);
    return (maxTemp > maxHum ? maxTemp : maxHum) + 5;
  }

  double _getXAxisInterval() {
    if (data.length <= 10) return 1;
    if (data.length <= 50) return data.length / 10;
    return data.length / 5;
  }
}
