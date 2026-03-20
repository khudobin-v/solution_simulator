import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../theme.dart';

class ChartPanel extends StatelessWidget {
  final List<StepData> series;

  const ChartPanel({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('График',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Относительная масса и средняя концентрация',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildChart(colors)),
          const SizedBox(height: 12),
          _buildLegend(colors),
        ],
      ),
    );
  }

  Widget _buildChart(AppColorsExtension colors) {
    final massSpots = <FlSpot>[];
    final concSpots = <FlSpot>[];

    // Sample to at most 300 points for performance
    final step = (series.length / 300).ceil().clamp(1, series.length);
    for (int i = 0; i < series.length; i += step) {
      final d = series[i];
      massSpots.add(FlSpot(d.step.toDouble(), d.relativeMass));
      concSpots.add(FlSpot(d.step.toDouble(), d.meanConcentration));
    }

    return LineChart(
      LineChartData(
        backgroundColor: colors.elevated,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.2,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.borderLight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: colors.borderLight),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 0.2,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 10, color: colors.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (series.last.step / 5).ceilToDouble(),
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(
                    fontSize: 10, color: colors.textMuted),
              ),
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: massSpots,
            isCurved: true,
            color: colors.textPrimary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: colors.textPrimary.withAlpha(18),
            ),
          ),
          LineChartBarData(
            spots: concSpots,
            isCurved: true,
            color: colors.electricBlue,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: colors.electricBlue.withAlpha(18),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.elevated,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      s.y.toStringAsFixed(3),
                      TextStyle(
                        color: s.bar.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(AppColorsExtension colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(colors.textPrimary, 'Относит. масса', colors),
        const SizedBox(width: 24),
        _legendItem(colors.electricBlue, 'Ср. концентрация', colors),
      ],
    );
  }

  Widget _legendItem(Color color, String label, AppColorsExtension colors) {
    return Row(
      children: [
        Container(
            width: 20,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            )),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }
}
