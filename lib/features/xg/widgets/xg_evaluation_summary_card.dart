import 'package:flutter/material.dart';

import '../../../models/xg_evaluation_score.dart';
import 'xg_summary_card_shell.dart';

/// 综合测评页顶部摘要卡。
class XgEvaluationSummaryCard extends StatelessWidget {
  final XgEvaluationScore score;

  const XgEvaluationSummaryCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return XgSummaryCardShell(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '总分',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            score.zcj.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto',
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '分',
                            style: TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A11CB).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${score.cpxnDisplay} ${score.cpxqDisplay}',
                  style: const TextStyle(
                    color: Color(0xFF6A11CB),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _RankItem(
                    label: '班级排名',
                    value: score.bjpm,
                    color: const Color(0xFF6A11CB),
                    icon: Icons.class_rounded,
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xFFE0E0E0)),
                Expanded(
                  child: _RankItem(
                    label: '专业排名',
                    value: score.zynjpm,
                    color: const Color(0xFFFB8C00),
                    icon: Icons.school_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _RankItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
