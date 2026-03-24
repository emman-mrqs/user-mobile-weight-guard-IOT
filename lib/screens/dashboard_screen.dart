import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mobile/widget/navbar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const List<double> _hourlyWeightKg = <double>[
    2190,
    2280,
    2325,
    2240,
    2390,
    2450,
    2410,
    2485,
    2520,
    2470,
    2540,
    2495,
  ];

  static const int _totalTasks = 36;
  static const int _completedTasks = 29;

  @override
  Widget build(BuildContext context) {
    final double avgWeight = _hourlyWeightKg.reduce((a, b) => a + b) / _hourlyWeightKg.length;
    final double completionRate = _completedTasks / _totalTasks;

    return Container(
      color: const Color(0xFF051E16),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppNavbar(
                title: 'Dashboard',
                subtitle: 'Cargo and trip performance at a glance',
                notificationCount: 3,
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _KpiCard(
                      title: 'Avg Load',
                      value: '${avgWeight.toStringAsFixed(0)} kg',
                      subtitle: 'Last 12 intervals',
                      accent: const Color(0xFF4ADE80),
                      icon: Icons.scale_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      title: 'Tasks Done',
                      value: '$_completedTasks/$_totalTasks',
                      subtitle: '${(completionRate * 100).toStringAsFixed(0)}% completion',
                      accent: const Color(0xFF4ADE80),
                      icon: Icons.task_alt_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Weight Trend (kg)',
                subtitle: 'Open-source chart via fl_chart',
                child: SizedBox(
                  height: 190,
                  child: LineChart(
                    LineChartData(
                      minY: 2100,
                      maxY: 2600,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (double value) {
                          return FlLine(color: Colors.white.withValues(alpha: 0.08), strokeWidth: 1);
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: 100,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10, color: Colors.white60),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 2,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${value.toInt()}:00',
                                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: <LineChartBarData>[
                        LineChartBarData(
                          spots: _hourlyWeightKg
                              .asMap()
                              .entries
                              .map((MapEntry<int, double> e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: const Color(0xFF4ADE80),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (FlSpot spot, double percent, LineChartBarData barData, int index) {
                              return FlDotCirclePainter(
                                radius: 2.5,
                                color: const Color(0xFF4ADE80),
                                strokeWidth: 1,
                                strokeColor: const Color(0xFF0C2B22),
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Task Done Progress',
                subtitle: 'Daily operation completion status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Completed: $_completedTasks tasks',
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        Text(
                          'Pending: ${_totalTasks - _completedTasks}',
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: completionRate,
                        minHeight: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(completionRate * 100).toStringAsFixed(0)}% complete',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2B22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Operational Insights',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    SizedBox(height: 14),
                    _InsightRow(label: 'Most active route', value: 'Cebu -> Mandaue'),
                    SizedBox(height: 8),
                    _InsightRow(label: 'Peak loading window', value: '08:00 - 10:00'),
                    SizedBox(height: 8),
                    _InsightRow(label: 'Avg unloading delay', value: '6 mins'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;

  const _InsightRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
