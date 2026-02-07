import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/analytics_models.dart';

/// Chart widget displaying training max progression over time.
class TrainingMaxChart extends StatefulWidget {
  final TrainingMaxProgression data;
  final String? selectedLift;
  final ValueChanged<String>? onLiftChanged;

  const TrainingMaxChart({
    super.key,
    required this.data,
    this.selectedLift,
    this.onLiftChanged,
  });

  @override
  State<TrainingMaxChart> createState() => _TrainingMaxChartState();
}

class _TrainingMaxChartState extends State<TrainingMaxChart> {
  late String _selectedLift;
  bool _showByCycle = false;

  @override
  void initState() {
    super.initState();
    _selectedLift = widget.selectedLift ?? 'squat';
  }

  @override
  void didUpdateWidget(TrainingMaxChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLift != null &&
        widget.selectedLift != oldWidget.selectedLift) {
      _selectedLift = widget.selectedLift!;
    }
  }

  Color _getLiftColor(String lift) {
    switch (lift) {
      case 'squat':
        return Colors.green;
      case 'deadlift':
        return Colors.red;
      case 'bench_press':
        return Colors.blue;
      case 'press':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getLiftDisplayName(String lift) {
    switch (lift) {
      case 'squat':
        return 'Squat';
      case 'deadlift':
        return 'Deadlift';
      case 'bench_press':
        return 'Bench';
      case 'press':
        return 'Press';
      default:
        return lift;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataPoints = widget.data.getLiftData(_selectedLift);
    final color = _getLiftColor(_selectedLift);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildLiftSelector(color),
        const SizedBox(height: 16),
        if (dataPoints.isEmpty)
          _buildEmptyState()
        else
          _buildChart(dataPoints, color),
        if (dataPoints.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildXAxisToggle(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.show_chart, size: 24, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Training Max Progression',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiftSelector(Color activeColor) {
    final lifts = ['squat', 'deadlift', 'bench_press', 'press'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: lifts.map((lift) {
          final isSelected = lift == _selectedLift;
          final liftColor = _getLiftColor(lift);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getLiftDisplayName(lift)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedLift = lift);
                  widget.onLiftChanged?.call(lift);
                }
              },
              selectedColor: liftColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? liftColor : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? liftColor : Colors.grey[300]!,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No progression data yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete cycles to see your progress',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<TrainingMaxDataPoint> dataPoints, Color color) {
    // Sort by date
    final sortedPoints = List<TrainingMaxDataPoint>.from(dataPoints)
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = sortedPoints.asMap().entries.map((entry) {
      final xValue =
          _showByCycle ? entry.value.cycle.toDouble() : entry.key.toDouble();
      return FlSpot(xValue, entry.value.value);
    }).toList();

    final minY = sortedPoints.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = sortedPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final yPadding = (maxY - minY) * 0.1;

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calculateYInterval(minY, maxY),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                interval: _calculateYInterval(minY, maxY),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (_showByCycle) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'C${value.toInt()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  } else {
                    final index = value.toInt();
                    if (index >= 0 && index < sortedPoints.length) {
                      final date = sortedPoints[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('M/d').format(date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 5,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.grey[800]!,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = _showByCycle
                      ? sortedPoints
                          .indexWhere((p) => p.cycle == spot.x.toInt())
                      : spot.x.toInt();
                  if (index >= 0 && index < sortedPoints.length) {
                    final point = sortedPoints[index];
                    return LineTooltipItem(
                      '${point.value.toInt()} lbs\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${DateFormat('MMM d, y').format(point.date)}\nCycle ${point.cycle}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }
                  return null;
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          minY: (minY - yPadding).clamp(0, double.infinity),
          maxY: maxY + yPadding,
        ),
      ),
    );
  }

  double _calculateYInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 200) return 25;
    return 50;
  }

  Widget _buildXAxisToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'X-Axis:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Date', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: true,
              label: Text('Cycle', style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {_showByCycle},
          onSelectionChanged: (values) {
            setState(() => _showByCycle = values.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}
