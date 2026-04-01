import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mobile/widget/navbar.dart';

import '../services/mobile_dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = MobileDashboardService.fetchDashboard();
  }

  Future<void> _refreshDashboard() async {
    final nextFuture = MobileDashboardService.fetchDashboard(forceRefresh: true);
    setState(() {
      _dashboardFuture = nextFuture;
    });

    await nextFuture;
  }

  List<double> _parseWeightTrend(dynamic trend) {
    if (trend is! List) {
      return <double>[];
    }

    return trend
        .map((item) {
          if (item is num) {
            return item.toDouble();
          }
          return null;
        })
        .whereType<double>()
        .toList();
  }

  double _safeToDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  int _safeToInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF051E16),
      child: SafeArea(
        bottom: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white70, size: 34),
                      const SizedBox(height: 10),
                      Text(
                        snapshot.error.toString().replaceFirst('Exception: ', ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshDashboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A7B51),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ?? <String, dynamic>{};
            final kpis = (data['kpis'] is Map<String, dynamic>)
                ? data['kpis'] as Map<String, dynamic>
                : <String, dynamic>{};

            final avgWeight = _safeToDouble(kpis['avgLoadKg']);
            final completedTasks = _safeToInt(kpis['tasksCompleted']);
            final totalTasks = _safeToInt(kpis['totalTasks']);

            double completionRate = _safeToDouble(kpis['completionRate']);
            if (completionRate > 1) {
              completionRate = completionRate / 100;
            }
            if (completionRate < 0) {
              completionRate = 0;
            }
            if (completionRate > 1) {
              completionRate = 1;
            }

            final weightTrend = _parseWeightTrend(data['weightTrendKg']);
            final insights = (data['insights'] is List)
                ? (data['insights'] as List)
                    .whereType<Map>()
                    .map((e) => {
                          'label': (e['label'] ?? '').toString(),
                          'value': (e['value'] ?? '').toString(),
                        })
                    .toList()
                : <Map<String, String>>[];

            return RefreshIndicator(
              onRefresh: _refreshDashboard,
              color: const Color(0xFF4ADE80),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const AppNavbar(
                      title: 'Dashboard',
                      subtitle: 'Cargo and trip performance at a glance',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _refreshDashboard,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _KpiCard(
                            title: 'Avg Load',
                            value: '${avgWeight.toStringAsFixed(0)} kg',
                            subtitle: 'From server dashboard data',
                            accent: const Color(0xFF4ADE80),
                            icon: Icons.scale_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            title: 'Tasks Done',
                            value: '$completedTasks',
                            subtitle: 'Completed in last 30 days',
                            accent: const Color(0xFF4ADE80),
                            icon: Icons.task_alt_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Weight Trend (kg)',
                      subtitle: 'Data from mobile dashboard API',
                      child: SizedBox(
                        height: 190,
                        child: weightTrend.isEmpty
                            ? const Center(
                                child: Text(
                                  'No trend data yet',
                                  style: TextStyle(color: Colors.white60),
                                ),
                              )
                            : LineChart(
                                LineChartData(
                                  minY: weightTrend.reduce((a, b) => a < b ? a : b) - 20,
                                  maxY: weightTrend.reduce((a, b) => a > b ? a : b) + 20,
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
                                              'P${value.toInt() + 1}',
                                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  lineBarsData: <LineChartBarData>[
                                    LineChartBarData(
                                      spots: weightTrend
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
                                'Completed: $completedTasks tasks',
                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                              ),
                              Text(
                                'Pending: ${totalTasks - completedTasks}',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Operational Insights',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 14),
                          if (insights.isEmpty)
                            const Text('No insights yet', style: TextStyle(color: Colors.white60))
                          else
                            ...insights.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _InsightRow(
                                  label: item['label'] ?? '',
                                  value: item['value'] ?? '',
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
