import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../services/grade_service.dart';

class GradeAnalysisContent extends StatelessWidget {
  final Map<String, List<Grade>> allGrades;
  final List<String> semesters;
  final String? selectedTermId;

  const GradeAnalysisContent({
    super.key,
    required this.allGrades,
    required this.semesters,
    required this.selectedTermId,
  });

  List<Grade> get _currentGrades {
    if (selectedTermId == null) return [];

    if (selectedTermId == '全部') {
      return allGrades.values.expand((x) => x).toList();
    }
    return allGrades[selectedTermId] ?? [];
  }

  double _calculateGPA(List<Grade> grades) {
    if (grades.isEmpty) return 0.0;
    double totalPoints = 0.0;
    double totalCredits = 0.0;
    for (var g in grades) {
      if (g.gpa == 0) continue;
      totalPoints += g.gpa * g.credit;
      totalCredits += g.credit;
    }
    return totalCredits == 0 ? 0.0 : totalPoints / totalCredits;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (allGrades.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无成绩数据可分析', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final trendSpots = <FlSpot>[];
    final sortedTerms = semesters
        .where((s) => s != '全部')
        .toList()
        .reversed
        .toList();

    for (int i = 0; i < sortedTerms.length; i++) {
      final term = sortedTerms[i];
      final grades = allGrades[term] ?? [];
      final gpa = _calculateGPA(grades);
      trendSpots.add(FlSpot(i.toDouble(), gpa));
    }

    final currentGrades = _currentGrades;
    int excellent = 0, good = 0, pass = 0, fail = 0;
    for (var g in currentGrades) {
      if (!g.isPassed) {
        fail++;
        continue;
      }
      final score = double.tryParse(g.score) ?? 0;
      if (score >= 90) {
        excellent++;
      } else if (score >= 80) {
        good++;
      } else {
        pass++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            theme: theme,
            title: '学期成绩分布',
            subtitle: selectedTermId == '全部' ? '所有学期' : selectedTermId,
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    sections: [
                      _buildPieSection(excellent, '优秀', Colors.blue.shade400),
                      _buildPieSection(good, '良好', Colors.teal.shade300),
                      _buildPieSection(pass, '及格', Colors.orange.shade300),
                      _buildPieSection(fail, '挂科', Colors.red.shade300),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _SectionTitle(theme: theme, title: 'GPA 变化趋势', subtitle: '全程记录'),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.5,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 24, 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.2,
                        ),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 0.5,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final index = val.toInt();
                          if (index >= 0 && index < sortedTerms.length) {
                            final term = sortedTerms[index];
                            String label = term;
                            try {
                              final parts = term.split('-');
                              if (parts.length >= 3) {
                                final year = parts[0].length == 4
                                    ? parts[0].substring(2)
                                    : parts[0];
                                label = '$year-${parts.last}';
                              } else if (parts.isNotEmpty) {
                                label = parts.last;
                              }
                            } catch (_) {}

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
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
                      spots: trendSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                      ),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: theme.colorScheme.surface,
                            strokeWidth: 3,
                            strokeColor: theme.colorScheme.primary,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.25),
                            theme.colorScheme.primary.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 5,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) =>
                          theme.colorScheme.inverseSurface,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      tooltipMargin: 16,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final term = sortedTerms[index];
                          return LineTooltipItem(
                            '$term\n',
                            TextStyle(
                              color: theme.colorScheme.onInverseSurface
                                  .withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: 'GPA: ${spot.y.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onInverseSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.5,
                            ),
                            strokeWidth: 2,
                            dashArray: [5, 5],
                          ),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 8,
                                color: theme.colorScheme.primary,
                                strokeWidth: 3,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(int value, String title, Color color) {
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: value > 0 ? '$value门' : '',
      radius: 50,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      badgeWidget: value > 0 ? _Badge(text: title, color: color) : null,
      badgePositionPercentageOffset: 1.3,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final String? subtitle;

  const _SectionTitle({
    required this.theme,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 13, color: theme.hintColor),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2),
        ],
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
