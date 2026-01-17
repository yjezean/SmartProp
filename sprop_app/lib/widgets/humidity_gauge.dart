import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../theme/app_theme.dart';

class HumidityGauge extends StatelessWidget {
  final double humidity;

  const HumidityGauge({
    super.key,
    required this.humidity,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getHumidityColor(humidity);

    return Container(
      padding: const EdgeInsets.all(16),
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: 100,
            startAngle: 180,
            endAngle: 0,
            showLabels: false,
            showTicks: false,
            radiusFactor: 0.8,
            axisLineStyle: const AxisLineStyle(
              thickness: 0.1,
              thicknessUnit: GaugeSizeUnit.factor,
              color: AppTheme.divider,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: humidity,
                width: 0.1,
                sizeUnit: GaugeSizeUnit.factor,
                color: color,
                enableAnimation: true,
                animationDuration: 500,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${humidity.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const Text(
                      'Humidity',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0.5,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

